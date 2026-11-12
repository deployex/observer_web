defmodule Observer.Web.Components.MultiSelectList do
  @moduledoc """
  Multi select list box, with a per-group search filter - the Tracing/Profiling pages' version of
  `Observer.Web.Components.MultiSelect`, kept as a separate component because it supports up to
  four groups, each with its own search box and an optional extra info label.
  """
  use Phoenix.Component

  alias Observer.Web.Components.Core
  alias Observer.Web.Components.Icons
  alias Observer.Web.Helpers
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :selected_text, :string, required: true
  attr :selected, :list, required: true
  attr :unselected, :list, required: true
  attr :show_options, :boolean, required: true
  attr :form_search, :map, default: %{}

  def content(assigns) do
    elements_to_filter = Map.keys(assigns.form_search.params)

    filtered_unselected =
      Enum.map(assigns.unselected, fn %{name: name, keys: keys} = element ->
        if name in elements_to_filter do
          key_to_find = String.downcase(assigns.form_search.params[name])

          filtered_keys =
            Enum.filter(keys, &String.contains?(String.downcase(&1), key_to_find))

          %{element | keys: filtered_keys}
        else
          element
        end
      end)

    panel_id = "#{assigns.id}-panel"

    close = JS.hide(to: "##{panel_id}") |> JS.push("close-options")

    toggle =
      JS.toggle(to: "##{panel_id}", in: "ease-in duration-150", out: "ease-out duration-100")
      |> JS.push("toggle-options")

    assigns =
      assigns
      |> assign(elements_to_filter: elements_to_filter)
      |> assign(unselected: filtered_unselected)
      |> assign(panel_id: panel_id, close: close, toggle: toggle)

    ~H"""
    <div
      id={@id}
      class="relative inline-flex shrink-0"
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
          id={"#{@id}-toggle-options"}
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
          "absolute left-0 top-full mt-1 z-40 flex gap-2 p-2 rounded-md border border-base-300 bg-base-100 shadow-lg max-w-[90vw] overflow-x-auto",
          !@show_options && "hidden"
        ]}
      >
        <div
          :for={item <- @unselected}
          :if={@show_options}
          class="w-72 shrink-0 max-h-72 overflow-y-scroll rounded border border-base-300"
        >
          <div class="sticky top-0 z-10 bg-base-100 border-b border-base-200 p-1.5">
            <div class="text-[0.65rem] font-semibold uppercase tracking-wide text-muted">
              {item.name}{if item[:info], do: item.info}
            </div>
            <.form
              :if={item.name in @elements_to_filter}
              for={@form_search}
              id={"multi-select-list-search-form-#{@id}-#{item.name}"}
              phx-change="form-multi-select-list-update-search"
            >
              <Core.input
                field={@form_search[item.name]}
                type="text-custom-search"
                placeholder="search..."
              />
            </.form>
          </div>
          <div class="flex flex-wrap gap-1 p-1.5">
            <button
              :for={key <- item.keys}
              id={Helpers.normalize_id("#{@id}-#{item.name}-#{key}-add-item")}
              type="button"
              phx-click="multi-select-add-item"
              phx-value-key={key}
              phx-value-item={item.name}
              class="inline-flex items-center px-2 py-0.5 rounded-full border border-base-300 text-xs text-base-content hover:bg-base-200"
            >
              {key}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
