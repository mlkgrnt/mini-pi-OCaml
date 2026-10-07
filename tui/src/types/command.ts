// Port of commands.py in typescript

export interface BuiltinSlashCommand {
    name: string;
    description: string;
    argumentHint?: string;
}

export const BUILTIN_SLASH_COMMANDS: BuiltinSlashCommand[] = [
    { name: "exit", description: "Quit the application" },
    { name: "clear", description: "Start a fresh session" },
    { name: "help", description: "List all available slash commands" },
    { name: "session", description: "Show the active session ID" },
    {
        name: "resume",
        description: "List saved sessions or resume a specific session",
        argumentHint: "<session_id>",
    },
    {
        name: "compact",
        description:
            "Compact conversation history with optional focus instructions",
        argumentHint: "<instructions>",
    },
    {
        name: "rewind",
        description: "Rewind conversation to a previous user message",
    },
    {
        name: "login",
        description: "Login to provider using api key",
        argumentHint: "<provider> <key>",
    },
    {
        name: "logout",
        description: "Remove the api key for provider",
        argumentHint: "<provider>",
    },
    {
        name: "model",
        description: "Set the default model across all sessions",
        argumentHint: "<model_ref>",
    },
];
