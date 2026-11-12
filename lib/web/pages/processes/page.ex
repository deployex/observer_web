defmodule Observer.Web.Processes.Page do
  @moduledoc """
  This is the live component responsible for the Processes pillar: an etop-style, auto-refreshing
  table of the busiest processes on a selected node, ranked by reductions (delta per refresh
  interval), memory or message queue length, with a per-process drill-down panel.

  Refresh ticks carry a generation counter: changing any control bumps the generation and starts
  a new timer chain, so a tick from a cancelled chain that was already in flight is ignored
  instead of spawning a second chain.
  """

  @behaviour Observer.Web.Page

  use Observer.Web, :live_component

  alias Observer.Web.Components.Core
  alias Observer.Web.Components.DetailsPanel
  alias Observer.Web.Components.Toolbar
  alias Observer.Web.Page
  alias ObserverWeb.Processes

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class={[
      "min-h-screen bg-base-100",
      DetailsPanel.padding_class(!!@details, @details_panel_collapsed, @details_panel_expanded)
    ]}>
      <Toolbar.content>
        <.form
          for={@form}
          id="processes-update-form"
          class="flex flex-col md:flex-row md:items-end shrink-0 text-xs text-center text-base-content whitespace-nowrap gap-x-5 gap-y-1"
          phx-change="form-update"
        >
          <Core.input
            field={@form[:service]}
            type="select"
            label="Service"
            options={@services}
          />

          <Core.input
            field={@form[:sort_by]}
            type="select"
            label="Sort by"
            options={[
              {"Reductions", "reductions"},
              {"Memory", "memory"},
              {"Message Queue", "message_queue_len"}
            ]}
          />

          <Core.input
            field={@form[:limit]}
            type="select"
            label="Top"
            options={[{"25", "25"}, {"50", "50"}, {"100", "100"}, {"250", "250"}]}
          />

          <Core.input
            field={@form[:refresh_seconds]}
            type="select"
            label="Refresh"
            options={[{"Paused", "0"}, {"2s", "2"}, {"5s", "5"}, {"10s", "10"}]}
          />

          <Core.input field={@form[:search]} type="text" label="Search" phx-debounce="300" />
        </.form>

        <button
          id="processes-refresh"
          phx-click="processes-refresh"
          class={Core.action_button_class()}
        >
          REFRESH
        </button>
      </Toolbar.content>

      <div class="p-2">
        <div :if={@sample_error} class="p-4 text-sm text-error">
          Could not sample {@form.params["service"]}: {inspect(@sample_error)}
        </div>

        <div
          :if={@summary == nil and @sample_error == nil}
          class="p-4 text-sm text-muted"
        >
          Collecting processes...
        </div>

        <div :if={@summary} class="flex flex-wrap gap-2 px-2 pb-2 text-xs">
          <span class={Core.badge_class()}>
            Processes: {@summary.process_count}
          </span>
          <span class={Core.badge_class()}>
            Run Queue: {@summary.run_queue}
          </span>
          <span
            :for={key <- [:total, :processes, :ets, :binary, :atom, :code]}
            class={Core.badge_class()}
          >
            {key}: {format_bytes(Map.get(@summary.memory, key, 0))}
          </span>
          <span :if={search_active?(@form)} class={Core.badge_class(:neutral)}>
            Showing: {length(@rows)}
          </span>
        </div>

        <div :if={@rows != []} class="bg-base-100 w-full shadow-lg rounded">
          <Core.table_tracing id="processes-results" rows={Enum.with_index(@rows)}>
            <:col :let={{row, _index}} label="NAME"><Core.truncated value={row.name} /></:col>
            <:col :let={{row, _index}} label="PID">{inspect(row.pid)}</:col>
            <:col :let={{row, _index}} label="MEMORY">{format_bytes(row.memory)}</:col>
            <:col :let={{row, _index}} label={reductions_label(@form.params["sort_by"])}>
              {row.reductions_diff}
            </:col>
            <:col :let={{row, _index}} label="MSG QUEUE">{row.message_queue_len}</:col>
            <:col :let={{row, _index}} label="CURRENT FUNCTION">
              <Core.truncated value={row.current_function} />
            </:col>
            <:col :let={{_row, index}} label="">
              <button
                id={"processes-select-row-#{index}"}
                phx-click="processes-select-row"
                phx-value-index={index}
                class="text-xs font-semibold text-primary border border-primary rounded px-2.5 py-1 hover:bg-primary hover:text-primary-content transition-colors"
              >
                DETAILS
              </button>
            </:col>
          </Core.table_tracing>
        </div>

        <DetailsPanel.content
          :if={@details}
          id="processes-details-panel"
          expand_id="processes-details-panel-expand"
          collapse_id="processes-details-panel-collapse"
          close_id="processes-details-close"
          collapsed={@details_panel_collapsed}
          expanded={@details_panel_expanded}
          expand_event="processes-details-panel-expand"
          collapse_event="processes-details-panel-collapse"
          close_event="processes-details-close"
        >
          <:title>Process {inspect(@details.pid)}</:title>

          <div class="p-2">
            <div :if={@details.info == :not_found} class="p-4 text-sm text-muted">
              The process has exited.
            </div>
            <table :if={is_list(@details.info)} class="w-full text-left text-xs m-2">
              <tbody>
                <tr :for={{key, value} <- @details.info} class="align-top">
                  <td class="py-1 pr-4 font-semibold text-base-content whitespace-nowrap capitalize">
                    {key}
                  </td>
                  <td class="py-1 text-base-content whitespace-pre-wrap break-all">
                    {value}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </DetailsPanel.content>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) when is_connected?(socket) do
    :net_kernel.monitor_nodes(true)

    send(self(), {:processes_tick, 1})

    socket
    |> assign_defaults()
    |> assign(:tick_gen, 1)
  end

  def handle_mount(socket) do
    socket
    |> assign_defaults()
    |> assign(:tick_gen, 0)
  end

  defp assign_defaults(socket) do
    socket
    |> assign(:services, services())
    |> assign(:rows, [])
    |> assign(:summary, nil)
    |> assign(:previous_reductions, %{})
    |> assign(:details, nil)
    |> assign(:details_panel_collapsed, false)
    |> assign(:details_panel_expanded, false)
    |> assign(:sample_error, nil)
    |> assign(:form, to_form(default_form_options()))
  end

  @impl Page
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Processes")
  end

  @impl Page
  def handle_parent_event("form-update", params, socket) do
    service_changed? = params["service"] != socket.assigns.form.params["service"]

    socket =
      if service_changed? do
        socket
        |> assign(:previous_reductions, %{})
        |> assign(:details, nil)
        |> assign(:summary, nil)
        |> assign(:rows, [])
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:form, to_form(params))
     |> restart_tick_chain()}
  end

  def handle_parent_event("processes-refresh", _params, socket) do
    {:noreply, restart_tick_chain(socket)}
  end

  def handle_parent_event("processes-select-row", %{"index" => index}, socket) do
    case Enum.at(socket.assigns.rows, positive_int(index, 0)) do
      nil ->
        {:noreply, socket}

      row ->
        {:noreply,
         socket
         |> assign(:details, fetch_details(row.pid))
         |> assign(:details_panel_collapsed, false)
         |> assign(:details_panel_expanded, false)}
    end
  end

  def handle_parent_event("processes-details-close", _params, socket) do
    {:noreply,
     socket
     |> assign(:details, nil)
     |> assign(:details_panel_collapsed, false)
     |> assign(:details_panel_expanded, false)}
  end

  def handle_parent_event("processes-details-panel-collapse", _params, socket) do
    {:noreply, assign(socket, :details_panel_collapsed, !socket.assigns.details_panel_collapsed)}
  end

  def handle_parent_event("processes-details-panel-expand", _params, socket) do
    {:noreply, assign(socket, :details_panel_expanded, !socket.assigns.details_panel_expanded)}
  end

  # Bumps the generation and fires an immediate tick - any tick still in flight from the
  # previous chain is dropped by the generation guard in handle_info/2.
  defp restart_tick_chain(socket) do
    tick_gen = socket.assigns.tick_gen + 1
    send(self(), {:processes_tick, tick_gen})

    assign(socket, :tick_gen, tick_gen)
  end

  @impl Page
  def handle_info({:processes_tick, gen}, %{assigns: %{tick_gen: gen}} = socket) do
    socket =
      case Processes.sample(selected_service(socket)) do
        {:ok, sample} -> assign_sample(socket, sample)
        {:error, reason} -> assign(socket, :sample_error, reason)
      end

    refresh_seconds = positive_int(socket.assigns.form.params["refresh_seconds"], 0)

    if refresh_seconds > 0 do
      Process.send_after(self(), {:processes_tick, gen}, refresh_seconds * 1_000)
    end

    {:noreply, socket}
  end

  def handle_info({:processes_tick, _stale_gen}, socket) do
    {:noreply, socket}
  end

  def handle_info({:nodeup, _node}, socket) do
    {:noreply, assign(socket, :services, services())}
  end

  def handle_info({:nodedown, node}, %{assigns: %{form: form}} = socket) do
    socket = assign(socket, :services, services())

    if to_string(node) == form.params["service"] do
      params = %{form.params | "service" => to_string(Node.self())}

      {:noreply,
       socket
       |> assign(:form, to_form(params))
       |> assign(:previous_reductions, %{})
       |> assign(:details, nil)
       |> restart_tick_chain()}
    else
      {:noreply, socket}
    end
  end

  defp assign_sample(socket, sample) do
    %{form: form, previous_reductions: previous_reductions, details: details} = socket.assigns

    sort_by = sort_by_atom(form.params["sort_by"])
    limit = positive_int(form.params["limit"], 50)
    search = String.downcase(form.params["search"] || "")

    filtered_sample = %{sample | processes: filter_processes(sample.processes, search)}

    rows = Processes.rank(filtered_sample, sort_by, limit, previous_reductions)

    details =
      if details do
        fetch_details(details.pid)
      end

    socket
    |> assign(:rows, rows)
    |> assign(
      :summary,
      Map.take(sample, [:process_count, :run_queue, :memory])
    )
    |> assign(:previous_reductions, Processes.reductions_by_pid(sample))
    |> assign(:details, details)
    |> assign(:sample_error, nil)
  end

  defp fetch_details(pid) do
    case Processes.details(pid) do
      {:ok, info} -> %{pid: pid, info: info}
      {:error, :not_found} -> %{pid: pid, info: :not_found}
    end
  end

  defp services do
    Enum.map([Node.self() | Node.list()], &{&1, to_string(&1)})
  end

  # The form's service value only becomes a node if it matches a currently known node - a
  # crafted payload (or a node that just left the cluster) safely falls back to the local one.
  defp selected_service(socket) do
    service = socket.assigns.form.params["service"]

    [Node.self() | Node.list()]
    |> Enum.find(Node.self(), &(to_string(&1) == service))
  end

  defp filter_processes(processes, ""), do: processes

  defp filter_processes(processes, search) do
    Enum.filter(processes, fn row ->
      String.contains?(String.downcase(row.name), search) or
        String.contains?(String.downcase(inspect(row.pid)), search) or
        String.contains?(String.downcase(row.current_function), search)
    end)
  end

  defp sort_by_atom("memory"), do: :memory
  defp sort_by_atom("message_queue_len"), do: :message_queue_len
  defp sort_by_atom(_reductions), do: :reductions

  defp positive_int(value, default) do
    case Integer.parse(value || "") do
      {int, ""} when int >= 0 -> int
      _invalid -> default
    end
  end

  defp default_form_options do
    %{
      "service" => to_string(Node.self()),
      "sort_by" => "reductions",
      "limit" => "50",
      "refresh_seconds" => "5",
      "search" => ""
    }
  end

  defp search_active?(form), do: (form.params["search"] || "") != ""

  defp reductions_label("reductions"), do: "REDUCTIONS (Δ)"
  defp reductions_label(_other), do: "REDUCTIONS"

  defp format_bytes(bytes) when bytes >= 1_073_741_824,
    do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1_024, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"
end
