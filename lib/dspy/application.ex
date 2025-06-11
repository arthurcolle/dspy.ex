defmodule Dspy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Dspy.Settings, []},
      {Registry, keys: :unique, name: Dspy.MultiAgentChat.Registry},
      {Dspy.MultiAgentLogger, []},
      {Task, fn -> configure_language_model() end}
    ]

    opts = [strategy: :one_for_one, name: Dspy.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)
    
    # Give a moment for Settings to start then configure
    Process.sleep(100)
    configure_language_model()
    
    {:ok, pid}
  end
  
  defp configure_language_model do
    case Application.get_env(:dspy, :lm) do
      %{module: module, api_key: api_key, model: model} = config ->
        lm = module.new([
          api_key: api_key,
          model: model
        ])
        
        :ok = Dspy.Settings.configure([
          lm: lm,
          max_tokens: Map.get(config, :max_tokens, 2048),
          temperature: Map.get(config, :temperature, 0.0)
        ])
        
        IO.puts("✅ DSPy LM configured: #{model}")
        
      _ ->
        IO.puts("⚠️  No LM configuration found")
    end
  rescue
    error ->
      IO.puts("❌ Failed to configure LM: #{inspect(error)}")
  end
end
