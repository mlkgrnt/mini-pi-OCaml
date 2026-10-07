// Port of messages.py in typescript

export interface UserMessageData {
    role: "user";
    content: string;
}

export interface ToolCallData {
    id: string;
    name: string;
    arguments: Record<string, unknown>;
}

export interface Usage {
    input_tokens: number;
    output_tokens: number;
    cache_read: number;
}

export interface AssistantMessageData {
    role: "assistant";
    content: string;
    thinking?: string;
    tool_calls?: ToolCallData[];
    stop_reason?: string;
    error_message?: string;
    usage?: Usage;
}

export interface ToolResultMessageData {
    role: "tool_result";
    tool_name: string;
    tool_call_id: string;
    content: string;
    is_error?: boolean;
}

export type Message =
    UserMessageData | AssistantMessageData | ToolResultMessageData;

export interface CompactSummaryMessage {
    role: "compaction_summary";
    summary: string;
}

export type SessionMessage = Message | CompactSummaryMessage;
