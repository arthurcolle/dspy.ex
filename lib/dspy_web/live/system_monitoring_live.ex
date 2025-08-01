defmodule DspyWeb.SystemMonitoringLive do
  use DspyWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, metrics: %{}, page_title: "System Monitoring")}
  end

  def render(assigns) do
    ~H"""
    <div class="system-monitoring-container">
      <h1>System Monitoring</h1>
      <p>Real-time system metrics will appear here.</p>
    </div>
    """
  end
end