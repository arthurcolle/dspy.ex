defmodule Dspy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Dspy.Settings, []}
    ]

    opts = [strategy: :one_for_one, name: Dspy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end