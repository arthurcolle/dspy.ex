#!/usr/bin/env elixir

# Enhanced Realtime DSPy Showcase
# Demonstrates truly realtime, ongoing examples with live monitoring

Mix.install([
  {:dspy, path: "."},
  {:jason, "~> 1.4"}
])

defmodule RealtimeShowcase do
  @moduledoc """
  Comprehensive showcase of DSPy's realtime capabilities.
  
  This example demonstrates:
  - Continuous realtime execution with the realtime flag
  - Live data store with ongoing updates
  - Real-time monitoring and alerting
  - Performance tracking and optimization
  - Live dashboard data
  
  Run with: elixir examples/realtime_showcase.exs --realtime
  """
  
  require Logger
  
  alias Dspy.{
    RealtimeExecutionEngine,
    RealtimeStore,
    RealtimeMonitor,
    Example,
    Settings
  }
  
  def main(args \\ []) do
    # Check for realtime flag
    realtime_enabled = "--realtime" in args or "-r" in args
    
    IO.puts("""
    🚀 DSPy Realtime Showcase
    ========================
    
    Realtime Mode: #{if realtime_enabled, do: "✅ ENABLED", else: "❌ Disabled"}
    
    This showcase demonstrates DSPy's advanced realtime capabilities:
    
    #{if realtime_enabled do
      """
      🔄 Continuous execution every 5 seconds
      📊 Live metrics and performance tracking  
      🚨 Real-time alerting and monitoring
      💾 Persistent data store with live updates
      📈 Performance trend analysis
      🎯 Adaptive execution optimization
      """
    else
      """
      📚 Single execution demonstration
      📊 Basic metrics collection
      💾 Data store demonstration
      
      Add --realtime flag for continuous execution!
      """
    end}
    """)
    
    # Configure DSPy
    configure_dspy()
    
    # Create examples for demonstration
    examples = create_demo_examples()
    
    # Start the realtime systems
    {:ok, store} = start_realtime_store()
    {:ok, monitor} = start_realtime_monitor()
    {:ok, engine} = start_execution_engine(examples, realtime_enabled)
    
    if realtime_enabled do
      run_realtime_showcase(engine, store, monitor)
    else
      run_single_showcase(engine, store, monitor, examples)
    end
  end
  
  defp configure_dspy() do
    # Configure with GPT-4.1 for optimal performance
    Dspy.configure(
      lm: %Dspy.LM.OpenAI{
        model: "gpt-4.1",
        max_tokens: 2048,
        temperature: 0.1
      },
      max_tokens: 2048,
      temperature: 0.1,
      cache: true
    )
    
    IO.puts("✅ DSPy configured with GPT-4.1")
  end
  
  defp create_demo_examples() do
    [
      Dspy.example(%{
        id: "reasoning_1",
        question: "What are the implications of quantum computing for cryptography?",
        context: "security analysis",
        difficulty: "advanced"
      }),
      
      Dspy.example(%{
        id: "reasoning_2", 
        question: "How do neural networks learn complex patterns?",
        context: "machine learning",
        difficulty: "intermediate"
      }),
      
      Dspy.example(%{
        id: "reasoning_3",
        question: "What causes climate change and what are potential solutions?",
        context: "environmental science",
        difficulty: "intermediate"
      }),
      
      Dspy.example(%{
        id: "math_1",
        question: "Solve: If f(x) = x² + 3x - 2, find the derivative and critical points",
        context: "calculus",
        difficulty: "intermediate"
      }),
      
      Dspy.example(%{
        id: "creative_1",
        question: "Write a short story about a time traveler who can only go backwards",
        context: "creative writing",
        difficulty: "open-ended"
      })
    ]
  end
  
  defp start_realtime_store() do
    IO.puts("🏪 Starting realtime store...")
    
    RealtimeStore.start_link(
      persistence: true,
      retention_days: 30,
      realtime_updates: true,
      max_memory_mb: 200,
      aggregation_interval_ms: 30_000
    )
  end
  
  defp start_realtime_monitor() do
    IO.puts("📊 Starting realtime monitor...")
    
    RealtimeMonitor.start_link(
      alert_thresholds: %{
        error_rate: 0.2,
        latency_ms: 8_000,
        memory_usage_mb: 300,
        cpu_usage_percent: 85
      },
      dashboard_enabled: true,
      auto_reporting: false,
      monitoring_interval_ms: 5_000,
      alert_cooldown_ms: 120_000  # 2 minutes
    )
  end
  
  defp start_execution_engine(examples, realtime_enabled) do
    IO.puts("🚀 Starting execution engine...")
    
    RealtimeExecutionEngine.start_link(
      examples: examples,
      realtime: realtime_enabled,
      interval_ms: 5_000,  # Execute every 5 seconds
      stream_results: true,
      max_concurrent: 2,
      auto_scaling: true,
      performance_threshold: 0.7
    )
  end
  
  defp run_realtime_showcase(engine, store, monitor) do
    IO.puts("""
    
    🔄 REALTIME MODE ACTIVE
    ======================
    
    Starting continuous execution and monitoring...
    
    Commands:
    - 's' + Enter: Show current status
    - 'm' + Enter: Show metrics  
    - 'a' + Enter: Show alerts
    - 'd' + Enter: Show dashboard data
    - 'r' + Enter: Generate report
    - 'p' + Enter: Pause/Resume execution
    - 'q' + Enter: Quit
    
    """)
    
    # Subscribe to live updates
    RealtimeExecutionEngine.subscribe_to_results(engine, self())
    RealtimeMonitor.subscribe_alerts(monitor, self())
    RealtimeStore.subscribe(store, :results, self())
    
    # Start realtime execution
    :ok = RealtimeExecutionEngine.start_realtime(engine)
    
    # Start interactive loop
    realtime_interaction_loop(engine, store, monitor)
  end
  
  defp run_single_showcase(engine, store, monitor, examples) do
    IO.puts("""
    
    📚 SINGLE EXECUTION MODE
    =======================
    
    Running one execution cycle...
    
    """)
    
    # Execute examples once
    case RealtimeExecutionEngine.execute(engine, examples) do
      {:ok, results} ->
        IO.puts("✅ Execution completed successfully!")
        IO.puts("📊 Results: #{length(results)} predictions generated")
        
        # Store results
        Enum.each(results, fn result ->
          RealtimeStore.store_result(store, result.example_id, result)
        end)
        
        # Show metrics
        show_metrics(engine, store, monitor)
        
        # Generate sample dashboard data
        show_dashboard_data(monitor)
        
      {:error, reason} ->
        IO.puts("❌ Execution failed: #{inspect(reason)}")
    end
  end
  
  defp realtime_interaction_loop(engine, store, monitor) do
    receive do
      {:realtime_results, results, timestamp} ->
        IO.puts("📈 [#{format_time(timestamp)}] New results: #{length(results)} predictions")
        
        # Store results in realtime store
        Enum.each(results, fn result ->
          RealtimeStore.store_result(store, result.example_id, result)
        end)
        
        realtime_interaction_loop(engine, store, monitor)
        
      {:monitor_alerts, alerts} ->
        IO.puts("🚨 [#{format_time(DateTime.utc_now())}] New alerts: #{length(alerts)}")
        Enum.each(alerts, fn alert ->
          severity_emoji = case alert.severity do
            :critical -> "💥"
            :high -> "🔴"
            :medium -> "🟡" 
            :low -> "🔵"
          end
          IO.puts("   #{severity_emoji} #{alert.message}")
        end)
        
        realtime_interaction_loop(engine, store, monitor)
        
      {:store_update, type, action, entry} ->
        IO.puts("💾 [#{format_time(entry.timestamp)}] Store update: #{action} #{type}")
        realtime_interaction_loop(engine, store, monitor)
        
    after
      100 ->
        # Check for user input
        case check_input() do
          "s" -> 
            show_status(engine, store, monitor)
            realtime_interaction_loop(engine, store, monitor)
            
          "m" ->
            show_metrics(engine, store, monitor)
            realtime_interaction_loop(engine, store, monitor)
            
          "a" ->
            show_alerts(monitor)
            realtime_interaction_loop(engine, store, monitor)
            
          "d" ->
            show_dashboard_data(monitor)
            realtime_interaction_loop(engine, store, monitor)
            
          "r" ->
            generate_report(monitor)
            realtime_interaction_loop(engine, store, monitor)
            
          "p" ->
            toggle_execution(engine)
            realtime_interaction_loop(engine, store, monitor)
            
          "q" ->
            IO.puts("\n👋 Stopping realtime showcase...")
            RealtimeExecutionEngine.stop_realtime(engine)
            :ok
            
          nil ->
            realtime_interaction_loop(engine, store, monitor)
            
          input ->
            IO.puts("❓ Unknown command: #{input}")
            realtime_interaction_loop(engine, store, monitor)
        end
    end
  end
  
  defp check_input() do
    case IO.getn("", 1) do
      :eof -> nil
      "\n" -> nil
      char -> 
        # Read rest of line
        IO.read(:line)
        char
    end
  end
  
  defp show_status(engine, store, monitor) do
    engine_status = RealtimeExecutionEngine.get_status(engine)
    store_stats = RealtimeStore.get_stats(store)
    health_status = RealtimeMonitor.get_health_status(monitor)
    
    IO.puts("""
    
    📊 SYSTEM STATUS
    ===============
    
    🚀 Execution Engine:
       Status: #{engine_status.status}
       Cycle: #{engine_status.current_cycle}
       Subscribers: #{engine_status.subscriber_count}
       Errors: #{engine_status.error_count}
       Last Run: #{format_time(engine_status.last_execution)}
       Next Run: #{format_time(engine_status.next_execution)}
    
    💾 Data Store:
       Total Entries: #{store_stats.total_entries}
       Memory Usage: #{Float.round(store_stats.total_memory_mb, 2)}MB
       Results: #{Map.get(store_stats.tables, :results, %{}) |> Map.get(:entries, 0)}
       Metrics: #{Map.get(store_stats.tables, :metrics, %{}) |> Map.get(:entries, 0)}
    
    🏥 System Health:
       Overall: #{health_status.overall_health}
       Active Alerts: #{health_status.active_alerts}
       Error Rate: #{Float.round(health_status.error_rate * 100, 2)}%
       Avg Latency: #{Float.round(health_status.average_latency, 2)}ms
       Memory: #{Float.round(health_status.memory_usage, 2)}MB
       CPU: #{Float.round(health_status.cpu_usage, 2)}%
    
    """)
  end
  
  defp show_metrics(engine, store, monitor) do
    engine_metrics = RealtimeExecutionEngine.get_metrics(engine)
    trends = RealtimeMonitor.get_performance_trends(monitor, 1)  # Last hour
    
    IO.puts("""
    
    📈 PERFORMANCE METRICS
    =====================
    
    🎯 Execution Metrics:
       Total Executions: #{Map.get(engine_metrics, :total_executions, 0)}
       Total Examples: #{Map.get(engine_metrics, :total_examples, 0)}
       Success Rate: #{Float.round(Map.get(engine_metrics, :success_rate, 0.0) * 100, 2)}%
       Error Rate: #{Float.round(Map.get(engine_metrics, :error_rate, 0.0) * 100, 2)}%
       Avg Latency: #{Float.round(Map.get(engine_metrics, :average_execution_time, 0.0), 2)}ms
       Throughput: #{Float.round(Map.get(engine_metrics, :throughput_per_second, 0.0), 4)}/sec
    
    📊 Performance Trends (Last Hour):
       Data Points: #{trends.data_points}
       Latency Trend: #{trends.trends.latency_trend}
       Error Rate Trend: #{trends.trends.error_rate_trend}
       Throughput Trend: #{trends.trends.throughput_trend}
       Memory Trend: #{trends.trends.memory_trend}
    
    """)
  end
  
  defp show_alerts(monitor) do
    active_alerts = RealtimeMonitor.get_alerts(monitor, acknowledged: false)
    all_alerts = RealtimeMonitor.get_alerts(monitor)
    
    IO.puts("""
    
    🚨 ALERTS DASHBOARD
    ==================
    
    Active Alerts: #{length(active_alerts)}
    Total Alerts: #{length(all_alerts)}
    
    """)
    
    if length(active_alerts) > 0 do
      IO.puts("🔴 ACTIVE ALERTS:")
      Enum.each(active_alerts, fn alert ->
        severity_color = case alert.severity do
          :critical -> "💥 CRITICAL"
          :high -> "🔴 HIGH"
          :medium -> "🟡 MEDIUM"
          :low -> "🔵 LOW"
        end
        
        IO.puts("   [#{format_time(alert.timestamp)}] #{severity_color}")
        IO.puts("   #{alert.message}")
        IO.puts("   Type: #{alert.type} | ID: #{alert.id}")
        IO.puts("")
      end)
    else
      IO.puts("✅ No active alerts - system running smoothly!")
    end
  end
  
  defp show_dashboard_data(monitor) do
    dashboard_data = RealtimeMonitor.get_dashboard_data(monitor)
    
    IO.puts("""
    
    📺 LIVE DASHBOARD
    ================
    
    🏥 Health Status: #{dashboard_data.health_status.overall_health}
    📊 Active Widgets: #{length(dashboard_data.widgets)}
    🚨 Recent Alerts: #{length(dashboard_data.recent_alerts)}
    
    💻 Current Metrics:
       Memory: #{Float.round(Map.get(dashboard_data.system_metrics, :memory_usage_mb, 0.0), 2)}MB
       CPU: #{Float.round(Map.get(dashboard_data.system_metrics, :cpu_usage_percent, 0.0), 2)}%
       Processes: #{Map.get(dashboard_data.system_metrics, :process_count, 0)}
    
    📈 Widget Status:
    """)
    
    Enum.each(dashboard_data.widgets, fn widget ->
      IO.puts("   • #{widget.title} (#{widget.type}) - Updated: #{format_time(widget.last_updated)}")
    end)
    
    IO.puts("")
  end
  
  defp generate_report(monitor) do
    IO.puts("📝 Generating performance report...")
    
    case RealtimeMonitor.generate_report(monitor, time_range: 1, include_charts: false) do
      {:ok, report} ->
        IO.puts("""
        
        📋 PERFORMANCE REPORT
        ====================
        
        #{report}
        
        """)
        
      {:error, reason} ->
        IO.puts("❌ Failed to generate report: #{inspect(reason)}")
    end
  end
  
  defp toggle_execution(engine) do
    status = RealtimeExecutionEngine.get_status(engine)
    
    case status.status do
      :running ->
        RealtimeExecutionEngine.pause_realtime(engine)
        IO.puts("⏸️  Execution paused")
        
      :paused ->
        RealtimeExecutionEngine.resume_realtime(engine)
        IO.puts("▶️  Execution resumed")
        
      _ ->
        IO.puts("❓ Cannot toggle execution in current state: #{status.status}")
    end
  end
  
  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 8)  # HH:MM:SS
  end
end

# Run the showcase
System.argv() |> RealtimeShowcase.main()