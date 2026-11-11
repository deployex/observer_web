defmodule Observer.Web.Components.MultiSelect do
  @moduledoc """
  Multi select box
  """
  use Phoenix.Component

  alias Observer.Web.Components.Icons
  alias Observer.Web.Helpers
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :selected_text, :string, required: true
  attr :selected, :list, required: true
  attr :unselected, :list, required: true
  attr :show_options, :boolean, required: true

  def content(assigns) do
    panel_id = "#{assigns.id}-panel"

    close = JS.hide(to: "##{panel_id}") |> JS.push("close-options")

    toggle =
      JS.toggle(to: "##{panel_id}", in: "ease-in duration-150", out: "ease-out duration-100")
      |> JS.push("toggle-options")

    assigns = assign(assigns, panel_id: panel_id, close: close, toggle: toggle)

    ~H"""
    <div
      id={@id}
      class="relative"
      phx-click-away={@close}
      phx-window-keydown={@close}
      phx-key="escape"
    >
      <div class="flex flex-wrap items-center gap-1 px-2 py-1 border border-base-300 rounded-md bg-base-200 text-xs">
        <span class="text-muted shrink-0">{@selected_text}</span>

        <%= for item <- @selected do %>
          <%= for key <- item.keys do %>
            <span class="inline-flex items-center gap-x-1 pl-1.5 pr-1 py-0.5 rounded border border-base-300 bg-base-100 text-base-content">
              {"#{item.name}:#{key}"}
              <button
                id={Helpers.normalize_id("#{@id}-#{item.name}-#{key}-remove-item")}
                type="button"
                phx-click="multi-select-remove-item"
                phx-value-key={key}
                phx-value-item={item.name}
                class="text-muted hover:text-base-content"
              >
                <Icons.x_mark class="w-3 h-3" />
              </button>
            </span>
          <% end %>
        <% end %>

        <button
          type="button"
          id={Helpers.normalize_id("#{@id}-toggle-options")}
          phx-click={@toggle}
          class="ml-auto inline-flex items-center text-muted hover:text-base-content"
        >
          <%= if @show_options do %>
            <Icons.chevron_up class="w-3.5 h-3.5" />
          <% else %>
            <Icons.chevron_down class="w-3.5 h-3.5" />
          <% end %>
        </button>
      </div>

      <div
        id={@panel_id}
        class={[
          "absolute left-0 top-full mt-1 z-40 w-64 max-h-72 overflow-y-scroll rounded-md border border-base-300 bg-base-100 shadow-lg divide-y divide-base-200",
          !@show_options && "hidden"
        ]}
      >
        <div :for={item <- @unselected} class="py-1">
          <div class="px-3 py-1 text-[0.65rem] font-semibold uppercase tracking-wide text-muted">
            {item.name}
          </div>
          <button
            :for={key <- item.keys}
            id={Helpers.normalize_id("#{@id}-#{item.name}-#{key}-add-item")}
            type="button"
            phx-click="multi-select-add-item"
            phx-value-key={key}
            phx-value-item={item.name}
            class={[
              "w-full flex items-center px-3 py-1 text-left text-xs border-l-2 hover:bg-base-200",
              highlighted?(key, item.unselected_highlight) && "border-success",
              !highlighted?(key, item.unselected_highlight) && "border-transparent"
            ]}
          >
            <span class="truncate text-base-content">{key}</span>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp highlighted?(key, unselected_highlight), do: key in unselected_highlight
end
