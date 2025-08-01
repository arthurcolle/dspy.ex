defmodule DspyWeb.AgentSwarmLive do
  use DspyWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, agents: [], page_title: "Agent Swarm")}
  end

  def render(assigns) do
    ~H"""
    <div class="agent-swarm-container">
      <h1>Agent Swarm Management</h1>
      <p>No agents currently active.</p>
    </div>
    """
  end
end