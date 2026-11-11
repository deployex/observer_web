defmodule Observer.Web.Components.Toolbar do
  @moduledoc false
  use Phoenix.Component

  slot :inner_block, required: true

  def content(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-x-3 gap-y-2 px-2 py-2 bg-base-100 border-b border-base-300">
      {render_slot(@inner_block)}
    </div>
    """
  end
end
