from app.services.executions_dispatcher import DispatchTask, ExecutionDispatcher


def _make_task(execution_id: str) -> DispatchTask:
    return DispatchTask(
        execution_id=execution_id,
        tenant_id="TEN-DEMO",
        device_id="device-1",
        payload={"executionId": execution_id},
    )


def test_dispatcher_enqueues_and_respects_active_task() -> None:
    dispatcher = ExecutionDispatcher()
    dispatcher.enqueue("device-1", _make_task("EXEC-1"))
    dispatcher.enqueue("device-1", _make_task("EXEC-2"))

    first = dispatcher.next_task("device-1")
    assert first is not None and first.execution_id == "EXEC-1"

    # active task prevents next_task returning new task until completed
    assert dispatcher.next_task("device-1") is None

    dispatcher.complete_task("device-1")
    second = dispatcher.next_task("device-1")
    assert second is not None and second.execution_id == "EXEC-2"


def test_dispatcher_complete_without_active_is_safe() -> None:
    dispatcher = ExecutionDispatcher()
    dispatcher.complete_task("unknown-device")  # should not raise
