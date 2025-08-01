defmodule DspyWeb.HotswapControlLive do
  use DspyWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, modules: [], page_title: "Hotswap Control")}
  end

  def render(assigns) do
    ~H"""
    <div class="hotswap-control-container">
      <h1>Hotswap Control Panel</h1>
      <p>Module hotswapping controls will appear here.</p>
    </div>
    """
  end
end