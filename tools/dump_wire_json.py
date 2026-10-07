"""Dump the exact wire JSON that the Python original produces.

This is the reference side of the port's protocol conformance check: the OCaml
test suite hard-codes what it believes pydantic emits, and this script proves
whether that belief is right. Run with a Python that has pydantic installed:

    python.exe tools/dump_wire_json.py
"""

import json
import os
import sys
from pathlib import Path

# The upstream Python checkout to read the reference encodings from.
UPSTREAM = os.environ.get("MINI_PI_PY_SRC", "E:/mini-pi-src")
sys.path.insert(0, UPSTREAM)


def dump(label, obj, model_dump=True):
    if model_dump:
        payload = obj.model_dump(mode="json")
    else:
        payload = obj
    text = json.dumps(payload, separators=(",", ":"))
    print(f"{label}\n  {text}")


def main():
    from ai.types import (
        AssistantMessage,
        TextDeltaEvent,
        ThinkingDeltaEvent,
        ToolCall,
        ToolResultMessage,
        Usage,
        UserMessage,
    )
    import agent.events as agent_events
    import coding.events as coding_events
    from coding.messages import CompactionSummaryMessage
    from coding.session_manager.entries import (
        CompactionEntry,
        MessageEntry,
        SessionHeader,
    )
    from coding.session_manager.manager import ChatSessionFileMetadata

    print("== ai.types ==")
    dump("UserMessage", UserMessage(content="hello"))
    dump(
        "AssistantMessage (full)",
        AssistantMessage(
            content="hi",
            tool_calls=[ToolCall(id="c1", name="read", arguments={"path": "a"})],
            thinking="why",
            thinking_signature="reasoning_content",
            stop_reason="tool_use",
            usage=Usage(input_tokens=10, output_tokens=2, cache_read=1, total_tokens=12),
        ),
    )
    dump("AssistantMessage (empty)", AssistantMessage())
    dump(
        "ToolResultMessage",
        ToolResultMessage(
            tool_call_id="c1", tool_name="read", content="x", is_error=True
        ),
    )
    dump("TextDeltaEvent", TextDeltaEvent(delta="ab"))
    dump("ThinkingDeltaEvent", ThinkingDeltaEvent(delta="ab"))

    print("\n== agent.events ==")
    dump("agent_start", agent_events.AgentStartEvent())
    dump(
        "agent_end",
        agent_events.AgentEndEvent(messages=[UserMessage(content="hello")]),
    )
    dump("turn_start", agent_events.TurnStartEvent())
    dump(
        "turn_end",
        agent_events.TurnEndEvent(
            message=AssistantMessage(content="hi", stop_reason="stop"),
            tool_results=[
                ToolResultMessage(tool_call_id="c1", tool_name="read", content="x")
            ],
        ),
    )
    dump(
        "message_start",
        agent_events.MessageStartEvent(message=UserMessage(content="hello")),
    )
    dump(
        "message_end",
        agent_events.MessageEndEvent(message=AssistantMessage(content="hi")),
    )
    dump(
        "message_update/text_delta",
        agent_events.MessageUpdateEvent(assistant_message_event=TextDeltaEvent(delta="ab")),
    )
    dump(
        "tool_execution_start",
        agent_events.ToolExecutionStartEvent(
            tool_call_id="i", tool_name="bash", arguments={}
        ),
    )
    dump(
        "tool_execution_end",
        agent_events.ToolExecutionEndEvent(
            tool_call_id="i", tool_name="bash", result="out", is_error=False
        ),
    )

    print("\n== coding.events ==")
    dump("compaction_start", coding_events.CompactionStartEvent(reason="manual"))
    dump("compaction_end", coding_events.CompactionEndEvent(error_message="boom"))
    dump("compaction_end ok", coding_events.CompactionEndEvent(result="2 messages"))

    print("\n== coding.messages ==")
    dump("compaction_summary", CompactionSummaryMessage(summary="S"))

    print("\n== session entries ==")
    dump(
        "SessionHeader",
        SessionHeader(id="h1", timestamp="2026-10-07T00:00:00.000000+00:00", cwd="/w"),
    )
    dump(
        "MessageEntry",
        MessageEntry(
            id="e1",
            timestamp="2026-10-07T00:00:00.000000+00:00",
            parent_id="h1",
            message=UserMessage(content="hello"),
        ),
    )
    dump(
        "CompactionEntry",
        CompactionEntry(
            id="e2",
            timestamp="2026-10-07T00:00:00.000000+00:00",
            parent_id="e1",
            summary="S",
            first_kept_entry_id="e1",
        ),
    )

    print("\n== session list metadata ==")
    dump(
        "ChatSessionFileMetadata",
        ChatSessionFileMetadata(
            updated_at="2026-10-07T12:34:56.123456", id="s1", title="first"
        ),
    )

    print("\n== rpc payloads ==")
    try:
        from coding.modes.rpc.types import (
            EmptySuccessResponse,
            ExtensionCommandInfo,
            ExtensionCommandsData,
            ExtensionUIResponse,
            NotifyUIRequestPayload,
            ExtensionUIRequest,
            RpcErrorResponse,
            RpcPayloadResponse,
            RewindTargetsData,
            SelectUIRequestPayload,
            SessionData,
            SessionListData,
            SessionState,
        )
        from coding.session import RewindTarget

        dump("SessionState", SessionState(model="Minimax M3"))
        dump(
            "SessionData",
            SessionData(session_id="s1", messages=[UserMessage(content="hi")]),
        )
        dump(
            "SessionListData",
            SessionListData(
                rows=[
                    ChatSessionFileMetadata(
                        updated_at="2026-10-07T12:34:56.123456", id="s1", title=None
                    )
                ]
            ),
        )
        dump(
            "RewindTargetsData",
            RewindTargetsData(targets=[RewindTarget(entry_id="e1", text="hello")]),
        )
        dump(
            "ExtensionCommandsData",
            ExtensionCommandsData(
                commands=[ExtensionCommandInfo(name="permission", description="d")]
            ),
        )
        dump(
            "EmptySuccessResponse",
            EmptySuccessResponse(request_type="prompt", id="req_1"),
        )
        dump(
            "RpcPayloadResponse",
            RpcPayloadResponse(
                request_type="get_state",
                id="req_2",
                data=SessionState(model="Minimax M3"),
            ),
        )
        dump(
            "RpcErrorResponse",
            RpcErrorResponse(request_type="prompt", id="req_3", error="boom"),
        )
        dump(
            "ExtensionUIRequest (select)",
            ExtensionUIRequest(
                id="ab12cd",
                payload=SelectUIRequestPayload(title="t", options=["Yes", "No"]),
            ),
        )
        dump(
            "ExtensionUIRequest (notify)",
            ExtensionUIRequest(
                id="ab12cd",
                payload=NotifyUIRequestPayload(message="m", notify_type="warning"),
            ),
        )
        dump("ExtensionUIResponse", ExtensionUIResponse(id="ab12cd", value="Yes"))
    except Exception as exc:  # pragma: no cover - import chain may need httpx
        print(f"  (skipped: {type(exc).__name__}: {exc})")


if __name__ == "__main__":
    main()
