defmodule Observer.Web.Ets.Page do
  @moduledoc """
  This is the live component responsible for the ETS pillar: every ETS table on a selected node
  with its metadata (owner, protection, type, size, memory), searchable and sortable, plus an
  optional bounded content preview gated behind the `:table_content_inspection` config (see
  `ObserverWeb.Ets` - table contents are live production data, so previews are off by default).
  """

  @behaviour Observer.Web.Page

  use Observer.Web, :live_component

  alias Observer.Web.Components.Core
  alias Observer.Web.Components.DetailsPanel
  alias Observer.Web.Components.Toolbar
  alias Observer.Web.Page
  alias ObserverWeb.Ets
  alias ObserverWeb.Mnesia

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns = assign(assigns, :source, source_atom(assigns.form.params["source"]))

    ~H"""
    <div class={[
      "min-h-screen bg-base-100",
      DetailsPanel.padding_class(!!@details, @details_panel_collapsed, @details_panel_expanded)
    ]}>
      <Toolbar.content>
        <.form
          for={@form}
          id="ets-update-form"
          class="flex flex-col md:flex-row md:items-end shrink-0 text-xs text-center text-base-content whitespace-nowrap gap-x-5 gap-y-1"
          phx-change="form-update"
        >
          <Core.input
            field={@form[:source]}
            type="select"
            label="Source"
            options={[{"ETS", "ets"}, {"Mnesia", "mnesia"}]}
          />

          <Core.input field={@form[:service]} type="select" label="Service" options={@services} />

          <Core.input
            field={@form[:sort_by]}
            type="select"
            label="Sort by"
            options={[{"Memory", "memory"}, {"Size", "size"}, {"Name", "name"}]}
          />

          <Core.input field={@form[:search]} type="text" label="Search" phx-debounce="300" />
        </.form>

        <button
          id="ets-refresh"
          phx-click="ets-refresh"
          class={Core.action_button_class()}
        >
          REFRESH
        </button>
      </Toolbar.content>

      <div class="p-2">
        <div
          :if={@tables_error == :mnesia_not_running}
          class="p-4 text-sm text-muted"
        >
          Mnesia is not running on {@form.params["service"]}.
        </div>
        <div
          :if={@tables_error && @tables_error != :mnesia_not_running}
          class="p-4 text-sm text-error"
        >
          Could not list tables on {@form.params["service"]}: {inspect(@tables_error)}
        </div>

        <div
          :if={@tables == nil and @tables_error == nil}
          class="p-4 text-sm text-muted"
        >
          Collecting ETS tables...
        </div>

        <div :if={@tables} class="flex flex-wrap gap-2 px-2 pb-2 text-xs">
          <span class={Core.badge_class()}>
            Tables: {length(@tables)}
          </span>
          <span class={Core.badge_class()}>
            Total memory: {format_bytes(Enum.sum(Enum.map(@tables, & &1.memory)))}
          </span>
          <span
            :if={@rows != nil and length(@rows) != length(@tables)}
            class={Core.badge_class(:neutral)}
          >
            Showing: {length(@rows)}
          </span>
        </div>

        <div
          :if={@rows != nil and @rows != []}
          class="bg-base-100 w-full shadow-lg rounded"
        >
          <Core.table_tracing id="ets-results" rows={Enum.with_index(@rows)}>
            <:col :let={{table, _index}} label="NAME">
              <Core.truncated value={inspect(table.name)} />
            </:col>
            <:col :let={{table, _index}} label="TYPE">{table.type}</:col>
            <:col
              :let={{table, _index}}
              label={if @source == :mnesia, do: "STORAGE", else: "PROTECTION"}
            >
              {if @source == :mnesia, do: table.storage, else: table.protection}
            </:col>
            <:col :let={{table, _index}} label="OWNER">
              <Core.truncated value={table.owner_label} />
            </:col>
            <:col :let={{table, _index}} label="OBJECTS">{table.size}</:col>
            <:col :let={{table, _index}} label="MEMORY">{format_bytes(table.memory)}</:col>
            <:col :let={{_table, index}} label="">
              <button
                id={"ets-select-row-#{index}"}
                phx-click="ets-select-row"
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
          id="ets-details-panel"
          expand_id="ets-details-panel-expand"
          collapse_id="ets-details-panel-collapse"
          close_id="ets-details-close"
          collapsed={@details_panel_collapsed}
          expanded={@details_panel_expanded}
          expand_event="ets-details-panel-expand"
          collapse_event="ets-details-panel-collapse"
          close_event="ets-details-close"
        >
          <:title>Table {inspect(@details.table.name)}</:title>

          <div class="flex flex-wrap gap-2 px-4 py-2 text-xs">
            <span
              :for={{label, value} <- details_badges(@details.table, @source)}
              class={Core.badge_class(:neutral)}
            >
              {label}: {value}
            </span>
          </div>

          <div
            :if={@details.content == {:error, :content_inspection_disabled}}
            class="px-4 pb-4 text-xs text-muted"
          >
            Content inspection is disabled. Table contents are live production data - to enable
            bounded, read-only previews, set <code class="font-mono">config :observer_web, table_content_inspection: true</code>.
          </div>

          <div
            :if={@details.content == {:error, :not_accessible}}
            class="px-4 pb-4 text-xs text-muted"
          >
            This table's contents are not accessible (private table, or it no longer exists).
          </div>

          <div :if={match?({:ok, _}, @details.content)} class="px-4 pb-4">
            <h3 class="text-xs font-semibold text-base-content pb-1">
              First objects (bounded preview)
            </h3>
            <div :if={elem(@details.content, 1) == []} class="text-xs text-muted">
              The table is empty.
            </div>
            <ul class="text-xs font-mono text-base-content space-y-1 break-all">
              <li :for={object <- elem(@details.content, 1)}>{object}</li>
            </ul>
          </div>
        </DetailsPanel.content>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) when is_connected?(socket) do
    :net_kernel.monitor_nodes(true)

    send(self(), :ets_refresh)

    assign_defaults(socket)
  end

  def handle_mount(socket) do
    assign_defaults(socket)
  end

  defp assign_defaults(socket) do
    socket
    |> assign(:services, services())
    |> assign(:tables, nil)
    |> assign(:rows, nil)
    |> assign(:details, nil)
    |> assign(:details_panel_collapsed, false)
    |> assign(:details_panel_expanded, false)
    |> assign(:tables_error, nil)
    |> assign(
      :form,
      to_form(%{
        "source" => "ets",
        "service" => to_string(Node.self()),
        "sort_by" => "memory",
        "search" => ""
      })
    )
  end

  @impl Page
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "ETS")
  end

  @impl Page
  def handle_parent_event("form-update", params, socket) do
    service_changed? =
      params["service"] != socket.assigns.form.params["service"] or
        params["source"] != socket.assigns.form.params["source"]

    socket = assign(socket, :form, to_form(params))

    if service_changed? do
      send(self(), :ets_refresh)

      {:noreply,
       socket
       |> assign(:tables, nil)
       |> assign(:rows, nil)
       |> assign(:details, nil)}
    else
      {:noreply, assign_rows(socket)}
    end
  end

  def handle_parent_event("ets-refresh", _params, socket) do
    send(self(), :ets_refresh)

    {:noreply, socket}
  end

  def handle_parent_event("ets-select-row", %{"index" => index}, socket) do
    case Enum.at(socket.assigns.rows || [], positive_int(index, 0)) do
      nil ->
        {:noreply, socket}

      table ->
        node = selected_service(socket)

        content =
          case source(socket) do
            :mnesia -> Mnesia.table_content(node, table.name)
            :ets -> Ets.table_content(node, table.handle)
          end

        {:noreply,
         socket
         |> assign(:details, %{table: table, content: content})
         |> assign(:details_panel_collapsed, false)
         |> assign(:details_panel_expanded, false)}
    end
  end

  def handle_parent_event("ets-details-close", _params, socket) do
    {:noreply,
     socket
     |> assign(:details, nil)
     |> assign(:details_panel_collapsed, false)
     |> assign(:details_panel_expanded, false)}
  end

  def handle_parent_event("ets-details-panel-collapse", _params, socket) do
    {:noreply, assign(socket, :details_panel_collapsed, !socket.assigns.details_panel_collapsed)}
  end

  def handle_parent_event("ets-details-panel-expand", _params, socket) do
    {:noreply, assign(socket, :details_panel_expanded, !socket.assigns.details_panel_expanded)}
  end

  @impl Page
  def handle_info(:ets_refresh, socket) do
    case list_tables(socket) do
      {:ok, tables} ->
        {:noreply,
         socket
         |> assign(:tables, tables)
         |> assign(:tables_error, nil)
         |> assign_rows()}

      {:error, reason} ->
        {:noreply, assign(socket, :tables_error, reason)}
    end
  end

  def handle_info({:nodeup, _node}, socket) do
    {:noreply, assign(socket, :services, services())}
  end

  def handle_info({:nodedown, node}, %{assigns: %{form: form}} = socket) do
    socket = assign(socket, :services, services())

    if to_string(node) == form.params["service"] do
      send(self(), :ets_refresh)

      params = %{form.params | "service" => to_string(Node.self())}

      {:noreply,
       socket
       |> assign(:form, to_form(params))
       |> assign(:details, nil)}
    else
      {:noreply, socket}
    end
  end

  defp assign_rows(%{assigns: %{tables: nil}} = socket), do: socket

  defp assign_rows(%{assigns: %{tables: tables, form: form}} = socket) do
    search = String.downcase(form.params["search"] || "")

    sort_by =
      case form.params["sort_by"] do
        "size" -> :size
        "name" -> :name
        _memory -> :memory
      end

    rows =
      tables
      |> Enum.filter(
        &(search == "" or String.contains?(String.downcase(inspect(&1.name)), search))
      )
      |> sort_rows(sort_by)

    assign(socket, :rows, rows)
  end

  defp sort_rows(tables, :name), do: Enum.sort_by(tables, &inspect(&1.name))
  defp sort_rows(tables, key), do: Enum.sort_by(tables, &Map.fetch!(&1, key), :desc)

  defp source(socket), do: source_atom(socket.assigns.form.params["source"])

  defp source_atom("mnesia"), do: :mnesia
  defp source_atom(_ets), do: :ets

  defp details_badges(table, :ets) do
    [
      {"type", table.type},
      {"protection", table.protection},
      {"owner", table.owner_label},
      {"objects", table.size},
      {"memory", format_bytes(table.memory)},
      {"compressed", table.compressed}
    ]
  end

  defp details_badges(table, :mnesia) do
    [
      {"type", table.type},
      {"storage", table.storage},
      {"owner", table.owner_label},
      {"objects", table.size},
      {"memory", format_bytes(table.memory)},
      {"index", inspect(table.index)}
    ]
  end

  defp list_tables(socket) do
    node = selected_service(socket)

    case source(socket) do
      :mnesia -> Mnesia.list_tables(node)
      :ets -> Ets.list_tables(node)
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

  defp positive_int(value, default) do
    case Integer.parse(value || "") do
      {int, ""} when int >= 0 -> int
      _invalid -> default
    end
  end

  defp format_bytes(bytes) when bytes >= 1_073_741_824,
    do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1_024, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"
end
