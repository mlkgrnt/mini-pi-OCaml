import {
    CombinedAutocompleteProvider,
    Editor,
    Key,
    matchesKey,
    ProcessTerminal,
    TuiMainScreen,
    type SelectItem,
} from "@earendil-works/pi-tui";

import {
    dim_color_wrapper,
    cyan_color_wrapper,
    red_color_wrapper,
    editorTheme,
} from "./theme.js";
import { Trajectory } from "./trajectory.js";
import type { SessionEvent } from "./types/events.js";
import { ActivityLoader } from "./loader.js";
import { TUIHeader } from "./header.js";
import { PickerComponent, type PickerOptions } from "./component.js";
import { RpcClient } from "./rpc_client.js";
import type { ExtensionCommandInfo, ExtensionUIRequest } from "./types/rpc.js";
import { BUILTIN_SLASH_COMMANDS } from "./types/command.js";

const DOUBLE_ESC_TIMEOUT_MS = 400;

export class InteractiveMode {
    private tui: TuiMainScreen;
    private editor: Editor;
    private trajectory: Trajectory;
    private tuiHeader: TUIHeader;
    private activityLoader: ActivityLoader;
    private agent: RpcClient;

    private busy: boolean = false;
    private currentSessionId: string = "";
    private extensionCommands: ExtensionCommandInfo[] = [];
    private activePicker: PickerComponent | null = null;
    private lastEscTime: number = 0;

    constructor(agent: RpcClient) {
        // UI Setup
        const terminal = new ProcessTerminal();
        this.tui = new TuiMainScreen(terminal);
        this.tui.setClearOnShrink(true);
        this.editor = new Editor(this.tui, editorTheme, {
            paddingX: 1,
        });
        this.trajectory = new Trajectory(() => this.tui.requestRender());
        this.tuiHeader = new TUIHeader(() => this.tui.requestRender());
        this.activityLoader = new ActivityLoader(this.tui, this.editor);

        // Agent
        this.agent = agent;
    }

    // UI utils
    private showError(message: string): void {
        this.trajectory.addText(message, red_color_wrapper);
    }

    private showStatus(message: string): void {
        this.trajectory.addText(message, dim_color_wrapper);
    }

    private showPicker(options: PickerOptions): Promise<SelectItem | null> {
        return new Promise((resolve) => {
            if (this.activePicker) {
                this.tui.removeChild(this.activePicker);
                this.activePicker = null;
            }

            const picker = new PickerComponent(options);
            this.activePicker = picker;

            const closePicker = () => {
                this.tui.removeChild(picker);
                this.tui.addChild(this.editor);
                this.tui.setFocus(this.editor);
                this.activePicker = null;
                this.tui.requestRender();
            };

            picker.onSelect = (item) => {
                closePicker();
                resolve(item);
            };

            picker.onCancel = () => {
                closePicker();
                resolve(null);
            };

            this.tui.removeChild(this.editor);
            this.tui.addChild(picker);
            this.tui.setFocus(picker);
            this.tui.requestRender();
        });
    }

    // Cancellation

    private async abortAgent(): Promise<void> {
        try {
            await this.agent.abort();
        } catch (err) {
            this.showError(`Error aborting: ${err}`);
        }
    }

    private shutdown(): void {
        this.agent.kill();
        this.tui.stop();
        process.exit(0);
    }

    // Setup

    private setupKeyHandlers(): void {
        this.tui.addInputListener((data: string) => {
            if (this.activePicker) {
                if (
                    matchesKey(data, Key.ctrl("c")) ||
                    matchesKey(data, Key.esc)
                ) {
                    this.activePicker.onCancel?.();
                    return { consume: true };
                }
                return; // Picker will handle rest of key like navigate up / down
            }

            if (matchesKey(data, Key.ctrl("c"))) {
                if (this.busy) {
                    this.abortAgent();
                    return { consume: true }; // Ctrl+c is being consumed, dont passes down
                } else {
                    this.shutdown();
                }
            } else if (matchesKey(data, Key.ctrl("o"))) {
                this.trajectory.toggleAllCollapsibles();
                return { consume: true };
            } else if (matchesKey(data, Key.alt("enter"))) {
                const text = this.editor.getText().trim();
                this.handleSubmit(text, true);
                return { consume: true };
            } else if (matchesKey(data, Key.esc)) {
                if (this.busy) {
                    this.abortAgent();
                    return { consume: true };
                }

                if (this.editor.isShowingAutocomplete()) {
                    return; // Editor will handle auto complete request
                }

                const now = Date.now();
                if (now - this.lastEscTime <= DOUBLE_ESC_TIMEOUT_MS) {
                    this.editor.setText("");
                    this.lastEscTime = 0;
                } else {
                    this.lastEscTime = now;
                }

                return { consume: true };
            }
        });
    }

