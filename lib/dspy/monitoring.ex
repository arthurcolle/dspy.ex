defmodule Dspy.Monitoring do
  @moduledoc """
  Comprehensive monitoring and observability system for task execution
  with metrics collection, distributed tracing, alerting, and real-time dashboards.
  """

  defmodule MetricsCollector do
    @moduledoc """
    Collects and aggregates performance metrics for tasks and system components.
    """

    use GenServer

    defstruct [
      :name,
      :metrics_store,
      :aggregation_rules,
      :collection_interval,
      :retention_policy,
      :export_targets,
      :active_counters,
      :histograms,
      :gauges,
      :timers
    ]

    @type metric_type :: :counter | :gauge | :histogram | :timer | :meter
    @type metric_value :: number() | {number(), map()}
    @type time_series :: [{DateTime.t(), metric_value()}]

    def start_link(opts \\ []) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def record_metric(collector \\ __MODULE__, metric_name, value, tags \\ %{}) do
      GenServer.cast(collector, {:record_metric, metric_name, value, tags, DateTime.utc_now()})
    end

    def increment_counter(collector \\ __MODULE__, counter_name, amount \\ 1, tags \\ %{}) do
      GenServer.cast(collector, {:increment_counter, counter_name, amount, tags})
    end

    def set_gauge(collector \\ __MODULE__, gauge_name, value, tags \\ %{}) do
      GenServer.cast(collector, {:set_gauge, gauge_name, value, tags})
    end

    def record_histogram(collector \\ __MODULE__, histogram_name, value, tags \\ %{}) do
      GenServer.cast(collector, {:record_histogram, histogram_name, value, tags})
    end

    def start_timer(collector \\ __MODULE__, timer_name, tags \\ %{}) do
      GenServer.call(collector, {:start_timer, timer_name, tags})
    end

    def stop_timer(collector \\ __MODULE__, timer_id) do
      GenServer.cast(collector, {:stop_timer, timer_id})
    end

    def get_metrics(collector \\ __MODULE__, filter \\ %{}) do
      GenServer.call(collector, {:get_metrics, filter})
    end

    def get_metric_summary(collector \\ __MODULE__) do
      GenServer.call(collector, :get_metric_summary)
    end

    @impl true
    def init(opts) do
      state = %__MODULE__{
        name: Keyword.get(opts, :name, __MODULE__),
        metrics_store: %{},
        aggregation_rules: initialize_aggregation_rules(opts),
        collection_interval: Keyword.get(opts, :collection_interval, 10_000),
        retention_policy: Keyword.get(opts, :retention_policy, %{default: 86_400_000}),
        export_targets: Keyword.get(opts, :export_targets, []),
        active_counters: %{},
        histograms: %{},
        gauges: %{},
        timers: %{}
      }

      # Schedule periodic collection
      schedule_collection()

      {:ok, state}
    end

    @impl true
    def handle_cast({:record_metric, metric_name, value, tags, timestamp}, state) do
      updated_store =
        record_metric_internal(state.metrics_store, metric_name, value, tags, timestamp)

      {:noreply, %{state | metrics_store: updated_store}}
    end

    @impl true
    def handle_cast({:increment_counter, counter_name, amount, tags}, state) do
      metric_key = {counter_name, tags}
      current_value = Map.get(state.active_counters, metric_key, 0)
      updated_counters = Map.put(state.active_counters, metric_key, current_value + amount)

      {:noreply, %{state | active_counters: updated_counters}}
    end

    @impl true
    def handle_cast({:set_gauge, gauge_name, value, tags}, state) do
      metric_key = {gauge_name, tags}
      updated_gauges = Map.put(state.gauges, metric_key, {value, DateTime.utc_now()})

      {:noreply, %{state | gauges: updated_gauges}}
    end

    @impl true
    def handle_cast({:record_histogram, histogram_name, value, tags}, state) do
      metric_key = {histogram_name, tags}
      current_values = Map.get(state.histograms, metric_key, [])
      # Keep last 1000 values
      updated_values = [value | Enum.take(current_values, 999)]
      updated_histograms = Map.put(state.histograms, metric_key, updated_values)

      {:noreply, %{state | histograms: updated_histograms}}
    end

    @impl true
    def handle_cast({:stop_timer, timer_id}, state) do
      case Map.get(state.timers, timer_id) do
        nil ->
          {:noreply, state}

        {timer_name, tags, start_time} ->
          duration = DateTime.diff(DateTime.utc_now(), start_time, :microsecond)
          updated_timers = Map.delete(state.timers, timer_id)

          # Record the timing as a histogram
          updated_state = record_histogram_internal(state, timer_name, duration, tags)
          {:noreply, %{updated_state | timers: updated_timers}}
      end
    end

    @impl true
    def handle_call({:start_timer, timer_name, tags}, _from, state) do
      timer_id = generate_timer_id()
      timer_entry = {timer_name, tags, DateTime.utc_now()}
      updated_timers = Map.put(state.timers, timer_id, timer_entry)

      {:reply, timer_id, %{state | timers: updated_timers}}
    end

    @impl true
    def handle_call({:get_metrics, filter}, _from, state) do
      filtered_metrics = filter_metrics(state.metrics_store, filter)
      {:reply, filtered_metrics, state}
    end

    @impl true
    def handle_call(:get_metric_summary, _from, state) do
      summary = generate_metric_summary(state)
      {:reply, summary, state}
    end

    @impl true
    def handle_info(:collect_metrics, state) do
      # Aggregate current metrics into time series
      updated_state = aggregate_current_metrics(state)

      # Export metrics if configured
      export_metrics(updated_state)

      # Schedule next collection
      schedule_collection()

      # Clean up old metrics based on retention policy
      final_state = apply_retention_policy(updated_state)

      {:noreply, final_state}
    end

    # Private implementation

    defp initialize_aggregation_rules(opts) do
      default_rules = %{
        counters: :sum,
        gauges: :last,
        histograms: :percentiles,
        timers: :percentiles
      }

      Keyword.get(opts, :aggregation_rules, default_rules)
    end

    defp record_metric_internal(store, metric_name, value, tags, timestamp) do
      metric_key = {metric_name, tags}
      current_series = Map.get(store, metric_key, [])
      updated_series = [{timestamp, value} | current_series]

      Map.put(store, metric_key, updated_series)
    end

    defp record_histogram_internal(state, histogram_name, value, tags) do
      metric_key = {histogram_name, tags}
      current_values = Map.get(state.histograms, metric_key, [])
      updated_values = [value | Enum.take(current_values, 999)]

      %{state | histograms: Map.put(state.histograms, metric_key, updated_values)}
    end

    defp generate_timer_id do
      "timer_#{System.unique_integer([:positive])}_#{System.monotonic_time()}"
    end

    defp filter_metrics(metrics_store, filter) do
      case filter do
        %{} when map_size(filter) == 0 ->
          metrics_store

        %{metric_name: name} ->
          Enum.filter(metrics_store, fn {{metric_name, _tags}, _series} ->
            metric_name == name
          end)
          |> Map.new()

        %{tags: filter_tags} ->
          Enum.filter(metrics_store, fn {{_metric_name, tags}, _series} ->
            tags_match?(tags, filter_tags)
          end)
          |> Map.new()

        _ ->
          metrics_store
      end
    end

    defp tags_match?(tags, filter_tags) do
      Enum.all?(filter_tags, fn {key, value} ->
        Map.get(tags, key) == value
      end)
    end

    defp generate_metric_summary(state) do
      %{
        total_metrics: map_size(state.metrics_store),
        active_counters: map_size(state.active_counters),
        active_gauges: map_size(state.gauges),
        active_histograms: map_size(state.histograms),
        active_timers: map_size(state.timers),
        collection_interval: state.collection_interval,
        retention_policies: map_size(state.retention_policy)
      }
    end

    defp aggregate_current_metrics(state) do
      timestamp = DateTime.utc_now()

      # Aggregate counters
      counter_metrics =
        Enum.map(state.active_counters, fn {{name, tags}, value} ->
          {{name, tags}, [{timestamp, value}]}
        end)
        |> Map.new()

      # Aggregate gauges
      gauge_metrics =
        Enum.map(state.gauges, fn {{name, tags}, {value, _ts}} ->
          {{name, tags}, [{timestamp, value}]}
        end)
        |> Map.new()

      # Aggregate histograms
      histogram_metrics =
        Enum.map(state.histograms, fn {{name, tags}, values} ->
          aggregated_value = calculate_histogram_percentiles(values)
          {{name, tags}, [{timestamp, aggregated_value}]}
        end)
        |> Map.new()

      # Merge all aggregated metrics into the store
      updated_store =
        state.metrics_store
        |> Map.merge(counter_metrics, fn _k, existing, new -> existing ++ new end)
        |> Map.merge(gauge_metrics, fn _k, existing, new -> existing ++ new end)
        |> Map.merge(histogram_metrics, fn _k, existing, new -> existing ++ new end)

      %{state | metrics_store: updated_store}
    end

    defp calculate_histogram_percentiles(values) when length(values) == 0, do: %{}

    defp calculate_histogram_percentiles(values) do
      sorted_values = Enum.sort(values)
      count = length(sorted_values)

      %{
        count: count,
        min: List.first(sorted_values),
        max: List.last(sorted_values),
        mean: Enum.sum(sorted_values) / count,
        p50: percentile(sorted_values, 0.5),
        p95: percentile(sorted_values, 0.95),
        p99: percentile(sorted_values, 0.99)
      }
    end

    defp percentile(sorted_values, p) do
      index = (length(sorted_values) - 1) * p
      lower_index = floor(index)
      upper_index = ceil(index)

      if lower_index == upper_index do
        Enum.at(sorted_values, round(lower_index))
      else
        lower_value = Enum.at(sorted_values, lower_index)
        upper_value = Enum.at(sorted_values, upper_index)
        weight = index - lower_index
        lower_value + weight * (upper_value - lower_value)
      end
    end

    defp export_metrics(state) do
      # Export metrics to configured targets
      Enum.each(state.export_targets, fn target ->
        case target do
          {:prometheus, config} -> export_to_prometheus(state.metrics_store, config)
          {:statsd, config} -> export_to_statsd(state.metrics_store, config)
          {:cloudwatch, config} -> export_to_cloudwatch(state.metrics_store, config)
          {:custom, export_fn} -> export_fn.(state.metrics_store)
          _ -> :ok
        end
      end)
    end

    defp export_to_prometheus(_metrics, _config) do
      # Implementation for Prometheus export
      :ok
    end

    defp export_to_statsd(_metrics, _config) do
      # Implementation for StatsD export
      :ok
    end

    defp export_to_cloudwatch(_metrics, _config) do
      # Implementation for CloudWatch export
      :ok
    end

    defp apply_retention_policy(state) do
      current_time = DateTime.utc_now()

      updated_store =
        Enum.reduce(state.metrics_store, %{}, fn {metric_key, series}, acc ->
          {metric_name, tags} = metric_key
          retention_ms = get_retention_for_metric(state.retention_policy, metric_name, tags)

          filtered_series =
            Enum.filter(series, fn {timestamp, _value} ->
              age_ms = DateTime.diff(current_time, timestamp, :millisecond)
              age_ms <= retention_ms
            end)

          if length(filtered_series) > 0 do
            Map.put(acc, metric_key, filtered_series)
          else
            acc
          end
        end)

      %{state | metrics_store: updated_store}
    end

    defp get_retention_for_metric(retention_policy, metric_name, _tags) do
      Map.get(retention_policy, metric_name, Map.get(retention_policy, :default, 86_400_000))
    end

    defp schedule_collection do
      Process.send_after(self(), :collect_metrics, 10_000)
    end
  end

  defmodule DistributedTracer do
    @moduledoc """
    Distributed tracing system for tracking task execution across components.
    """

    use GenServer

    defstruct [
      :name,
      :active_traces,
      :completed_traces,
      :trace_config,
      :sampling_rate,
      :max_trace_duration,
      :export_config
    ]

    @type trace_id :: String.t()
    @type span_id :: String.t()
    @type trace_context :: %{trace_id: trace_id(), parent_span_id: span_id() | nil}

    def start_link(opts \\ []) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def start_trace(tracer \\ __MODULE__, operation_name, metadata \\ %{}) do
      GenServer.call(tracer, {:start_trace, operation_name, metadata})
    end

    def start_span(tracer \\ __MODULE__, trace_context, operation_name, metadata \\ %{}) do
      GenServer.call(tracer, {:start_span, trace_context, operation_name, metadata})
    end

    def finish_span(tracer \\ __MODULE__, span_id, result \\ :ok, metadata \\ %{}) do
      GenServer.cast(tracer, {:finish_span, span_id, result, metadata})
    end

    def add_span_tag(tracer \\ __MODULE__, span_id, key, value) do
      GenServer.cast(tracer, {:add_span_tag, span_id, key, value})
    end

    def add_span_log(tracer \\ __MODULE__, span_id, message, metadata \\ %{}) do
      GenServer.cast(tracer, {:add_span_log, span_id, message, metadata})
    end

    def get_trace(tracer \\ __MODULE__, trace_id) do
      GenServer.call(tracer, {:get_trace, trace_id})
    end

    @impl true
    def init(opts) do
      state = %__MODULE__{
        name: Keyword.get(opts, :name, __MODULE__),
        active_traces: %{},
        completed_traces: %{},
        trace_config: initialize_trace_config(opts),
        sampling_rate: Keyword.get(opts, :sampling_rate, 1.0),
        max_trace_duration: Keyword.get(opts, :max_trace_duration, 300_000),
        export_config: Keyword.get(opts, :export_config, [])
      }

      # Schedule periodic cleanup
      schedule_cleanup()

      {:ok, state}
    end

    @impl true
    def handle_call({:start_trace, operation_name, metadata}, _from, state) do
      if should_sample_trace?(state.sampling_rate) do
        trace_id = generate_trace_id()
        span_id = generate_span_id()

        trace = create_new_trace(trace_id, span_id, operation_name, metadata)
        updated_traces = Map.put(state.active_traces, trace_id, trace)

        trace_context = %{trace_id: trace_id, parent_span_id: span_id}
        {:reply, {:ok, trace_context}, %{state | active_traces: updated_traces}}
      else
        {:reply, {:ok, :not_sampled}, state}
      end
    end

    @impl true
    def handle_call({:start_span, trace_context, operation_name, metadata}, _from, state) do
      trace_id = trace_context.trace_id

      case Map.get(state.active_traces, trace_id) do
        nil ->
          {:reply, {:error, :trace_not_found}, state}

        trace ->
          span_id = generate_span_id()
          span = create_new_span(span_id, trace_context.parent_span_id, operation_name, metadata)

          updated_spans = Map.put(trace.spans, span_id, span)
          updated_trace = %{trace | spans: updated_spans}
          updated_traces = Map.put(state.active_traces, trace_id, updated_trace)

          {:reply, {:ok, span_id}, %{state | active_traces: updated_traces}}
      end
    end

    @impl true
    def handle_call({:get_trace, trace_id}, _from, state) do
      trace = Map.get(state.active_traces, trace_id) || Map.get(state.completed_traces, trace_id)
      {:reply, trace, state}
    end

    @impl true
    def handle_cast({:finish_span, span_id, result, metadata}, state) do
      updated_traces =
        Enum.reduce(state.active_traces, %{}, fn {trace_id, trace}, acc ->
          case Map.get(trace.spans, span_id) do
            nil ->
              Map.put(acc, trace_id, trace)

            span ->
              finished_span = finish_span_internal(span, result, metadata)
              updated_spans = Map.put(trace.spans, span_id, finished_span)
              updated_trace = %{trace | spans: updated_spans}

              # Check if this completes the trace
              if trace_completed?(updated_trace) do
                completed_trace = complete_trace(updated_trace)
                export_trace(completed_trace, state.export_config)

                # Move to completed traces
                send(self(), {:move_to_completed, trace_id, completed_trace})
                acc
              else
                Map.put(acc, trace_id, updated_trace)
              end
          end
        end)

      {:noreply, %{state | active_traces: updated_traces}}
    end

    @impl true
    def handle_cast({:add_span_tag, span_id, key, value}, state) do
      updated_traces =
        update_span_in_traces(state.active_traces, span_id, fn span ->
          updated_tags = Map.put(span.tags, key, value)
          %{span | tags: updated_tags}
        end)

      {:noreply, %{state | active_traces: updated_traces}}
    end

    @impl true
    def handle_cast({:add_span_log, span_id, message, metadata}, state) do
      log_entry = %{
        timestamp: DateTime.utc_now(),
        message: message,
        metadata: metadata
      }

      updated_traces =
        update_span_in_traces(state.active_traces, span_id, fn span ->
          updated_logs = [log_entry | span.logs]
          %{span | logs: updated_logs}
        end)

      {:noreply, %{state | active_traces: updated_traces}}
    end

    @impl true
    def handle_info({:move_to_completed, trace_id, completed_trace}, state) do
      updated_active = Map.delete(state.active_traces, trace_id)
      updated_completed = Map.put(state.completed_traces, trace_id, completed_trace)

      {:noreply, %{state | active_traces: updated_active, completed_traces: updated_completed}}
    end

    @impl true
    def handle_info(:cleanup_traces, state) do
      {updated_active, expired_traces} =
        cleanup_expired_traces(state.active_traces, state.max_trace_duration)

      # Export expired traces
      Enum.each(expired_traces, fn trace ->
        export_trace(trace, state.export_config)
      end)

      # Cleanup old completed traces
      updated_completed = cleanup_old_completed_traces(state.completed_traces)

      schedule_cleanup()

      {:noreply, %{state | active_traces: updated_active, completed_traces: updated_completed}}
    end

    # Private implementation

    defp initialize_trace_config(opts) do
      %{
        max_spans_per_trace: Keyword.get(opts, :max_spans_per_trace, 100),
        max_logs_per_span: Keyword.get(opts, :max_logs_per_span, 50),
        auto_finish_root_spans: Keyword.get(opts, :auto_finish_root_spans, true)
      }
    end

    defp should_sample_trace?(sampling_rate) do
      :rand.uniform() <= sampling_rate
    end

    defp generate_trace_id do
      "trace_#{System.unique_integer([:positive])}_#{System.monotonic_time()}"
    end

    defp generate_span_id do
      "span_#{System.unique_integer([:positive])}_#{System.monotonic_time()}"
    end

    defp create_new_trace(trace_id, root_span_id, operation_name, metadata) do
      root_span = create_new_span(root_span_id, nil, operation_name, metadata)

      %{
        trace_id: trace_id,
        start_time: DateTime.utc_now(),
        end_time: nil,
        duration: nil,
        spans: %{root_span_id => root_span},
        root_span_id: root_span_id,
        metadata: metadata,
        status: :active
      }
    end

    defp create_new_span(span_id, parent_span_id, operation_name, metadata) do
      %{
        span_id: span_id,
        parent_span_id: parent_span_id,
        operation_name: operation_name,
        start_time: DateTime.utc_now(),
        end_time: nil,
        duration: nil,
        tags: %{},
        logs: [],
        metadata: metadata,
        status: :active
      }
    end

    defp finish_span_internal(span, result, metadata) do
      end_time = DateTime.utc_now()
      duration = DateTime.diff(end_time, span.start_time, :microsecond)

      %{
        span
        | end_time: end_time,
          duration: duration,
          status: result,
          metadata: Map.merge(span.metadata, metadata)
      }
    end

    defp trace_completed?(trace) do
      # Check if all spans are finished
      Enum.all?(trace.spans, fn {_span_id, span} ->
        span.status != :active
      end)
    end

    defp complete_trace(trace) do
      end_time = DateTime.utc_now()
      duration = DateTime.diff(end_time, trace.start_time, :microsecond)

      %{trace | end_time: end_time, duration: duration, status: :completed}
    end

    defp update_span_in_traces(traces, span_id, update_fn) do
      Enum.reduce(traces, %{}, fn {trace_id, trace}, acc ->
        case Map.get(trace.spans, span_id) do
          nil ->
            Map.put(acc, trace_id, trace)

          span ->
            updated_span = update_fn.(span)
            updated_spans = Map.put(trace.spans, span_id, updated_span)
            updated_trace = %{trace | spans: updated_spans}
            Map.put(acc, trace_id, updated_trace)
        end
      end)
    end

    defp cleanup_expired_traces(active_traces, max_duration) do
      current_time = DateTime.utc_now()

      Enum.split_with(active_traces, fn {_trace_id, trace} ->
        age = DateTime.diff(current_time, trace.start_time, :millisecond)
        age <= max_duration
      end)
    end

    defp cleanup_old_completed_traces(completed_traces) do
      # Keep only last 1000 completed traces
      completed_traces
      |> Enum.sort_by(fn {_id, trace} -> trace.end_time end, :desc)
      |> Enum.take(1000)
      |> Map.new()
    end

    defp export_trace(trace, export_config) do
      Enum.each(export_config, fn config ->
        case config do
          {:jaeger, jaeger_config} -> export_to_jaeger(trace, jaeger_config)
          {:zipkin, zipkin_config} -> export_to_zipkin(trace, zipkin_config)
          {:custom, export_fn} -> export_fn.(trace)
          _ -> :ok
        end
      end)
    end

    defp export_to_jaeger(_trace, _config) do
      # Implementation for Jaeger export
      :ok
    end

    defp export_to_zipkin(_trace, _config) do
      # Implementation for Zipkin export
      :ok
    end

    defp schedule_cleanup do
      Process.send_after(self(), :cleanup_traces, 60_000)
    end
  end

  defmodule AlertManager do
    @moduledoc """
    Alert management system for monitoring task execution and system health.
    """

    use GenServer

    defstruct [
      :name,
      :alert_rules,
      :active_alerts,
      :alert_history,
      :notification_channels,
      :escalation_policies,
      :alert_metrics
    ]

    @type alert_level :: :info | :warning | :error | :critical
    @type alert_status :: :active | :resolved | :suppressed | :escalated

    def start_link(opts \\ []) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def trigger_alert(manager \\ __MODULE__, alert_name, level, message, metadata \\ %{}) do
      GenServer.cast(manager, {:trigger_alert, alert_name, level, message, metadata})
    end

    def resolve_alert(manager \\ __MODULE__, alert_id) do
      GenServer.cast(manager, {:resolve_alert, alert_id})
    end

    def suppress_alert(manager \\ __MODULE__, alert_id, duration_ms) do
      GenServer.cast(manager, {:suppress_alert, alert_id, duration_ms})
    end

    def add_alert_rule(manager \\ __MODULE__, rule) do
      GenServer.call(manager, {:add_alert_rule, rule})
    end

    def get_active_alerts(manager \\ __MODULE__) do
      GenServer.call(manager, :get_active_alerts)
    end

    @impl true
    def init(opts) do
      state = %__MODULE__{
        name: Keyword.get(opts, :name, __MODULE__),
        alert_rules: initialize_default_rules(),
        active_alerts: %{},
        alert_history: [],
        notification_channels: Keyword.get(opts, :notification_channels, []),
        escalation_policies: Keyword.get(opts, :escalation_policies, %{}),
        alert_metrics: initialize_alert_metrics()
      }

      {:ok, state}
    end

    @impl true
    def handle_cast({:trigger_alert, alert_name, level, message, metadata}, state) do
      alert = create_alert(alert_name, level, message, metadata)

      # Check if this alert should be suppressed or deduplicated
      case should_trigger_alert?(alert, state) do
        true ->
          updated_active = Map.put(state.active_alerts, alert.id, alert)

          # Send notifications
          send_notifications(alert, state.notification_channels)

          # Update metrics
          updated_metrics = update_alert_metrics(state.alert_metrics, alert, :triggered)

          {:noreply, %{state | active_alerts: updated_active, alert_metrics: updated_metrics}}

        false ->
          {:noreply, state}
      end
    end

    @impl true
    def handle_cast({:resolve_alert, alert_id}, state) do
      case Map.get(state.active_alerts, alert_id) do
        nil ->
          {:noreply, state}

        alert ->
          resolved_alert = resolve_alert_internal(alert)
          updated_active = Map.delete(state.active_alerts, alert_id)
          updated_history = [resolved_alert | Enum.take(state.alert_history, 999)]

          # Send resolution notifications
          send_resolution_notifications(resolved_alert, state.notification_channels)

          # Update metrics
          updated_metrics = update_alert_metrics(state.alert_metrics, resolved_alert, :resolved)

          {:noreply,
           %{
             state
             | active_alerts: updated_active,
               alert_history: updated_history,
               alert_metrics: updated_metrics
           }}
      end
    end

    @impl true
    def handle_cast({:suppress_alert, alert_id, duration_ms}, state) do
      case Map.get(state.active_alerts, alert_id) do
        nil ->
          {:noreply, state}

        alert ->
          suppressed_alert = suppress_alert_internal(alert, duration_ms)
          updated_active = Map.put(state.active_alerts, alert_id, suppressed_alert)

          {:noreply, %{state | active_alerts: updated_active}}
      end
    end

    @impl true
    def handle_call({:add_alert_rule, rule}, _from, state) do
      rule_id = generate_rule_id()
      rule_with_id = Map.put(rule, :id, rule_id)
      updated_rules = Map.put(state.alert_rules, rule_id, rule_with_id)

      {:reply, {:ok, rule_id}, %{state | alert_rules: updated_rules}}
    end

    @impl true
    def handle_call(:get_active_alerts, _from, state) do
      {:reply, Map.values(state.active_alerts), state}
    end

    # Private implementation

    defp initialize_default_rules do
      %{
        "high_error_rate" => %{
          condition: {:metric_threshold, "task_error_rate", :>, 0.1},
          level: :warning,
          cooldown: 300_000
        },
        "resource_exhaustion" => %{
          condition: {:metric_threshold, "resource_utilization", :>, 0.9},
          level: :critical,
          cooldown: 60_000
        },
        "task_timeout" => %{
          condition: {:event_pattern, "task_timeout"},
          level: :error,
          cooldown: 120_000
        }
      }
    end

    defp initialize_alert_metrics do
      %{
        total_alerts: 0,
        alerts_by_level: %{info: 0, warning: 0, error: 0, critical: 0},
        alerts_by_source: %{},
        average_resolution_time: 0.0,
        escalation_count: 0
      }
    end

    defp create_alert(alert_name, level, message, metadata) do
      %{
        id: generate_alert_id(),
        name: alert_name,
        level: level,
        message: message,
        metadata: metadata,
        status: :active,
        created_at: DateTime.utc_now(),
        resolved_at: nil,
        suppressed_until: nil,
        escalation_count: 0,
        notification_sent: false
      }
    end

    defp should_trigger_alert?(alert, state) do
      # Check for deduplication
      similar_active =
        Enum.find(state.active_alerts, fn {_id, active_alert} ->
          active_alert.name == alert.name and active_alert.status == :active
        end)

      # Check cooldown periods
      recent_similar =
        Enum.find(state.alert_history, fn historical_alert ->
          historical_alert.name == alert.name and
            within_cooldown?(historical_alert, get_alert_cooldown(alert.name, state.alert_rules))
        end)

      is_nil(similar_active) and is_nil(recent_similar)
    end

    defp within_cooldown?(historical_alert, cooldown_ms) do
      case historical_alert.resolved_at do
        nil ->
          false

        resolved_time ->
          elapsed = DateTime.diff(DateTime.utc_now(), resolved_time, :millisecond)
          elapsed < cooldown_ms
      end
    end

    defp get_alert_cooldown(alert_name, alert_rules) do
      case Map.get(alert_rules, alert_name) do
        # Default 5 minutes
        nil -> 300_000
        rule -> Map.get(rule, :cooldown, 300_000)
      end
    end

    defp resolve_alert_internal(alert) do
      %{alert | status: :resolved, resolved_at: DateTime.utc_now()}
    end

    defp suppress_alert_internal(alert, duration_ms) do
      suppress_until = DateTime.utc_now() |> DateTime.add(duration_ms, :millisecond)

      %{alert | status: :suppressed, suppressed_until: suppress_until}
    end

    defp send_notifications(alert, notification_channels) do
      Enum.each(notification_channels, fn channel ->
        case channel do
          {:email, config} -> send_email_notification(alert, config)
          {:slack, config} -> send_slack_notification(alert, config)
          {:webhook, config} -> send_webhook_notification(alert, config)
          {:sms, config} -> send_sms_notification(alert, config)
          _ -> :ok
        end
      end)
    end

    defp send_resolution_notifications(alert, notification_channels) do
      # Similar to send_notifications but for resolutions
      Enum.each(notification_channels, fn channel ->
        case channel do
          {:email, config} -> send_email_resolution(alert, config)
          {:slack, config} -> send_slack_resolution(alert, config)
          _ -> :ok
        end
      end)
    end

    defp send_email_notification(_alert, _config) do
      # Implementation for email notifications
      :ok
    end

    defp send_slack_notification(_alert, _config) do
      # Implementation for Slack notifications
      :ok
    end

    defp send_webhook_notification(_alert, _config) do
      # Implementation for webhook notifications
      :ok
    end

    defp send_sms_notification(_alert, _config) do
      # Implementation for SMS notifications
      :ok
    end

    defp send_email_resolution(_alert, _config) do
      # Implementation for email resolution notifications
      :ok
    end

    defp send_slack_resolution(_alert, _config) do
      # Implementation for Slack resolution notifications
      :ok
    end

    defp update_alert_metrics(metrics, alert, action) do
      updated_total = metrics.total_alerts + 1
      updated_by_level = Map.update!(metrics.alerts_by_level, alert.level, &(&1 + 1))

      case action do
        :triggered ->
          %{metrics | total_alerts: updated_total, alerts_by_level: updated_by_level}

        :resolved ->
          resolution_time =
            if alert.resolved_at and alert.created_at do
              DateTime.diff(alert.resolved_at, alert.created_at, :millisecond)
            else
              0
            end

          new_avg_resolution =
            if metrics.total_alerts > 0 do
              (metrics.average_resolution_time * (metrics.total_alerts - 1) + resolution_time) /
                metrics.total_alerts
            else
              resolution_time
            end

          %{metrics | average_resolution_time: new_avg_resolution}
      end
    end

    defp generate_alert_id do
      "alert_#{System.unique_integer([:positive])}_#{System.monotonic_time()}"
    end

    defp generate_rule_id do
      "rule_#{System.unique_integer([:positive])}_#{System.monotonic_time()}"
    end
  end

  # Main Monitoring API

  def start_monitoring_system(opts \\ []) do
    children = [
      {MetricsCollector, Keyword.get(opts, :metrics_collector, [])},
      {DistributedTracer, Keyword.get(opts, :distributed_tracer, [])},
      {AlertManager, Keyword.get(opts, :alert_manager, [])}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Dspy.MonitoringSupervisor)
  end

  def record_task_metric(metric_name, value, tags \\ %{}) do
    MetricsCollector.record_metric(metric_name, value, tags)
  end

  def start_task_trace(task_name, metadata \\ %{}) do
    DistributedTracer.start_trace(task_name, metadata)
  end

  def trigger_alert(alert_name, level, message, metadata \\ %{}) do
    AlertManager.trigger_alert(alert_name, level, message, metadata)
  end

  def get_system_health do
    %{
      metrics_summary: MetricsCollector.get_metric_summary(),
      active_alerts: AlertManager.get_active_alerts(),
      trace_status: get_trace_status()
    }
  end

  defp get_trace_status do
    # Get basic trace status information
    %{
      # Would get from DistributedTracer
      active_traces: 0,
      completed_traces: 0,
      average_trace_duration: 0.0
    }
  end
end
