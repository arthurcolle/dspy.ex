defmodule Dspy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Dspy.Settings, []},
      {Registry, keys: :unique, name: Dspy.MultiAgentChat.Registry}
    ]
    
    # Only start MultiAgentLogger if explicitly enabled
    children = 
      if Application.get_env(:dspy, :enable_multi_agent_logger, false) do
        children ++ [{Dspy.MultiAgentLogger, []}]
      else
        children
      end

    opts = [strategy: :one_for_one, name: Dspy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
