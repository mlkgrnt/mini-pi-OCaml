import type { SessionMessage } from "./message.js";

// RPC Client Request
export interface MessageRequest {
    id?: string;
    type: "prompt" | "steer" | "follow_up";
    message: string;
}

export interface CompactRequest {
    id?: string;
    type: "compact";
    custom_instructions?: string;
}

export interface ResumeRequest {
    id?: string;
    type: "resume";
    session_id: string;
}

export interface RewindRequest {
    id?: string;
    type: "rewind";
    entry_id: string;
}

export interface LoginRequest {
    id?: string;
    type: "login";
    provider: string;
    key: string;
}

export interface LogoutRequest {
    id?: string;
    type: "logout";
    provider: string;
}

export interface SetDefaultModelRequest {
    id?: string;
    type: "set_default_model";
    model_ref: string;
}

// No arguments
export interface GeneralRequest {
    id?: string;
    type:
        | "abort"
        | "new_session"
        | "get_state"
        | "list_sessions"
        | "get_rewind_targets"
        | "get_extension_commands";
}

export type RpcRequest =
    | MessageRequest
    | CompactRequest
    | ResumeRequest
    | RewindRequest
    | LoginRequest
    | LogoutRequest
    | SetDefaultModelRequest
    | GeneralRequest;

// RPC server response payload
export interface SessionState {
    model: string;
    session_id?: string;
    session_name?: string | null;
}

export interface SessionData {
    session_id: string;
    messages: SessionMessage[];
}

export interface ChatSessionFileMetadata {
    id: string;
    updated_at: string;
    title?: string | null;
}

export interface SessionListData {
    rows: ChatSessionFileMetadata[];
}

export interface RewindTarget {
    entry_id: string;
    text: string;
}

export interface RewindTargetsData {
    targets: RewindTarget[];
}

// export interface CompactData {
//     response: string;
// }

export interface ExtensionCommandInfo {
    name: string;
    description: string;
}

export interface ExtensionCommandsData {
    commands: ExtensionCommandInfo[];
}

// RPC Server Response

export type RpcSuccessResponse =
    | {
          id?: string;
          type: "response";
          request_type: "prompt" | "steer" | "follow_up" | "abort";
          success: true;
      }
    | {
          id?: string;
          type: "response";
          request_type: "get_state";
          success: true;
          data: SessionState;
      }
    | {
          id?: string;
          type: "response";
          request_type: "new_session";
          success: true;
          data: SessionData;
      }
    | { id?: string; type: "response"; request_type: "compact"; success: true }
    | {
          id?: string;
          type: "response";
          request_type: "list_sessions";
          success: true;
          data: SessionListData;
      }
    | {
          id?: string;
          type: "response";
          request_type: "resume";
          success: true;
          data: SessionData;
      }
    | {
          id?: string;
          type: "response";
          request_type: "rewind";
          success: true;
          data: SessionData;
      }
    | {
          id?: string;
          type: "response";
          request_type: "get_rewind_targets";
          success: true;
          data: RewindTargetsData;
      }
    | { id?: string; type: "response"; request_type: "login"; success: true }
    | { id?: string; type: "response"; request_type: "logout"; success: true }
    | {
          id?: string;
          type: "response";
          request_type: "set_default_model";
          success: true;
      }
    | {
          id?: string;
          type: "response";
          request_type: "get_extension_commands";
          success: true;
          data: ExtensionCommandsData;
      };

export interface RpcErrorResponse {
    id?: string;
    type: "response";
    request_type: string;
    success: false;
    error: string;
}

export type RpcResponse = RpcSuccessResponse | RpcErrorResponse;

// Extension UI requests payload

export interface SelectUIRequestPayload {
    method: "select";
    title: string;
    options: string[];
}

export interface NotifyUIRequestPayload {
    method: "notify";
    message: string;
    notify_type: "info" | "warning" | "error";
}

// Extension UI requests
export interface ExtensionUIRequest {
    type: "extension_ui_request";
    id: string;
    payload: SelectUIRequestPayload | NotifyUIRequestPayload;
}

// Extension UI Response
export interface ExtensionUIResponse {
    type: "extension_ui_response";
    id: string;
    value?: string;
    cancelled?: boolean;
}
