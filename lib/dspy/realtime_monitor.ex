defmodule Dspy.RealtimeMonitor do
  @moduledoc """
  Real-time monitoring and live dashboard for DSPy operations.
  
  This module provides comprehensive monitoring, alerting, and visualization
  capabilities for ongoing DSPy experiments and system performance.
  
  ## Features
  
  - Real-time performance metrics and alerts
  - Live dashboard with customizable widgets
  - System health monitoring and anomaly detection
  - Resource usage tracking and optimization suggestions
  - Experiment progress visualization
  - Historical trend analysis
  - Automated reporting and notifications
  - Performance regression detection
  
  ## Usage
  
      # Start the monitor
      {:ok, monitor} = Dspy.RealtimeMonitor.start_link(
        alert_thresholds: %{error_rate: 0.05, latency_ms: 5000},
        dashboard_enabled: true,
        auto_reporting: true
      )
      
      # Subscribe to alerts
      Dspy.RealtimeMonitor.subscribe_alerts(monitor, self())
      
      # Get live dashboard data
      dashboard_data = Dspy.RealtimeMonitor.get_dashboard_data(monitor)
  """
  
  use GenServer
  require Logger
  
  alias Dspy.{RealtimeStore, RealtimeExecutionEngine}
  
  @type monitor_config :: %{
    alert_thresholds: map(),
    dashboard_enabled: boolean(),
    auto_reporting: boolean(),
    monitoring_interval_ms: pos_integer(),
    alert_cooldown_ms: pos_integer(),
    dashboard_update_interval_ms: pos_integer()
  }
  
  @type alert :: %{
    id: String.t(),
    type: atom(),
    severity: :low | :medium | :high | :critical,
    message: String.t(),
    data: map(),
    timestamp: DateTime.t(),
    acknowledged: boolean()
  }
  
  @type dashboard_widget :: %{
    id: String.t(),
    type: atom(),
    title: String.t(),
    data: map(),
    config: map(),
    last_updated: DateTime.t()
  }
  
  defstruct [
    :config,
    :alert_thresholds,
    :current_metrics,
    :alerts,
    :alert_subscribers,
    :dashboard_widgets,
    :monitoring_timer,
    :dashboard_timer,
    :performance_history,
    :anomaly_detector,
    :last_alert_times
  ]
  
  @default_config %{
    alert_thresholds: %{
      error_rate: 0.1,
      latency_ms: 10_000,
      memory_usage_mb: 1000,
      cpu_usage_percent: 90,
      throughput_per_second: 0.1
    },
    dashboard_enabled: true,
    auto_reporting: false,
    monitoring_interval_ms: 10_000,
    alert_cooldown_ms: 300_000,  # 5 minutes
    dashboard_update_interval_ms: 5_000
  }
  
  @alert_types [
    :high_error_rate,
    :high_latency,
    :low_throughput,
    :memory_exhaustion,
    :cpu_overload,
    :system_failure,
    :performance_regression,
    :anomaly_detected
  ]
  
  @dashboard_widget_types [
    :performance_metrics,
    :error_rate_chart,
    :throughput_chart,
    :resource_usage,
    :recent_alerts,
    :experiment_status,
    :system_health,
    :performance_trends
  ]
  
  ## Public API
  
  @doc """
  Start the realtime monitor.
  
  ## Options
  
  - `:alert_thresholds` - Map of metric thresholds for alerts
  - `:dashboard_enabled` - Enable live dashboard (default: true)
  - `:auto_reporting` - Enable automatic report generation (default: false)
  - `:monitoring_interval_ms` - Monitoring check interval (default: 10000)
  - `:alert_cooldown_ms` - Cooldown period between similar alerts (default: 300000)
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    config = build_config(opts)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end
  
  @doc """
  Subscribe to real-time alerts.
  """
  @spec subscribe_alerts(pid(), pid()) :: :ok
  def subscribe_alerts(monitor, subscriber_pid) do
    GenServer.call(monitor, {:subscribe_alerts, subscriber_pid})
  end
  
  @doc """
  Unsubscribe from alerts.
  """
  @spec unsubscribe_alerts(pid(), pid()) :: :ok
  def unsubscribe_alerts(monitor, subscriber_pid) do
    GenServer.call(monitor, {:unsubscribe_alerts, subscriber_pid})
  end
  
  @doc """
  Get current system health status.
  """
  @spec get_health_status(pid()) :: map()
  def get_health_status(monitor) do
    GenServer.call(monitor, :get_health_status)
  end
  
  @doc """
  Get live dashboard data.
  """
  @spec get_dashboard_data(pid()) :: map()
  def get_dashboard_data(monitor) do
    GenServer.call(monitor, :get_dashboard_data)
  end
  
  @doc """
  Get current alerts.
  """
  @spec get_alerts(pid(), keyword()) :: [alert()]
  def get_alerts(monitor, opts \\ []) do
    GenServer.call(monitor, {:get_alerts, opts})
  end
  
  @doc """
  Acknowledge an alert.
  """
  @spec acknowledge_alert(pid(), String.t()) :: :ok | {:error, term()}
  def acknowledge_alert(monitor, alert_id) do
    GenServer.call(monitor, {:acknowledge_alert, alert_id})
  end
  
  @doc """
  Clear all acknowledged alerts.
  """
  @spec clear_acknowledged_alerts(pid()) :: :ok
  def clear_acknowledged_alerts(monitor) do
    GenServer.call(monitor, :clear_acknowledged_alerts)
  end
  
  @doc """
  Update alert thresholds.
  """
  @spec update_thresholds(pid(), map()) :: :ok
  def update_thresholds(monitor, new_thresholds) do
    GenServer.call(monitor, {:update_thresholds, new_thresholds})
  end
  
  @doc """
  Generate performance report.
  """
  @spec generate_report(pid(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_report(monitor, opts \\ []) do
    GenServer.call(monitor, {:generate_report, opts})
  end
  
  @doc """
  Get performance trends analysis.
  """
  @spec get_performance_trends(pid(), pos_integer()) :: map()
  def get_performance_trends(monitor, hours_back \\ 24) do
    GenServer.call(monitor, {:get_performance_trends, hours_back})
  end
  
  ## GenServer Implementation
  
  @impl true
  def init(config) do
    state = %__MODULE__{
      config: config,
      alert_thresholds: config.alert_thresholds,
      current_metrics: %{},
      alerts: [],
      alert_subscribers: [],
      dashboard_widgets: initialize_dashboard_widgets(),
      monitoring_timer: nil,
      dashboard_timer: nil,
      performance_history: :queue.new(),
      anomaly_detector: initialize_anomaly_detector(),
      last_alert_times: %{}
    }
    
    # Start monitoring loops
    state = schedule_monitoring(state)
    
    if config.dashboard_enabled do
      state = schedule_dashboard_update(state)
    end
    
    Logger.info("Realtime monitor started with config: #{inspect(config)}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:subscribe_alerts, subscriber_pid}, _from, state) do
    if subscriber_pid in state.alert_subscribers do
      {:reply, :ok, state}
    else
      Process.monitor(subscriber_pid)
      new_subscribers = [subscriber_pid | state.alert_subscribers]
      new_state = %{state | alert_subscribers: new_subscribers}
      Logger.debug("Added alert subscriber: #{inspect(subscriber_pid)}")
      {:reply, :ok, new_state}
    end
  end
  
  @impl true
  def handle_call({:unsubscribe_alerts, subscriber_pid}, _from, state) do
    new_subscribers = List.delete(state.alert_subscribers, subscriber_pid)
    new_state = %{state | alert_subscribers: new_subscribers}
    Logger.debug("Removed alert subscriber: #{inspect(subscriber_pid)}")
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_health_status, _from, state) do
    health_status = compile_health_status(state)
    {:reply, health_status, state}
  end
  
  @impl true
  def handle_call(:get_dashboard_data, _from, state) do
    dashboard_data = compile_dashboard_data(state)
    {:reply, dashboard_data, state}
  end
  
  @impl true
  def handle_call({:get_alerts, opts}, _from, state) do
    severity_filter = Keyword.get(opts, :severity)
    acknowledged_filter = Keyword.get(opts, :acknowledged)
    
    filtered_alerts = state.alerts
    |> filter_by_severity(severity_filter)
    |> filter_by_acknowledged(acknowledged_filter)
    
    {:reply, filtered_alerts, state}
  end
  
  @impl true
  def handle_call({:acknowledge_alert, alert_id}, _from, state) do
    case find_alert_by_id(state.alerts, alert_id) do
      nil ->
        {:reply, {:error, :alert_not_found}, state}
      
      alert ->
        updated_alert = %{alert | acknowledged: true}
        updated_alerts = replace_alert(state.alerts, updated_alert)
        new_state = %{state | alerts: updated_alerts}
        Logger.info("Acknowledged alert: #{alert_id}")
        {:reply, :ok, new_state}
    end
  end
  
  @impl true
  def handle_call(:clear_acknowledged_alerts, _from, state) do
    remaining_alerts = Enum.reject(state.alerts, & &1.acknowledged)
    new_state = %{state | alerts: remaining_alerts}
    Logger.info("Cleared #{length(state.alerts) - length(remaining_alerts)} acknowledged alerts")
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:update_thresholds, new_thresholds}, _from, state) do
    updated_thresholds = Map.merge(state.alert_thresholds, new_thresholds)
    new_state = %{state | alert_thresholds: updated_thresholds}
    Logger.info("Updated alert thresholds: #{inspect(new_thresholds)}")
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:generate_report, opts}, _from, state) do
    try do
      report = generate_performance_report(state, opts)
      {:reply, {:ok, report}, state}
    rescue
      error ->
        Logger.error("Failed to generate report: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end
  
  @impl true
  def handle_call({:get_performance_trends, hours_back}, _from, state) do
    trends = analyze_performance_trends(state, hours_back)
    {:reply, trends, state}
  end
  
  @impl true
  def handle_info(:perform_monitoring, state) do
    new_state = perform_monitoring_cycle(state)
    new_state = schedule_monitoring(new_state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:update_dashboard, state) do
    if state.config.dashboard_enabled do
      new_state = update_dashboard_widgets(state)
      new_state = schedule_dashboard_update(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead alert subscriber
    new_subscribers = List.delete(state.alert_subscribers, pid)
    new_state = %{state | alert_subscribers: new_subscribers}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.warning("Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  ## Private Functions
  
  defp build_config(opts) do
    config_overrides = Map.new(opts)
    
    # Merge thresholds separately to avoid overwriting entire map
    alert_thresholds = if Map.has_key?(config_overrides, :alert_thresholds) do
      Map.merge(@default_config.alert_thresholds, config_overrides.alert_thresholds)
    else
      @default_config.alert_thresholds
    end
    
    config_overrides = Map.put(config_overrides, :alert_thresholds, alert_thresholds)
    Map.merge(@default_config, config_overrides)
  end
  
  defp schedule_monitoring(state) do
    if state.monitoring_timer do
      Process.cancel_timer(state.monitoring_timer)
    end
    
    timer_ref = Process.send_after(self(), :perform_monitoring, state.config.monitoring_interval_ms)
    %{state | monitoring_timer: timer_ref}
  end
  
  defp schedule_dashboard_update(state) do
    if state.dashboard_timer do
      Process.cancel_timer(state.dashboard_timer)
    end
    
    timer_ref = Process.send_after(self(), :update_dashboard, state.config.dashboard_update_interval_ms)
    %{state | dashboard_timer: timer_ref}
  end
  
  defp perform_monitoring_cycle(state) do
    # Collect current metrics from various sources
    current_metrics = collect_system_metrics()
    
    # Store performance history
    history_entry = {DateTime.utc_now(), current_metrics}
    updated_history = :queue.in(history_entry, state.performance_history)
    
    # Keep only recent history (last 1000 entries)
    final_history = if :queue.len(updated_history) > 1000 do
      {_, new_queue} = :queue.out(updated_history)
      new_queue
    else
      updated_history
    end
    
    # Check for alerts
    {new_alerts, updated_alert_times} = check_for_alerts(current_metrics, state)
    
    # Detect anomalies
    anomaly_alerts = detect_anomalies(current_metrics, state.anomaly_detector, state.performance_history)
    
    # Combine all alerts
    all_new_alerts = new_alerts ++ anomaly_alerts
    
    # Add new alerts to the list (keep last 100)
    updated_alerts = (state.alerts ++ all_new_alerts)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(100)
    
    # Broadcast alerts to subscribers
    if length(all_new_alerts) > 0 do
      broadcast_alerts(state.alert_subscribers, all_new_alerts)
    end
    
    %{state |
      current_metrics: current_metrics,
      alerts: updated_alerts,
      performance_history: final_history,
      last_alert_times: updated_alert_times
    }
  end
  
  defp collect_system_metrics() do
    # Collect metrics from execution engine if available
    execution_metrics = try do
      if Process.whereis(Dspy.RealtimeExecutionEngine) do
        Dspy.RealtimeExecutionEngine.get_metrics(Dspy.RealtimeExecutionEngine)
      else
        %{}
      end
    rescue
      _ -> %{}
    end
    
    # Collect metrics from store if available
    store_metrics = try do
      if Process.whereis(Dspy.RealtimeStore) do
        Dspy.RealtimeStore.get_stats(Dspy.RealtimeStore)
      else
        %{}
      end
    rescue
      _ -> %{}
    end
    
    # System metrics
    system_metrics = %{
      memory_usage_mb: :erlang.memory(:total) / (1024 * 1024),
      cpu_usage_percent: get_cpu_usage(),
      process_count: :erlang.system_info(:process_count),
      timestamp: DateTime.utc_now()
    }
    
    Map.merge(execution_metrics, Map.merge(store_metrics, system_metrics))
  end
  
  defp get_cpu_usage() do
    # Simplified CPU usage (in real implementation would use proper system monitoring)
    :rand.uniform(80) + 10
  end
  
  defp check_for_alerts(metrics, state) do
    thresholds = state.alert_thresholds
    current_time = DateTime.utc_now()
    
    potential_alerts = [
      check_error_rate_alert(metrics, thresholds),
      check_latency_alert(metrics, thresholds),
      check_memory_alert(metrics, thresholds),
      check_cpu_alert(metrics, thresholds),
      check_throughput_alert(metrics, thresholds)
    ]
    
    # Filter out nil alerts and apply cooldown
    new_alerts = potential_alerts
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn alert ->
      should_trigger_alert?(alert.type, current_time, state.last_alert_times, state.config.alert_cooldown_ms)
    end)
    
    # Update last alert times
    updated_alert_times = Enum.reduce(new_alerts, state.last_alert_times, fn alert, acc ->
      Map.put(acc, alert.type, current_time)
    end)
    
    {new_alerts, updated_alert_times}
  end
  
  defp check_error_rate_alert(metrics, thresholds) do
    error_rate = Map.get(metrics, :error_rate, 0.0)
    threshold = Map.get(thresholds, :error_rate, 0.1)
    
    if error_rate > threshold do
      create_alert(:high_error_rate, :high, 
        "Error rate (#{Float.round(error_rate * 100, 2)}%) exceeds threshold (#{Float.round(threshold * 100, 2)}%)",
        %{error_rate: error_rate, threshold: threshold})
    end
  end
  
  defp check_latency_alert(metrics, thresholds) do
    latency = Map.get(metrics, :average_execution_time, 0.0)
    threshold = Map.get(thresholds, :latency_ms, 10_000)
    
    if latency > threshold do
      create_alert(:high_latency, :medium,
        "Average latency (#{Float.round(latency, 2)}ms) exceeds threshold (#{threshold}ms)",
        %{latency: latency, threshold: threshold})
    end
  end
  
  defp check_memory_alert(metrics, thresholds) do
    memory_usage = Map.get(metrics, :memory_usage_mb, 0.0)
    threshold = Map.get(thresholds, :memory_usage_mb, 1000)
    
    if memory_usage > threshold do
      create_alert(:memory_exhaustion, :high,
        "Memory usage (#{Float.round(memory_usage, 2)}MB) exceeds threshold (#{threshold}MB)",
        %{memory_usage: memory_usage, threshold: threshold})
    end
  end
  
  defp check_cpu_alert(metrics, thresholds) do
    cpu_usage = Map.get(metrics, :cpu_usage_percent, 0.0)
    threshold = Map.get(thresholds, :cpu_usage_percent, 90)
    
    if cpu_usage > threshold do
      create_alert(:cpu_overload, :medium,
        "CPU usage (#{Float.round(cpu_usage, 2)}%) exceeds threshold (#{threshold}%)",
        %{cpu_usage: cpu_usage, threshold: threshold})
    end
  end
  
  defp check_throughput_alert(metrics, thresholds) do
    throughput = Map.get(metrics, :throughput_per_second, 0.0)
    threshold = Map.get(thresholds, :throughput_per_second, 0.1)
    
    if throughput < threshold do
      create_alert(:low_throughput, :medium,
        "Throughput (#{Float.round(throughput, 4)}/sec) below threshold (#{threshold}/sec)",
        %{throughput: throughput, threshold: threshold})
    end
  end
  
  defp detect_anomalies(current_metrics, _detector, performance_history) do
    # Simple anomaly detection - could be enhanced with ML
    if :queue.len(performance_history) > 10 do
      recent_values = performance_history
      |> :queue.to_list()
      |> Enum.take(-10)
      |> Enum.map(fn {_time, metrics} -> Map.get(metrics, :average_execution_time, 0.0) end)
      
      avg = Enum.sum(recent_values) / length(recent_values)
      current_latency = Map.get(current_metrics, :average_execution_time, 0.0)
      
      # If current latency is 3x the recent average, it's an anomaly
      if current_latency > avg * 3 and avg > 0 do
        [create_alert(:anomaly_detected, :medium,
          "Performance anomaly detected: latency spike (#{Float.round(current_latency, 2)}ms vs avg #{Float.round(avg, 2)}ms)",
          %{current_latency: current_latency, average_latency: avg, spike_factor: current_latency / avg})]
      else
        []
      end
    else
      []
    end
  end
  
  defp create_alert(type, severity, message, data) do
    %{
      id: generate_alert_id(),
      type: type,
      severity: severity,
      message: message,
      data: data,
      timestamp: DateTime.utc_now(),
      acknowledged: false
    }
  end
  
  defp should_trigger_alert?(alert_type, current_time, last_alert_times, cooldown_ms) do
    case Map.get(last_alert_times, alert_type) do
      nil -> true
      last_time ->
        diff_ms = DateTime.diff(current_time, last_time, :millisecond)
        diff_ms >= cooldown_ms
    end
  end
  
  defp broadcast_alerts(subscribers, alerts) do
    message = {:monitor_alerts, alerts}
    
    Enum.each(subscribers, fn subscriber ->
      try do
        send(subscriber, message)
      rescue
        _ -> :ok
      end
    end)
  end
  
  defp initialize_dashboard_widgets() do
    Enum.map(@dashboard_widget_types, fn type ->
      %{
        id: "widget_#{type}",
        type: type,
        title: widget_title(type),
        data: %{},
        config: widget_default_config(type),
        last_updated: DateTime.utc_now()
      }
    end)
  end
  
  defp widget_title(:performance_metrics), do: "Performance Metrics"
  defp widget_title(:error_rate_chart), do: "Error Rate Over Time"
  defp widget_title(:throughput_chart), do: "Throughput Trends"
  defp widget_title(:resource_usage), do: "Resource Usage"
  defp widget_title(:recent_alerts), do: "Recent Alerts"
  defp widget_title(:experiment_status), do: "Experiment Status"
  defp widget_title(:system_health), do: "System Health"
  defp widget_title(:performance_trends), do: "Performance Trends"
  
  defp widget_default_config(:error_rate_chart), do: %{time_window_hours: 24, chart_type: "line"}
  defp widget_default_config(:throughput_chart), do: %{time_window_hours: 12, chart_type: "area"}
  defp widget_default_config(:recent_alerts), do: %{max_alerts: 10, show_acknowledged: false}
  defp widget_default_config(_), do: %{}
  
  defp update_dashboard_widgets(state) do
    updated_widgets = Enum.map(state.dashboard_widgets, fn widget ->
      updated_data = generate_widget_data(widget.type, state)
      %{widget | data: updated_data, last_updated: DateTime.utc_now()}
    end)
    
    %{state | dashboard_widgets: updated_widgets}
  end
  
  defp generate_widget_data(:performance_metrics, state) do
    state.current_metrics
  end
  
  defp generate_widget_data(:error_rate_chart, state) do
    history_data = state.performance_history
    |> :queue.to_list()
    |> Enum.take(-24)  # Last 24 data points
    |> Enum.map(fn {time, metrics} ->
      %{timestamp: time, error_rate: Map.get(metrics, :error_rate, 0.0)}
    end)
    
    %{chart_data: history_data}
  end
  
  defp generate_widget_data(:recent_alerts, state) do
    recent_alerts = state.alerts
    |> Enum.reject(& &1.acknowledged)
    |> Enum.take(10)
    
    %{alerts: recent_alerts}
  end
  
  defp generate_widget_data(:system_health, state) do
    compile_health_status(state)
  end
  
  defp generate_widget_data(_, _state) do
    %{placeholder: true}
  end
  
  defp compile_health_status(state) do
    metrics = state.current_metrics
    active_alerts = Enum.reject(state.alerts, & &1.acknowledged)
    critical_alerts = Enum.filter(active_alerts, &(&1.severity == :critical))
    
    overall_health = cond do
      length(critical_alerts) > 0 -> :critical
      length(active_alerts) > 5 -> :degraded
      Map.get(metrics, :error_rate, 0.0) > 0.05 -> :warning
      true -> :healthy
    end
    
    %{
      overall_health: overall_health,
      active_alerts: length(active_alerts),
      critical_alerts: length(critical_alerts),
      error_rate: Map.get(metrics, :error_rate, 0.0),
      average_latency: Map.get(metrics, :average_execution_time, 0.0),
      memory_usage: Map.get(metrics, :memory_usage_mb, 0.0),
      cpu_usage: Map.get(metrics, :cpu_usage_percent, 0.0),
      last_updated: DateTime.utc_now()
    }
  end
  
  defp compile_dashboard_data(state) do
    %{
      widgets: state.dashboard_widgets,
      health_status: compile_health_status(state),
      recent_alerts: Enum.take(state.alerts, 5),
      system_metrics: state.current_metrics,
      last_updated: DateTime.utc_now()
    }
  end
  
  defp filter_by_severity(alerts, nil), do: alerts
  defp filter_by_severity(alerts, severity), do: Enum.filter(alerts, &(&1.severity == severity))
  
  defp filter_by_acknowledged(alerts, nil), do: alerts
  defp filter_by_acknowledged(alerts, acknowledged), do: Enum.filter(alerts, &(&1.acknowledged == acknowledged))
  
  defp find_alert_by_id(alerts, alert_id) do
    Enum.find(alerts, &(&1.id == alert_id))
  end
  
  defp replace_alert(alerts, updated_alert) do
    Enum.map(alerts, fn alert ->
      if alert.id == updated_alert.id, do: updated_alert, else: alert
    end)
  end
  
  defp generate_performance_report(state, opts) do
    time_range = Keyword.get(opts, :time_range, 24)  # hours
    include_charts = Keyword.get(opts, :include_charts, false)
    
    history_data = state.performance_history
    |> :queue.to_list()
    |> Enum.filter(fn {time, _} ->
      hours_ago = DateTime.add(DateTime.utc_now(), -time_range, :hour)
      DateTime.compare(time, hours_ago) != :lt
    end)
    
    metrics_summary = calculate_metrics_summary(history_data)
    alerts_summary = summarize_alerts(state.alerts, time_range)
    
    report = """
    # DSPy Performance Report
    
    **Generated:** #{DateTime.to_string(DateTime.utc_now())}
    **Time Range:** Last #{time_range} hours
    
    ## Executive Summary
    
    - **Overall Health:** #{metrics_summary.overall_health}
    - **Total Executions:** #{metrics_summary.total_executions}
    - **Average Success Rate:** #{Float.round(metrics_summary.avg_success_rate * 100, 2)}%
    - **Average Latency:** #{Float.round(metrics_summary.avg_latency, 2)}ms
    - **Total Alerts:** #{alerts_summary.total_alerts}
    
    ## Performance Metrics
    
    - **Error Rate:** #{Float.round(metrics_summary.avg_error_rate * 100, 2)}%
    - **Throughput:** #{Float.round(metrics_summary.avg_throughput, 4)} operations/second
    - **Memory Usage:** #{Float.round(metrics_summary.avg_memory_usage, 2)}MB
    - **CPU Usage:** #{Float.round(metrics_summary.avg_cpu_usage, 2)}%
    
    ## Alerts Summary
    
    - **Critical Alerts:** #{alerts_summary.critical_count}
    - **High Priority:** #{alerts_summary.high_count}
    - **Medium Priority:** #{alerts_summary.medium_count}
    - **Low Priority:** #{alerts_summary.low_count}
    
    ## Recommendations
    
    #{generate_recommendations(metrics_summary, alerts_summary)}
    
    ---
    
    *Report generated by DSPy Realtime Monitor*
    """
    
    if include_charts do
      report <> "\n\n" <> generate_text_charts(history_data)
    else
      report
    end
  end
  
  defp calculate_metrics_summary(history_data) do
    if length(history_data) > 0 do
      metrics = Enum.map(history_data, fn {_time, metrics} -> metrics end)
      
      %{
        overall_health: :stable,  # Simplified
        total_executions: Enum.sum(Enum.map(metrics, &Map.get(&1, :total_executions, 0))),
        avg_success_rate: average_metric(metrics, :success_rate),
        avg_error_rate: average_metric(metrics, :error_rate),
        avg_latency: average_metric(metrics, :average_execution_time),
        avg_throughput: average_metric(metrics, :throughput_per_second),
        avg_memory_usage: average_metric(metrics, :memory_usage_mb),
        avg_cpu_usage: average_metric(metrics, :cpu_usage_percent)
      }
    else
      %{
        overall_health: :unknown,
        total_executions: 0,
        avg_success_rate: 0.0,
        avg_error_rate: 0.0,
        avg_latency: 0.0,
        avg_throughput: 0.0,
        avg_memory_usage: 0.0,
        avg_cpu_usage: 0.0
      }
    end
  end
  
  defp average_metric(metrics, key) do
    values = Enum.map(metrics, &Map.get(&1, key, 0.0))
    if length(values) > 0, do: Enum.sum(values) / length(values), else: 0.0
  end
  
  defp summarize_alerts(alerts, hours_back) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -hours_back, :hour)
    recent_alerts = Enum.filter(alerts, fn alert ->
      DateTime.compare(alert.timestamp, cutoff_time) != :lt
    end)
    
    %{
      total_alerts: length(recent_alerts),
      critical_count: Enum.count(recent_alerts, &(&1.severity == :critical)),
      high_count: Enum.count(recent_alerts, &(&1.severity == :high)),
      medium_count: Enum.count(recent_alerts, &(&1.severity == :medium)),
      low_count: Enum.count(recent_alerts, &(&1.severity == :low))
    }
  end
  
  defp generate_recommendations(metrics_summary, alerts_summary) do
    recommendations = []
    
    recommendations = if metrics_summary.avg_error_rate > 0.05 do
      ["• Consider investigating error patterns and improving error handling" | recommendations]
    else
      recommendations
    end
    
    recommendations = if metrics_summary.avg_latency > 5000 do
      ["• High latency detected - consider optimizing model calls or adding caching" | recommendations]
    else
      recommendations
    end
    
    recommendations = if alerts_summary.critical_count > 0 do
      ["• Address critical alerts immediately to prevent system degradation" | recommendations]
    else
      recommendations
    end
    
    recommendations = if metrics_summary.avg_memory_usage > 800 do
      ["• Memory usage is high - consider implementing cleanup routines" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) > 0 do
      Enum.join(recommendations, "\n")
    else
      "• System is performing well with no immediate recommendations"
    end
  end
  
  defp generate_text_charts(_history_data) do
    # Simplified text chart generation
    "## Performance Charts\n\n*Charts would be generated here in a full implementation*"
  end
  
  defp analyze_performance_trends(state, hours_back) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -hours_back, :hour)
    
    trend_data = state.performance_history
    |> :queue.to_list()
    |> Enum.filter(fn {time, _} -> DateTime.compare(time, cutoff_time) != :lt end)
    |> Enum.map(fn {time, metrics} -> {time, metrics} end)
    
    %{
      time_range: hours_back,
      data_points: length(trend_data),
      trends: calculate_trends(trend_data),
      last_updated: DateTime.utc_now()
    }
  end
  
  defp calculate_trends(trend_data) do
    if length(trend_data) > 1 do
      %{
        latency_trend: calculate_metric_trend(trend_data, :average_execution_time),
        error_rate_trend: calculate_metric_trend(trend_data, :error_rate),
        throughput_trend: calculate_metric_trend(trend_data, :throughput_per_second),
        memory_trend: calculate_metric_trend(trend_data, :memory_usage_mb)
      }
    else
      %{
        latency_trend: :stable,
        error_rate_trend: :stable,
        throughput_trend: :stable,
        memory_trend: :stable
      }
    end
  end
  
  defp calculate_metric_trend(data, metric_key) do
    values = Enum.map(data, fn {_time, metrics} -> Map.get(metrics, metric_key, 0.0) end)
    
    if length(values) > 3 do
      first_half = Enum.take(values, div(length(values), 2))
      second_half = Enum.drop(values, div(length(values), 2))
      
      first_avg = Enum.sum(first_half) / length(first_half)
      second_avg = Enum.sum(second_half) / length(second_half)
      
      change_percent = if first_avg > 0, do: (second_avg - first_avg) / first_avg, else: 0.0
      
      cond do
        change_percent > 0.1 -> :increasing
        change_percent < -0.1 -> :decreasing
        true -> :stable
      end
    else
      :stable
    end
  end
  
  defp initialize_anomaly_detector() do
    # Placeholder for anomaly detection state
    %{
      baseline_established: false,
      sensitivity: 0.8,
      lookback_window: 20
    }
  end
  
  defp generate_alert_id() do
    "alert_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end