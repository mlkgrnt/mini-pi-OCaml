import { ChildProcess, spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import readline from "node:readline";
import type { AgentEvent } from "./types/events.js";
import type {
    ExtensionCommandsData,
    ExtensionUIRequest,
    ExtensionUIResponse,
    RewindTargetsData,
    RpcRequest,
    RpcResponse,
    SessionData,
    SessionListData,
    SessionState,
} from "./types/rpc.js";

// The agent backend used to be a Python module started as
// `python -P -m coding.main --mode rpc`. This build drives a native OCaml
// binary that speaks the identical protocol on stdin/stdout instead.
//
// Resolution order:
//   1. MINI_PI_BIN                          explicit override
//   2. <root>/_build/default/bin/main.exe   a local dune build
//   3. python -P -m coding.main             the original Python implementation
interface Backend {
    cmd: string;
    args: string[];
}

function findInRoots(relative: string): string | null {
    const here = path.dirname(fileURLToPath(import.meta.url));
    const roots = [
        process.cwd(),
        path.resolve(here, ".."),
        path.resolve(here, "../.."),
        path.resolve(here, "../../.."),
    ];
    for (const root of roots) {
        const candidate = path.join(root, relative);
        if (fs.existsSync(candidate)) return candidate;
    }
    return null;
}

function resolveBackend(): Backend {
    const explicit = process.env.MINI_PI_BIN;
    if (explicit && explicit.trim() !== "") {
        return { cmd: explicit, args: ["--mode", "rpc"] };
    }

    for (const name of [
        "_build/default/bin/main.exe",
        "_build/default/bin/main.bc",
        "bin/minipi.exe",
    ]) {
        const found = findInRoots(name);
        if (found) return { cmd: found, args: ["--mode", "rpc"] };
    }

    // Last resort: the Python implementation this project was ported from.
    const pythonBin = process.env.MINI_PI_PYTHON || "python3";
    return { cmd: pythonBin, args: ["-P", "-m", "coding.main", "--mode", "rpc"] };
}

export class RpcClient {
    private process: ChildProcess;
    private requestId = 0;
    private pendingRequests = new Map<
        string,
        { resolve: (resp: RpcResponse) => void; reject: (err: Error) => void }
    >();
    private eventListeners: Array<(event: AgentEvent) => void> = [];
    private extensionUIListeners: Array<
        (req: ExtensionUIRequest) => Promise<void>
    > = [];
    private rl: readline.Interface;

    constructor() {
        const { cmd, args } = resolveBackend();
        this.process = spawn(cmd, args, {
            cwd: process.cwd(),
            stdio: ["pipe", "pipe", "inherit"],
            // stdin (node can write to), stdout (node can read from), stderr (any errors, warnings stream to parent terminal directly)
        });

        if (!this.process.stdout) {
            throw new Error("Unable to start the agent backend process");
        }

        this.rl = readline.createInterface({ input: this.process.stdout });
        this.rl.on("line", (line) => {
            this.handleLine(line);
        });

        this.process.on("exit", () => {
            const error = new Error("Python process exited");

            for (const pending of this.pendingRequests.values()) {
                pending.reject(error);
            }

            this.pendingRequests.clear();
        });
    }

    private handleLine(line: string): void {
        try {
            const parsed = JSON.parse(line) as
                RpcResponse | AgentEvent | ExtensionUIRequest;

            // Check for requests from rpc_server
            if (parsed.type == "extension_ui_request") {
                for (const l of this.extensionUIListeners) {
                    // Calling listener will start the execution of listener synchronously
                    // until it hit await where it save rest of listener into queue for picker
                    // to resolve and continues to handleLine
                    // In python call async function just create coroutine object but
                    // does not start the execution
                    // While in js, it do start the execution
                    l(parsed as ExtensionUIRequest);
                }
                return;
            }

            if (parsed.type == "response") {
                if (parsed.id && this.pendingRequests.has(parsed.id)) {
                    const pending = this.pendingRequests.get(parsed.id)!;
                    this.pendingRequests.delete(parsed.id);
                    pending.resolve(parsed as RpcResponse);
                }
                return;
            }

            for (const listener of this.eventListeners) {
                listener(parsed as AgentEvent);
            }
        } catch {
            // Ignore Non JSON lines
        }
    }

    private async send<T>(request: RpcRequest): Promise<T> {
        const stdin = this.process.stdin;

        const id = `req_${++this.requestId}`;
        const fullRequest = { ...request, id };

        return new Promise<T>((res, rej) => {
            const timeout = setTimeout(() => {
                this.pendingRequests.delete(id);
                // No race condition as Node run on single thread with "runs to completion"
                rej(
                    new Error(
                        `Timeout waiting for response to ${request.type} with id: ${id}`,
                    ),
                );
            }, 300000);

            this.pendingRequests.set(id, {
                resolve: (response: RpcResponse) => {
                    clearTimeout(timeout);
                    if (!response.success) {
                        rej(new Error(response.error));
                    } else {
                        res(
                            ("data" in response
                                ? response.data
                                : undefined) as T,
                        );
                    }
                },
                reject: (err: Error) => {
                    clearTimeout(timeout);
                    rej(err);
                },
            });

            stdin?.write(JSON.stringify(fullRequest) + "\n");
        });
    }

    public sendExtensionUIResponse(resp: ExtensionUIResponse): void {
        this.process.stdin?.write(JSON.stringify(resp) + "\n");
    }

    public onEvent(handler: (event: AgentEvent) => void): () => void {
        this.eventListeners.push(handler);
        const unsubscribe = () => {
            this.eventListeners = this.eventListeners.filter(
                (l) => l != handler,
            );
        };

        return unsubscribe;
    }

    public onExtensionUIRequest(
        handler: (req: ExtensionUIRequest) => Promise<void>,
    ): () => void {
        this.extensionUIListeners.push(handler);
        const unsubscribe = () => {
            this.extensionUIListeners = this.extensionUIListeners.filter(
                (l) => l != handler,
            );
        };

        return unsubscribe;
    }

    public onExit(handler: () => void): void {
        this.process.on("exit", handler); // on append to list of listerners for "exit"
    }

    public kill(): void {
        this.rl.close();
        this.process.kill();
    }

    // RPC client request interface

    // State
    async getState(): Promise<SessionState> {
        return this.send<SessionState>({ type: "get_state" });
    }

    // Message
    async prompt(message: string): Promise<void> {
        return this.send<void>({ type: "prompt", message });
    }

    async steer(message: string): Promise<void> {
        return this.send<void>({ type: "steer", message });
    }

    async followUp(message: string): Promise<void> {
        return this.send<void>({ type: "follow_up", message });
    }

    // Session
    async newSession(): Promise<SessionData> {
        return this.send<SessionData>({ type: "new_session" });
    }

    async listSessions(): Promise<SessionListData> {
        return this.send<SessionListData>({ type: "list_sessions" });
    }

    async resume(sessionId: string): Promise<SessionData> {
        return this.send<SessionData>({
            type: "resume",
            session_id: sessionId,
        });
    }

    // Rewind
    async rewind(entryId: string): Promise<SessionData> {
        return this.send<SessionData>({ type: "rewind", entry_id: entryId });
    }

    async getRewindTargets(): Promise<RewindTargetsData> {
        return this.send<RewindTargetsData>({ type: "get_rewind_targets" });
    }

    // Compaction
    async compact(custom_instructions?: string): Promise<void> {
        return this.send<void>({
            type: "compact",
            ...(custom_instructions !== undefined && { custom_instructions }),
        });
    }

    async login(provider: string, key: string): Promise<void> {
        return this.send<void>({ type: "login", provider, key });
    }

    async logout(provider: string): Promise<void> {
        return this.send<void>({ type: "logout", provider });
    }

    async setDefaultModel(model_ref: string): Promise<void> {
        return this.send<void>({ type: "set_default_model", model_ref });
    }

    async getExtensionCommands(): Promise<ExtensionCommandsData> {
        return this.send<ExtensionCommandsData>({
            type: "get_extension_commands",
        });
    }

    // Abort
    async abort(): Promise<void> {
        return this.send<void>({ type: "abort" });
    }
}
