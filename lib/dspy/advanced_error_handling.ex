defmodule Dspy.AdvancedErrorHandling do
  @moduledoc """
  Advanced error handling and resilience patterns for DSPy systems.
  
  This module provides sophisticated error recovery, circuit breakers,
  adaptive retry mechanisms, and system resilience patterns specifically
  designed for LLM-based reasoning systems.
  
  ## Features
  
  - Intelligent retry with exponential backoff and jitter
  - Circuit breaker patterns for failing services
  - Graceful degradation strategies
  - Error classification and adaptive responses  
  - Distributed error tracking and learning
  - Context-aware fallback mechanisms
  - Performance-based error prediction
  
  ## Error Classification
  
  - `:transient` - Temporary errors that may resolve with retry
  - `:permanent` - Errors that won't resolve without intervention
  - `:resource` - Resource exhaustion or limit errors
  - `:network` - Network connectivity issues
  - `:api` - External API failures
  - `:internal` - Internal logic or bug errors
  - `:timeout` - Operation timeout errors
  - `:validation` - Input validation failures
  """
  
  require Logger
  use GenServer
  
  @type error_class :: :transient | :permanent | :resource | :network | :api | :internal | :timeout | :validation
  @type error_context :: %{
    operation: String.t(),
    module: atom(),
    input: term(),
    timestamp: DateTime.t(),
    attempt: pos_integer(),
    previous_errors: [term()]
  }
  
  @type retry_config :: %{
    max_attempts: pos_integer(),
    base_delay_ms: pos_integer(),
    max_delay_ms: pos_integer(),
    backoff_factor: float(),
    jitter_factor: float()
  }
  
  @type circuit_breaker_config :: %{
    failure_threshold: pos_integer(),
    success_threshold: pos_integer(),
    timeout_ms: pos_integer(),
    half_open_max_calls: pos_integer()
  }
  
  defstruct [
    :name,
    :circuit_breakers,
    :error_history,
    :retry_configs,
    :fallback_strategies,
    :performance_metrics,
    :learning_model
  ]
  
  # Default configurations
  @default_retry_config %{
    max_attempts: 3,
    base_delay_ms: 1000,
    max_delay_ms: 30_000,
    backoff_factor: 2.0,
    jitter_factor: 0.1
  }
  
  @default_circuit_breaker_config %{
    failure_threshold: 5,
    success_threshold: 3,
    timeout_ms: 60_000,
    half_open_max_calls: 3
  }
  
  @doc """
  Start the advanced error handling system.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Execute a function with advanced error handling and retry logic.
  
  ## Examples
  
      result = execute_with_resilience(fn ->
        SomeModule.risky_operation(data)
      end, %{
        operation: "risky_operation",
        module: SomeModule,
        retry_config: %{max_attempts: 5}
      })
  """
  @spec execute_with_resilience(function(), map()) :: {:ok, term()} | {:error, term()}
  def execute_with_resilience(fun, context \\ %{}) do
    operation_id = generate_operation_id()
    start_time = System.monotonic_time(:millisecond)
    
    enhanced_context = context
    |> Map.put(:operation_id, operation_id)
    |> Map.put(:start_time, start_time)
    |> Map.put_new(:operation, "unknown_operation")
    |> Map.put_new(:module, __MODULE__)
    |> Map.put_new(:retry_config, @default_retry_config)
    
    case check_circuit_breaker(enhanced_context) do
      :closed ->
        execute_with_retry(fun, enhanced_context, 1)
      :open ->
        {:error, {:circuit_breaker_open, enhanced_context.operation}}
      :half_open ->
        execute_with_circuit_breaker_test(fun, enhanced_context)
    end
  end
  
  @doc """
  Register a fallback strategy for a specific operation or error type.
  """
  @spec register_fallback(String.t(), error_class(), function()) :: :ok
  def register_fallback(operation, error_class, fallback_fun) do
    GenServer.call(__MODULE__, {:register_fallback, operation, error_class, fallback_fun})
  end
  
  @doc """
  Get error statistics and performance metrics.
  """
  @spec get_metrics() :: map()
  def get_metrics() do
    GenServer.call(__MODULE__, :get_metrics)
  end
  
  @doc """
  Classify an error based on its characteristics.
  """
  @spec classify_error(term()) :: error_class()
  def classify_error(error) do
    case error do
      {:error, :timeout} -> :timeout
      {:error, :econnrefused} -> :network
      {:error, :enotfound} -> :network
      {:error, :nxdomain} -> :network
      {:error, :rate_limit} -> :resource
      {:error, :quota_exceeded} -> :resource
      {:error, {:http_error, status}} when status in 500..599 -> :transient
      {:error, {:http_error, status}} when status in 400..499 -> :permanent
      {:error, :invalid_input} -> :validation
      {:error, :bad_request} -> :validation
      {:error, :unauthorized} -> :permanent
      {:error, :forbidden} -> :permanent
      {:timeout, _} -> :timeout
      %RuntimeError{} -> :internal
      %ArgumentError{} -> :validation
      _ -> :internal
    end
  end
  
  @doc """
  Predict the likelihood of an operation failing based on historical data.
  """
  @spec predict_failure_probability(String.t(), map()) :: float()
  def predict_failure_probability(operation, context) do
    GenServer.call(__MODULE__, {:predict_failure, operation, context})
  end
  
  # GenServer Implementation
  
  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, "default")
    
    state = %__MODULE__{
      name: name,
      circuit_breakers: %{},
      error_history: :ets.new(:error_history, [:ordered_set, :private]),
      retry_configs: %{},
      fallback_strategies: %{},
      performance_metrics: initialize_metrics(),
      learning_model: initialize_learning_model()
    }
    
    Logger.info("Advanced error handling system started: #{name}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register_fallback, operation, error_class, fallback_fun}, _from, state) do
    key = {operation, error_class}
    updated_strategies = Map.put(state.fallback_strategies, key, fallback_fun)
    new_state = %{state | fallback_strategies: updated_strategies}
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = compile_metrics(state)
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call({:predict_failure, operation, context}, _from, state) do
    probability = calculate_failure_probability(operation, context, state)
    {:reply, probability, state}
  end
  
  @impl true
  def handle_call({:record_error, operation_context, error}, _from, state) do
    updated_state = record_error_event(state, operation_context, error)
    {:reply, :ok, updated_state}
  end
  
  @impl true
  def handle_call({:record_success, operation_context}, _from, state) do
    updated_state = record_success_event(state, operation_context)
    {:reply, :ok, updated_state}
  end
  
  # Private implementation functions
  
  defp execute_with_retry(fun, context, attempt) do
    _retry_config = context.retry_config
    
    try do
      case fun.() do
        {:ok, result} ->
          record_success(context)
          {:ok, result}
        
        {:error, _reason} = error ->
          handle_error_with_retry(error, fun, context, attempt)
        
        result ->
          # Handle non-standard return formats
          record_success(context)
          {:ok, result}
      end
    rescue
      error ->
        handle_error_with_retry({:error, error}, fun, context, attempt)
    catch
      :exit, reason ->
        handle_error_with_retry({:error, {:exit, reason}}, fun, context, attempt)
    end
  end
  
  defp handle_error_with_retry(error, fun, context, attempt) do
    error_class = classify_error(error)
    record_error(context, error, error_class)
    
    retry_config = context.retry_config
    
    cond do
      attempt >= retry_config.max_attempts ->
        Logger.error("Operation failed after #{attempt} attempts: #{inspect(error)}")
        try_fallback(error, context) || error
      
      error_class == :permanent ->
        Logger.error("Permanent error detected, not retrying: #{inspect(error)}")
        try_fallback(error, context) || error
      
      true ->
        delay = calculate_retry_delay(attempt, retry_config)
        Logger.warning("Retrying operation after #{delay}ms (attempt #{attempt + 1}/#{retry_config.max_attempts})")
        
        Process.sleep(delay)
        execute_with_retry(fun, context, attempt + 1)
    end
  end
  
  defp calculate_retry_delay(attempt, config) do
    base_delay = config.base_delay_ms
    backoff_factor = config.backoff_factor
    jitter_factor = config.jitter_factor
    max_delay = config.max_delay_ms
    
    # Exponential backoff with jitter
    exponential_delay = base_delay * :math.pow(backoff_factor, attempt - 1)
    jitter = exponential_delay * jitter_factor * (:rand.uniform() - 0.5)
    final_delay = exponential_delay + jitter
    
    min(round(final_delay), max_delay)
  end
  
  defp check_circuit_breaker(context) do
    operation = context.operation
    
    case GenServer.call(__MODULE__, {:get_circuit_breaker_state, operation}) do
      nil -> :closed  # No circuit breaker configured
      state -> state
    end
  end
  
  defp execute_with_circuit_breaker_test(fun, context) do
    case execute_with_retry(fun, context, 1) do
      {:ok, result} ->
        GenServer.call(__MODULE__, {:circuit_breaker_success, context.operation})
        {:ok, result}
      
      {:error, _reason} = error ->
        GenServer.call(__MODULE__, {:circuit_breaker_failure, context.operation})
        error
    end
  end
  
  defp try_fallback(error, context) do
    error_class = classify_error(error)
    operation = context.operation
    
    case GenServer.call(__MODULE__, {:get_fallback, operation, error_class}) do
      nil ->
        nil
      
      fallback_fun ->
        Logger.info("Executing fallback for #{operation} (#{error_class})")
        
        try do
          case fallback_fun.(error, context) do
            {:ok, result} ->
              {:ok, result}
            other ->
              other
          end
        rescue
          fallback_error ->
            Logger.error("Fallback also failed: #{inspect(fallback_error)}")
            nil
        end
    end
  end
  
  defp record_success(context) do
    GenServer.call(__MODULE__, {:record_success, context})
  end
  
  defp record_error(context, error, error_class) do
    enhanced_context = Map.put(context, :error_class, error_class)
    GenServer.call(__MODULE__, {:record_error, enhanced_context, error})
  end
  
  defp record_error_event(state, context, error) do
    timestamp = System.monotonic_time(:millisecond)
    
    error_record = %{
      operation: context.operation,
      module: context.module,
      error: error,
      error_class: context.error_class,
      timestamp: timestamp,
      duration: timestamp - context.start_time,
      attempt: Map.get(context, :attempt, 1)
    }
    
    :ets.insert(state.error_history, {timestamp, error_record})
    
    # Update circuit breaker
    updated_breakers = update_circuit_breaker_on_failure(state.circuit_breakers, context.operation)
    
    # Update performance metrics
    updated_metrics = update_error_metrics(state.performance_metrics, error_record)
    
    %{state | 
      circuit_breakers: updated_breakers,
      performance_metrics: updated_metrics
    }
  end
  
  defp record_success_event(state, context) do
    timestamp = System.monotonic_time(:millisecond)
    
    success_record = %{
      operation: context.operation,
      module: context.module,
      timestamp: timestamp,
      duration: timestamp - context.start_time
    }
    
    # Update circuit breaker
    updated_breakers = update_circuit_breaker_on_success(state.circuit_breakers, context.operation)
    
    # Update performance metrics
    updated_metrics = update_success_metrics(state.performance_metrics, success_record)
    
    %{state |
      circuit_breakers: updated_breakers,
      performance_metrics: updated_metrics
    }
  end
  
  defp update_circuit_breaker_on_failure(breakers, operation) do
    current = Map.get(breakers, operation, %{state: :closed, failures: 0, successes: 0, last_failure: nil})
    
    updated = %{current |
      failures: current.failures + 1,
      last_failure: System.monotonic_time(:millisecond)
    }
    
    config = @default_circuit_breaker_config
    
    new_state = if updated.failures >= config.failure_threshold do
      :open
    else
      current.state
    end
    
    Map.put(breakers, operation, %{updated | state: new_state})
  end
  
  defp update_circuit_breaker_on_success(breakers, operation) do
    current = Map.get(breakers, operation, %{state: :closed, failures: 0, successes: 0, last_failure: nil})
    
    updated = %{current |
      successes: current.successes + 1,
      failures: 0  # Reset failure count on success
    }
    
    config = @default_circuit_breaker_config
    
    new_state = case current.state do
      :half_open ->
        if updated.successes >= config.success_threshold do
          :closed
        else
          :half_open
        end
      _ ->
        :closed
    end
    
    Map.put(breakers, operation, %{updated | state: new_state})
  end
  
  defp initialize_metrics() do
    %{
      total_operations: 0,
      total_errors: 0,
      error_rate: 0.0,
      average_latency: 0.0,
      operations_by_type: %{},
      errors_by_class: %{},
      performance_trends: []
    }
  end
  
  defp initialize_learning_model() do
    %{
      failure_patterns: %{},
      success_patterns: %{},
      prediction_accuracy: 0.5,
      model_version: 1
    }
  end
  
  defp update_error_metrics(metrics, error_record) do
    %{metrics |
      total_operations: metrics.total_operations + 1,
      total_errors: metrics.total_errors + 1,
      error_rate: (metrics.total_errors + 1) / (metrics.total_operations + 1),
      errors_by_class: Map.update(metrics.errors_by_class, error_record.error_class, 1, &(&1 + 1))
    }
  end
  
  defp update_success_metrics(metrics, success_record) do
    %{metrics |
      total_operations: metrics.total_operations + 1,
      average_latency: calculate_moving_average(metrics.average_latency, success_record.duration, metrics.total_operations),
      operations_by_type: Map.update(metrics.operations_by_type, success_record.operation, 1, &(&1 + 1))
    }
  end
  
  defp calculate_moving_average(current_avg, new_value, count) do
    if count == 1 do
      new_value
    else
      (current_avg * (count - 1) + new_value) / count
    end
  end
  
  defp compile_metrics(state) do
    recent_errors = get_recent_errors(state.error_history, 3600_000)  # Last hour
    
    %{
      circuit_breakers: state.circuit_breakers,
      performance_metrics: state.performance_metrics,
      recent_error_count: length(recent_errors),
      recent_error_rate: calculate_recent_error_rate(recent_errors),
      top_error_classes: get_top_error_classes(recent_errors),
      system_health: calculate_system_health(state)
    }
  end
  
  defp get_recent_errors(error_history, window_ms) do
    current_time = System.monotonic_time(:millisecond)
    cutoff_time = current_time - window_ms
    
    :ets.select(error_history, [
      {{:"$1", :"$2"}, [{:>=, :"$1", cutoff_time}], [:"$2"]}
    ])
  end
  
  defp calculate_recent_error_rate(recent_errors) do
    if length(recent_errors) == 0 do
      0.0
    else
      error_count = length(recent_errors)
      total_operations = error_count * 2  # Estimate, would need success tracking too
      error_count / total_operations
    end
  end
  
  defp get_top_error_classes(recent_errors) do
    recent_errors
    |> Enum.group_by(& &1.error_class)
    |> Enum.map(fn {class, errors} -> {class, length(errors)} end)
    |> Enum.sort_by(fn {_class, count} -> count end, :desc)
    |> Enum.take(5)
  end
  
  defp calculate_system_health(state) do
    metrics = state.performance_metrics
    
    cond do
      metrics.error_rate > 0.1 -> :critical
      metrics.error_rate > 0.05 -> :degraded
      metrics.error_rate > 0.01 -> :warning
      true -> :healthy
    end
  end
  
  defp calculate_failure_probability(operation, _context, state) do
    # Simplified failure prediction based on historical data
    error_history = get_recent_errors(state.error_history, 3600_000)
    operation_errors = Enum.filter(error_history, & &1.operation == operation)
    
    case length(operation_errors) do
      0 -> 0.1  # Base probability
      count when count < 5 -> 0.2
      count when count < 10 -> 0.4
      _ -> 0.7
    end
  end
  
  defp generate_operation_id() do
    "op_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end