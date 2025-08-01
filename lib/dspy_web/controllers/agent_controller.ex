defmodule DspyWeb.AgentController do
  use DspyWeb, :controller

  def spawn_swarm(conn, %{"count" => count} = _params) do
    agents = for i <- 1..count do
      %{
        id: "agent_#{i}_#{System.unique_integer([:positive])}",
        status: "active",
        created_at: DateTime.utc_now()
      }
    end
    
    json(conn, %{status: "success", agents: agents})
  end

  def agent_status(conn, %{"id" => id}) do
    status = %{
      id: id,
      status: "active",
      memory_usage: :rand.uniform(100),
      cpu_usage: :rand.uniform(100),
      tasks_completed: :rand.uniform(50),
      uptime_seconds: :rand.uniform(3600)
    }
    
    json(conn, status)
  end

  def terminate_agent(conn, %{"id" => id}) do
    json(conn, %{status: "success", message: "Agent #{id} terminated"})
  end
end