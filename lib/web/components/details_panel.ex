defmodule Observer.Web.Components.DetailsPanel do
  @moduledoc """
  Bottom-docked panel that slides up to show the details of whatever row/identifier a page's
  user just selected (an ETS table, a process, a port, ...), with collapse/expand/close controls.
  Each page keeps its own selection state and event names; this component only renders the
  shared chrome around whatever content the caller puts in its `inner_block` slot.
  """
  use Phoenix.Component

  alias Observer.Web.Components.Icons
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :expand_id, :string, required: true
  attr :collapse_id, :string, required: true
  attr :close_id, :string, required: true
  attr :collapsed, :boolean, required: true
  attr :expanded, :boolean, required: true
  attr :expand_event, :string, required: true
  attr :collapse_event, :string, required: true
  attr :close_event, :string, required: true

  slot :title, required: true
  slot :inner_block, required: true

  def content(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={
        JS.transition(
          {"transition-transform duration-300 ease-out", "translate-y-full", "translate-y-0"}
        )
      }
      class={[
        "fixed inset-x-0 bottom-0 z-30 flex flex-col bg-base-100 border-t border-base-300 shadow-2xl",
        @expanded && "max-h-[92vh]",
        !@expanded && "max-h-[70vh]"
      ]}
    >
      <div class="flex items-center justify-between px-4 py-2 border-b border-base-300 shrink-0">
        <h2 class="text-sm font-semibold text-base-content">
          {render_slot(@title)}
        </h2>
        <div class="flex items-center gap-x-3">
          <button
            :if={not @collapsed}
            id={@expand_id}
            type="button"
            aria-label={if @expanded, do: "Shrink details panel", else: "Expand details panel"}
            title={if @expanded, do: "Shrink", else: "Expand"}
            phx-click={@expand_event}
            class="inline-flex text-muted focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary focus:text-base-content transition ease-in-out duration-150"
          >
            <%= if @expanded do %>
              <Icons.arrows_pointing_in class="w-5 h-5" />
            <% else %>
              <Icons.arrows_pointing_out class="w-5 h-5" />
            <% end %>
          </button>
          <button
            id={@collapse_id}
            type="button"
            aria-label={if @collapsed, do: "Restore details panel", else: "Minimize details panel"}
            title={if @collapsed, do: "Restore", else: "Minimize"}
            phx-click={@collapse_event}
            class="inline-flex text-muted focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary focus:text-base-content transition ease-in-out duration-150"
          >
            <%= if @collapsed do %>
              <Icons.chevron_up class="w-5 h-5" />
            <% else %>
              <Icons.chevron_down class="w-5 h-5" />
            <% end %>
          </button>
          <button
            id={@close_id}
            type="button"
            aria-label="Close details panel"
            title="Close"
            phx-click={@close_event}
            class="inline-flex text-muted focus:outline-none focus:ring-1 focus:ring-primary focus:border-primary focus:text-base-content transition ease-in-out duration-150"
          >
            <Icons.x_mark class="w-5 h-5" />
          </button>
        </div>
      </div>

      <div :if={not @collapsed} class="overflow-y-auto">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Bottom padding for the page's root container, so the docked panel never overlaps the page's
  own content. Sized to match the panel's own collapsed/expanded height.
  """
  def padding_class(shown?, collapsed?, expanded?)
  def padding_class(false, _collapsed?, _expanded?), do: nil
  def padding_class(true, true, _expanded?), do: "pb-16"
  def padding_class(true, false, true), do: "pb-[92vh]"
  def padding_class(true, false, false), do: "pb-[70vh]"
end