    private setupEditorSubmitHandler(): void {
        this.editor.onSubmit = (text: string) => {
            return this.handleSubmit(text, false);
        };
    }

    private setupAutocompleteProvider(): void {
        this.editor.setAutocompleteProvider(
            new CombinedAutocompleteProvider(
                [...BUILTIN_SLASH_COMMANDS, ...this.extensionCommands],
                process.cwd(),
                null,
            ),
        );
    }

    // init
    public run(): void {
        this.agent.onExit(() => {
            this.tui.stop();
            process.exit(0);
        });

        this.agent.onEvent((event) => this.handleEvent(event));
        this.agent.onExtensionUIRequest((req) =>
            this.handleExtensionUIRequest(req),
        );

        // Initial state fetch
        this.agent
            .getState()
            .then((state) => {
                this.tuiHeader.currentModel = state.model;
                this.tuiHeader.updateHeader();
            })
            .catch((err) => {
                this.showError(
                    `Failed to connect to agent ${err instanceof Error ? err.message : err}`,
                );
            });

        this.agent
            .getExtensionCommands()
            .then((data) => {
                const builtinNames = new Set(
                    BUILTIN_SLASH_COMMANDS.map((c) => c.name),
                );
                this.extensionCommands = data.commands.filter(
                    (c) => !builtinNames.has(c.name),
                );

                this.setupAutocompleteProvider();
            })
            .catch((err) => {
                this.showError(`Failed to load extension commands ${err}`);
            });

        this.setupEditorSubmitHandler();
        this.setupKeyHandlers();
        this.setupAutocompleteProvider();

        this.tui.addChild(this.tuiHeader.headerContainer);
        this.tui.addChild(this.trajectory.trajectoryContainer);
        this.tui.addChild(this.editor);

        this.tui.setFocus(this.editor);
        this.tui.start();
    }

    // Agent Event Handler
    private handleEvent(event: SessionEvent): void {
        switch (event.type) {
            case "agent_start": {
                this.busy = true;
                this.activityLoader.start("working...");
                break;
            }

            case "message_update": {
                const update = event.assistant_message_event;
                if (update.type == "thinking_delta") {
                    this.trajectory.handleThinkingDelta(update.delta);
                } else if (update.type == "text_delta") {
                    this.trajectory.handleTextDelta(update.delta);
                }
                break;
            }

            case "message_end": {
                if (event.message.role == "assistant") {
                    this.trajectory.handleAssistantMessageEnd(event.message);
                }
                break;
            }

            case "tool_execution_start": {
                this.trajectory.handleToolStart(
                    event.tool_name,
                    event.tool_call_id,
                    event.arguments,
                );
                break;
            }

            case "tool_execution_end": {
                this.trajectory.handleToolEnd(
                    event.tool_name,
                    event.tool_call_id,
                    event.result,
                    event.is_error,
                );
                break;
            }

            case "agent_end": {
                this.activityLoader.stop();
                this.trajectory.endLoop();
                this.busy = false;
                break;
            }

            case "compaction_start": {
                this.busy = true;
                this.activityLoader.start("compacting...");
                break;
            }

            case "compaction_end": {
                this.activityLoader.stop();
                this.busy = false;
                this.trajectory.handleCompactionEnd(
                    event.result,
                    event.error_message,
                );
                break;
            }

            case "turn_start":
            case "turn_end":
            case "message_start":
                break;
        }
    }

