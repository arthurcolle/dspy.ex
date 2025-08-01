defmodule DspyWeb.Router do
  use DspyWeb, :router

  # import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DspyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DspyWeb do
    pipe_through :browser

    live "/", GodmodeCoordinatorLive
    live "/coordinator", GodmodeCoordinatorLive
    live "/agents", AgentSwarmLive
    live "/monitoring", SystemMonitoringLive
    live "/hotswap", HotswapControlLive
    live "/analytics", PerformanceAnalyticsLive
  end

  # API routes
  scope "/api", DspyWeb do
    pipe_through :api

    post "/coordinator/execute", CoordinatorController, :execute_task
    post "/coordinator/override", CoordinatorController, :override_behavior
    post "/coordinator/hotswap", CoordinatorController, :system_hotswap
    get "/coordinator/status", CoordinatorController, :system_status
    post "/coordinator/optimize", CoordinatorController, :force_optimization
    
    post "/agents/spawn", AgentController, :spawn_swarm
    get "/agents/:id/status", AgentController, :agent_status
    delete "/agents/:id", AgentController, :terminate_agent
    
    get "/metrics/live", MetricsController, :live_metrics
    get "/metrics/history", MetricsController, :metrics_history
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  # if Application.compile_env(:dspy, :dev_routes) do
  #   scope "/dev" do
  #     pipe_through :browser

  #     live_dashboard "/dashboard", metrics: DspyWeb.Telemetry
  #   end
  # end
end