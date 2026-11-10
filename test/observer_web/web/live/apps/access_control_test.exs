defmodule Observer.Web.Apps.AccessControlTest do
  use Observer.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  alias Observer.Web.AccessError
  alias Observer.Web.Helpers
  alias Observer.Web.Mocks.RpcStubber
  alias Observer.Web.Mocks.TelemetryStubber

  setup [
    :set_mox_global,
    :verify_on_exit!
  ]

  # These actions are rejected before the UI ever renders a control for them (the button is
  # `disabled`, which Phoenix.LiveViewTest itself refuses to click), so the only way to prove the
  # server-side guard holds on its own is to send the underlying event directly, the same way a
  # client bypassing the UI would. That crashes the LiveView: `render_click/3`'s own call may
  # exit synchronously (caught below) and/or the link `live/2` set up delivers the crash as an
  # `:EXIT` message instead of taking this test process down with it (trapped below) - either
  # way is fine, so both are handled rather than relying on which one happens to fire first.
  defp assert_blocked(view, event, value) do
    Process.flag(:trap_exit, true)

    catch_exit(render_click(view, event, value))

    assert_receive {:EXIT, _pid, {%AccessError{}, _stacktrace}}
  end

  # Stubs the RPC/telemetry calls the applications page makes while mounting, then mounts it
  # and selects a single running process, returning the view.
  defp mount_with_selected_process(conn) do
    node = Node.self() |> to_string
    service = Helpers.normalize_id(node)
    test_pid_process = self()

    ObserverWeb.RpcMock
    |> stub(:call, fn node, module, function, args, timeout ->
      :rpc.call(node, module, function, args, timeout)
    end)
    |> stub(:pinfo, fn pid, information ->
      send(test_pid_process, {:apps_page_pid, self()})
      :rpc.pinfo(pid, information)
    end)

    TelemetryStubber.defaults()

    {:ok, index_live, _html} = live(conn, "/observer-read-only/applications")

    index_live
    |> element("#apps-multi-select-toggle-options")
    |> render_click()

    index_live
    |> element("#apps-multi-select-apps-kernel-add-item")
    |> render_click()

    index_live
    |> element("#apps-multi-select-services-#{service}-add-item")
    |> render_click()

    pid = Enum.random(:erlang.processes())
    id = "#{inspect(pid)}"
    series_name = "#{Node.self()}::app:kernel"

    assert_receive {:apps_page_pid, apps_page_pid}, 1_000

    send(apps_page_pid, {"request-process", %{"id" => id, "series_name" => series_name}})

    index_live
  end

  # Same as above, but selects an open port instead of a process.
  defp mount_with_selected_port(conn) do
    node = Node.self() |> to_string
    service = Helpers.normalize_id(node)
    test_pid_process = self()

    ObserverWeb.RpcMock
    |> stub(:call, fn node, module, function, args, timeout ->
      :rpc.call(node, module, function, args, timeout)
    end)
    |> stub(:pinfo, fn pid, information ->
      send(test_pid_process, {:apps_page_pid, self()})
      :rpc.pinfo(pid, information)
    end)

    TelemetryStubber.defaults()

    {:ok, index_live, _html} = live(conn, "/observer-read-only/applications")

    index_live
    |> element("#apps-multi-select-toggle-options")
    |> render_click()

    index_live
    |> element("#apps-multi-select-apps-kernel-add-item")
    |> render_click()

    index_live
    |> element("#apps-multi-select-services-#{service}-add-item")
    |> render_click()

    # The port only needs to exist long enough for the assertion - the test doesn't let it
    # outlive the case either way, so what it's spawned from doesn't matter.
    port = Port.open({:spawn, "cat"}, [:binary])
    id = "#{inspect(port)}"
    series_name = "#{Node.self()}::app:kernel"

    assert_receive {:apps_page_pid, apps_page_pid}, 1_000

    send(apps_page_pid, {"request-process", %{"id" => id, "series_name" => series_name}})

    {index_live, port}
  end

  test "read-only access blocks killing a process", %{conn: conn} do
    index_live = mount_with_selected_process(conn)

    assert_blocked(index_live, "request_process_action", %{"action" => "kill"})
  end

  test "read-only access blocks garbage collecting a process", %{conn: conn} do
    index_live = mount_with_selected_process(conn)

    assert_blocked(index_live, "request_process_action", %{"action" => "garbage_collect"})
  end

  test "read-only access blocks sending a message to a process", %{conn: conn} do
    index_live = mount_with_selected_process(conn)

    assert_blocked(index_live, "request_process_action", %{
      "process-send-message" => "{:hello, :world}"
    })
  end

  test "read-only access blocks closing a port", %{conn: conn} do
    {index_live, port} = mount_with_selected_port(conn)

    assert_blocked(index_live, "request_port_action", %{"action" => "kill"})

    assert Port.info(port)
    Port.close(port)
  end

  test "read-only access blocks starting a trace session", %{conn: conn} do
    RpcStubber.defaults()
    TelemetryStubber.defaults()

    {:ok, index_live, _html} = live(conn, "/observer-read-only/tracing")

    assert_blocked(index_live, "tracing-apps-run", %{})
  end

  test "read-only access blocks starting a profiling session", %{conn: conn} do
    RpcStubber.defaults()
    TelemetryStubber.defaults()

    {:ok, index_live, _html} = live(conn, "/observer-read-only/profiling")

    assert_blocked(index_live, "profiling-run", %{})
  end
end