    // Extension UI Request Handler
    private async handleExtensionUIRequest(
        req: ExtensionUIRequest,
    ): Promise<void> {
        if (req.payload.method == "select") {
            const selected = await this.showPicker({
                title: req.payload.title,
                items: req.payload.options.map((opt) => ({
                    value: opt,
                    label: opt,
                })),
            });

            if (selected) {
                this.agent.sendExtensionUIResponse({
                    type: "extension_ui_response",
                    id: req.id,
                    value: selected.value,
                });
            } else {
                this.agent.sendExtensionUIResponse({
                    type: "extension_ui_response",
                    id: req.id,
                    cancelled: true,
                });
            }

            return;
        }

        if (req.payload.method == "notify") {
            this.showStatus(
                `[${req.payload.notify_type.toUpperCase()}] ${req.payload.message}`,
            );
            return;
        }
    }

    // Submit Handler
    private async handleSubmit(text: string, isFollowup: boolean = false) {
        text = text.trim();
        if (!text) return;

        this.editor.addToHistory(text);

        this.editor.setText("");

        if (text == "/exit") {
            this.shutdown();
        }

        if (this.busy) {
            if (isFollowup) {
                this.trajectory.addText(
                    `follow-up > ${text}`,
                    cyan_color_wrapper,
                );
                try {
                    await this.agent.followUp(text);
                } catch (err) {
                    this.showError(`Error sending follow up: ${err}`);
                }
            } else {
                this.trajectory.addText(`steer > ${text}`, cyan_color_wrapper);
                try {
                    await this.agent.steer(text);
                } catch (err) {
                    this.showError(`Error sending steering: ${err}`);
                }
            }
            return;
        }

        if (text == "/clear") {
            this.handleClearCommand();
            return;
        }

        if (text == "/session") {
            this.showStatus(
                `Active session: ${this.currentSessionId || "(none)"}`,
            );
            return;
        }

        if (text == "/help") {
            this.handleHelpCommand();
            return;
        }

        if (text == "/login" || text.startsWith("/login ")) {
            this.handleLoginCommand(text);
            return;
        }

        if (text == "/logout" || text.startsWith("/logout ")) {
            this.handleLogoutCommand(text);
            return;
        }

        if (text == "/model" || text.startsWith("/model ")) {
            this.handleModelCommand(text);
            return;
        }

        if (text == "/rewind") {
            this.handleRewindCommand();
            return;
        }

        if (text.startsWith("/resume")) {
            this.handleResumeCommand(text);
            return;
        }

        if (text == "/compact" || text.startsWith("/compact ")) {
            this.handleCompactCommand(text);
            return;
        }

        this.trajectory.addText(`> ${text}`, cyan_color_wrapper);

        try {
            await this.agent.prompt(text);
        } catch (err) {
            this.activityLoader.stop();
            this.busy = false;
            this.showError(`Error sending prompt: ${err}`);
        }
    }

    // Commands

    private async handleClearCommand(): Promise<void> {
        try {
            const data = await this.agent.newSession();
            this.currentSessionId = data.session_id;
            this.trajectory.clear();
            this.showStatus(`Session started: ${this.currentSessionId}`);
        } catch (err) {
            this.showError(`Error clearing session: ${err}`);
        }
    }

    private handleHelpCommand(): void {
        const lines = [];

        if (BUILTIN_SLASH_COMMANDS.length > 0) {
            lines.push("Available built in commands");
        }

        for (const c of BUILTIN_SLASH_COMMANDS) {
            const hint = c.argumentHint ? ` ${c.argumentHint}:` : "";
            lines.push(`/${c.name}${hint} - ${c.description}`);
        }

        if (this.extensionCommands.length > 0) {
            lines.push("Available Extension commands");

            for (const c of this.extensionCommands) {
                lines.push(` /${c.name} - ${c.description}`);
            }
        }

        this.showStatus(
            lines.length != 0 ? lines.join("\n") : "No commands available",
        );
    }

