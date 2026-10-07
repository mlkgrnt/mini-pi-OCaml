// Port of events.py in typescript

import type {
    Message,
    AssistantMessageData,
    ToolResultMessageData,
} from "./message.js";

export interface TextDeltaEvent {
    type: "text_delta";
    delta: string;
}

export interface ThinkingDeltaEvent {
    type: "thinking_delta";
    delta: string;
}

export type AssistantMessageEvent = TextDeltaEvent | ThinkingDeltaEvent;

export interface MessageStartEvent {
    type: "message_start";
    message: Message;
}

export interface MessageUpdateEvent {
    type: "message_update";
    assistant_message_event: AssistantMessageEvent;
}

export interface MessageEndEvent {
    type: "message_end";
    message: Message;
}

export interface AgentStartEvent {
    type: "agent_start";
}

export interface AgentEndEvent {
    type: "agent_end";
    messages?: Message[];
}

export interface TurnStartEvent {
    type: "turn_start";
}

export interface TurnEndEvent {
    type: "turn_end";
    message: AssistantMessageData;
    tool_results?: ToolResultMessageData[];
}

export interface ToolExecutionStartEvent {
    type: "tool_execution_start";
    tool_name: string;
    arguments?: Record<string, unknown>;
    tool_call_id: string;
}

export interface ToolExecutionEndEvent {
    type: "tool_execution_end";
    tool_name: string;
    result: string;
    tool_call_id: string;
    is_error: boolean;
}

export type AgentEvent =
    | AgentStartEvent
    | AgentEndEvent
    | TurnStartEvent
    | TurnEndEvent
    | MessageStartEvent
    | MessageUpdateEvent
    | MessageEndEvent
    | ToolExecutionStartEvent
    | ToolExecutionEndEvent;

type CompactionReason = "threshold" | "overflow" | "manual";

export interface CompactionStartEvent {
    type: "compaction_start";
    reason: CompactionReason;
}

export interface CompactionEndEvent {
    type: "compaction_end";
    result?: string | null;
    error_message?: string | null;
}

export type SessionEvent =
    AgentEvent | CompactionStartEvent | CompactionEndEvent;
