defmodule Observer.Web.Apps.ProcessActions do
  @moduledoc """
  Component for managing process actions like killing, garbage collecting, sending messages, and monitoring.
  """

  use Observer.Web, :html

  alias Observer.Web.Resolver

  attr :id, :map, required: true
  attr :on_action, :any, required: true
  attr :form, :map, required: true
  attr :memory_monitor, :boolean, required: true
  attr :node, :atom, required: true
  attr :access, :any, required: true

  def content(assigns) do
    ~H"""
    <div class="text-sm text-center block rounded bg-base-100 border border-solid border-base-300 shadow-secondary-1 text-surface">
      <div class="font-mono font-semibold border-b-1 rounded-t border-neutral-100 px-6 py-1 bg-zinc-200 dark:bg-zinc-500">
        Process Actions
      </div>

      <div class="space-y-3 p-1">
        <div class="grid grid-cols-2 gap-3">
          <button
            id="process-clean-memory-button"
            phx-click={@on_action}
            phx-value-action="garbage_collect"
            disabled={not Resolver.can?(:garbage_collect_process, @access)}
            class={
              "flex items-center justify-center gap-2 px-4 py-2 bg-base-200 hover:bg-base-300 text-base-content text-sm font-semibold rounded-lg border border-base-300 shadow-sm hover:shadow transition-all duration-200 active:scale-95 tooltip " <>
                Core.gated_classes()
            }
            title="Run garbage collection on this process"
          >
            <span>🧹</span>
            <span>Clean Memory</span>
          </button>

          <button
            id="process-kill-button"
            phx-click={@on_action}
            phx-value-action="kill"
            disabled={not Resolver.can?(:kill_process, @access)}
            class={
              "flex items-center justify-center gap-2 px-4 py-2 bg-base-200 hover:bg-base-300 text-base-content text-sm font-semibold rounded-lg border border-base-300 shadow-sm hover:shadow transition-all duration-200 active:scale-95 tooltip " <>
                Core.gated_classes()
            }
            title="Terminate the selected process"
          >
            <span>⛔</span>
            <span>Kill</span>
          </button>
        </div>
      </div>

      <div class="p-1">
        <.form
          for={@form}
          phx-submit={@on_action}
          id="process-send-msg-form"
          phx-change="process-message-form-update"
        >
          <div class={["w-full min-w-[200px] relative"]}>
            <div class="relative">
              <input
                type="text"
                name="process-send-message"
                value={@form.params["message"]}
                class={[
                  "w-full bg-transparent placeholder:text-slate-400 text-slate-700 text-sm border rounded-md pl-3 pr-20 py-2 transition duration-300 ease focus:outline-none shadow-sm focus:shadow",
                  border_error(@form.errors != []),
                  "tooltip"
                ]}
                placeholder="Type a valid elixir message"
                title="Send a message to the process"
              />

              <button
                type="submit"
                id="process-send-message-button"
                phx-disable-with="Sending..."
                class={
                  "absolute right-1 top-1 rounded bg-slate-800 py-1 px-2.5 border border-transparent text-center text-sm text-white transition-all shadow-sm hover:shadow focus:bg-slate-700 focus:shadow-none active:bg-slate-700 hover:bg-slate-700 active:shadow-none " <>
                    Core.gated_classes()
                }
                disabled={
                  @form.errors != [] or @form.params["message"] == "" or
                    not Resolver.can?(:send_message, @access)
                }
              >
                Send
              </button>
            </div>
          </div>
        </.form>
      </div>

      <label class="flex me-5 p-1 cursor-pointer">
        <input
          type="checkbox"
          phx-click={@on_action}
          phx-value-type="toggle-memory"
          name="process-toggle-memory-monitoring-checkbox"
          value=""
          class="sr-only peer"
          checked={@memory_monitor}
        />
        <div class="relative w-11 h-6 bg-base-300 rounded-full peer peer-focus:ring-4 peer-focus:ring-primary/30 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-[2px] after:bg-white after:border-base-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary">
        </div>
        <span class="ms-3 text-sm font-medium text-base-content">Memory Monitor</span>
      </label>

      <div>
        <p class="text-xs text-muted mt-3 italic">
          Node: <span class="font-mono text-base-content">{@node}</span>
        </p>
        <p class="text-xs text-muted p-1 italic">
          Process ID: <span class="font-mono text-base-content">{process_info(@node, @id)}</span>
        </p>
      </div>
    </div>
    """
  end

  defp border_error(true), do: "border-error focus:border-error hover:border-error"
  defp border_error(_false), do: "border-slate-200 focus:border-slate-400 hover:border-slate-300"

  defp process_info(node, id) do
    if node == node(), do: "#{id} (local)", else: "#{id} (remote)"
  end
end