    private async handleLoginCommand(text: string): Promise<void> {
        const parts = text.slice("/login".length).trim().split(/\s+/);

        const provider = parts[0];
        const key = parts[1];

        if (!provider || !key) {
            this.showError("Usage: /login <provider> <key>");
            return;
        }

        try {
            await this.agent.login(provider, key);
            this.showStatus(`Saved API key for ${provider}`);
        } catch (err) {
            this.showError(`Error saving API Key ${err}`);
        }
    }

    private async handleLogoutCommand(text: string): Promise<void> {
        const parts = text.slice("/logout".length).trim().split(/\s+/);

        const provider = parts[0];

        if (!provider) {
            this.showError("Usage: /logout <provider>");
            return;
        }

        try {
            await this.agent.logout(provider);
            this.showStatus(`Removed stored API key for ${provider}`);
        } catch (err) {
            this.showError(`Error removing API Key ${err}`);
        }
    }

    private async handleModelCommand(text: string): Promise<void> {
        const parts = text.slice("/model".length).trim().split(/\s+/);

        const model_ref = parts[0];

        if (!model_ref) {
            this.showError("Usage: /model <model_ref>");
            return;
        }

        try {
            await this.agent.setDefaultModel(model_ref);
            this.tuiHeader.currentModel = model_ref;
            this.tuiHeader.updateHeader();
            this.showStatus(`Set default model to ${model_ref}`);
        } catch (err) {
            this.showError(`Error setting model to ${err}`);
        }
    }

    private async handleRewindCommand(): Promise<void> {
        try {
            const data = await this.agent.getRewindTargets();
            if (data.targets.length == 0) {
                this.showStatus("No message to rewind to");
                return;
            }

            const items: SelectItem[] = data.targets.map((t) => {
                const text = t.text.trim() || "(empty message)";
                const truncated =
                    text.length > 70 ? text.slice(0, 67) + "..." : text;
                return {
                    value: t.entry_id,
                    label: truncated,
                    description: t.text,
                };
            });

            const selected = await this.showPicker({
                title: "Select message to rewind to",
                items,
            });

            if (selected) {
                this.editor.setText(selected.description ?? "(empty message)");
                this.tui.setFocus(this.editor);
                this.tui.requestRender();

                const rewindData = await this.agent.rewind(selected.value);
                this.currentSessionId = rewindData.session_id;
                this.trajectory.loadMessages(rewindData.messages);
            }
        } catch (err) {
            this.showError(`Error rewinding: ${err}`);
        }
    }

    private async resumeSession(id: string): Promise<void> {
        const data = await this.agent.resume(id);
        this.currentSessionId = data.session_id;

        this.trajectory.loadMessages(data.messages);

        for (const m of data.messages) {
            if (m.role == "user" && m.content) {
                this.editor.addToHistory(m.content);
            }
        }
        this.showStatus(
            `Resumed ${this.currentSessionId} - ${data.messages.length} messages`,
        );
    }

    private async handleResumeCommand(text: string): Promise<void> {
        const id = text.slice("/resume".length).trim();

        try {
            if (id) {
                await this.resumeSession(id);
                return;
            }

            const data = await this.agent.listSessions();
            if (data.rows.length == 0) {
                this.showStatus("No saved sessions");
                return;
            }

            const items: SelectItem[] = data.rows.map((row) => {
                const title = row.title || row.id;
                const label =
                    row.id == this.currentSessionId
                        ? `${title} (current)`
                        : title;
                const formattedDate = row.updated_at
                    .split(".")[0]
                    ?.replace("T", " ") as string;

                return {
                    value: row.id,
                    label: label,
                    description: formattedDate,
                };
            });

            const selected = await this.showPicker({
                title: "Select session to resume:",
                items,
            });

            if (selected) {
                await this.resumeSession(selected.value);
            }
        } catch (err) {
            this.showError(`Error resuming session ${err}`);
        }
    }

    private async handleCompactCommand(text: string): Promise<void> {
        const customInstructions =
            text.slice("/compact".length).trim() || undefined;

        try {
            await this.agent.compact(customInstructions);
        } catch (err) {
            this.showError(`Error compacting: ${err}`);
        }
    }
}
