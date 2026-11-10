defmodule Observer.Web.AccessError do
  @moduledoc """
  Raised by `Observer.Web.Resolver.enforce_access!/2` when a dashboard action is attempted
  without the access level it requires.
  """

  defexception [:message, :action]

  @impl Exception
  def exception(opts) do
    action = Keyword.fetch!(opts, :action)

    %__MODULE__{
      action: action,
      message: "the #{inspect(action)} action isn't allowed with the current access level"
    }
  end
end
