defmodule Observer.Web.Components.SettingsPanel do
  @moduledoc """
  A toolbar "Settings" popover: a button that toggles a small form panel open, closing again on
  click-away or Escape. Purely client-side (`Phoenix.LiveView.JS`), so opening/closing never
  round-trips to the server. Each page supplies its own form as the `inner_block` slot.
  """
  use Phoenix.Component

  alias Observer.Web.Components.Icons
  alias Phoenix.LiveView.JS

  attr :id, :string, required: true, doc: "prefix for this popover's wrap/toggle/panel ids"
  attr :label, :string, required: true, doc: "title/aria-label for the toggle button"

  slot :inner_block, required: true

  def content(assigns) do
    panel_id = "#{assigns.id}-panel"

    assigns = assign(assigns, panel_id: panel_id)

    ~H"""
    <div
      id={"#{@id}-wrap"}
      class="relative inline-flex shrink-0"
      phx-click-away={JS.hide(to: "##{@panel_id}")}
      phx-window-keydown={JS.hide(to: "##{@panel_id}")}
      phx-key="escape"
    >
      <button
        type="button"
        id={"#{@id}-toggle"}
        title={@label}
        aria-label={@label}
        phx-click={
          JS.toggle(to: "##{@panel_id}", in: "ease-in duration-150", out: "ease-out duration-100")
        }
        class="inline-flex items-center gap-x-1 text-xs font-semibold text-muted hover:text-base-content border border-base-300 rounded px-2 py-1"
      >
        Settings <Icons.chevron_down class="w-3 h-3" />
      </button>
      <div
        id={@panel_id}
        class="hidden absolute left-full top-0 ml-2 z-40 w-56 rounded-md shadow-lg bg-base-100 border border-base-300 p-3"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
