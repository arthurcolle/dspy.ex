defmodule DspyWeb.MetricsController do
  use DspyWeb, :controller

  def live_metrics(conn, _params) do
    metrics = %{
      cpu_usage: System.cmd("ps", ["-o", "%cpu", "-p", "#{System.pid()}"]) |> elem(0) |> String.trim(),
      memory_usage: :erlang.memory(:total) / 1_048_576,
      process_count: :erlang.system_info(:process_count),
      timestamp: DateTime.utc_now()
    }
    
    json(conn, metrics)
  end

  def metrics_history(conn, params) do
    limit = Map.get(params, "limit", "100") |> String.to_integer()
    
    history = %{
      metrics: [],
      from: DateTime.utc_now() |> DateTime.add(-3600, :second),
      to: DateTime.utc_now(),
      limit: limit
    }
    
    json(conn, history)
  end
end