defmodule Dspy.ErrorHandler do
  @moduledoc """
  Comprehensive error handling and recovery system for task execution
  with intelligent retry mechanisms, circuit breakers, and failure analysis.
  """

  alias Dspy.TaskExecution.RetryPolicy

  defmodule ErrorClassifier do
    @moduledoc """
    Classifies errors for appropriate handling strategies.
    """

    @type error_category ::
            :transient | :permanent | :resource | :timeout | :dependency | :system | :unknown
    @type error_severity :: :low | :medium | :high | :critical

    defstruct [
      :category,
      :severity,
      :retryable,
      :escalate,
      :recovery_strategy,
      :error_pattern,
      :error_details,
      :classification_confidence
    ]

    @type t :: %__MODULE__{
            category: error_category(),
            severity: error_severity(),
            retryable: boolean(),
            escalate: boolean(),
            recovery_strategy: atom(),
            error_pattern: String.t(),
            error_details: map(),
            classification_confidence: float()
          }

    def classify_error(error) do
      {category, severity} = analyze_error_type(error)

      %__MODULE__{
        category: category,
        severity: severity,
        retryable: is_retryable?(category, error),
        escalate: should_escalate?(severity, category),
        recovery_strategy: determine_recovery_strategy(category, severity),
        error_pattern: extract_error_pattern(error),
        error_details: extract_error_details(error),
        classification_confidence: calculate_classification_confidence(error)
      }
    end

    defp analyze_error_type(error) do
      case error do
        # Network/Connection errors
        %{reason: :timeout} -> {:timeout, :medium}
        %{reason: :econnrefused} -> {:transient, :medium}
        %{reason: :nxdomain} -> {:permanent, :high}
        # Resource errors
        %{reason: :enomem} -> {:resource, :high}
        %{reason: :enospc} -> {:resource, :critical}
        %{reason: :emfile} -> {:resource, :high}
        # System errors
        %{reason: :enoent} -> {:system, :medium}
        %{reason: :eacces} -> {:system, :high}
        %{reason: :eperm} -> {:permanent, :high}
        # Task-specific errors
        {:error, :invalid_input} -> {:permanent, :low}
        {:error, :dependency_failure} -> {:dependency, :medium}
        {:error, :computation_error} -> {:transient, :medium}
        # Elixir/OTP errors
        {:error, :badarg} -> {:permanent, :low}
        {:error, :badarith} -> {:permanent, :low}
        {:error, :function_clause} -> {:permanent, :medium}
        {:error, :undef} -> {:permanent, :high}
        # Process errors
        :killed -> {:system, :medium}
        :normal -> {:system, :low}
        {:shutdown, _} -> {:system, :low}
        # Pattern matching errors
        %MatchError{} -> {:permanent, :medium}
        %ArithmeticError{} -> {:permanent, :low}
        %ArgumentError{} -> {:permanent, :low}
        %RuntimeError{} -> {:transient, :medium}
        # Unknown errors
        _ -> {:unknown, :medium}
      end
    end

    defp is_retryable?(category, _error) do
      case category do
        :transient -> true
        :timeout -> true
        :resource -> true
        :dependency -> true
        :system -> false
        :permanent -> false
        # Conservative approach
        :unknown -> true
      end
    end

    defp should_escalate?(severity, category) do
      case {severity, category} do
        {:critical, _} -> true
        {:high, :system} -> true
        {:high, :permanent} -> true
        {:high, :resource} -> true
        _ -> false
      end
    end

    defp determine_recovery_strategy(category, severity) do
      case {category, severity} do
        {:transient, _} -> :simple_retry
        {:timeout, _} -> :exponential_backoff
        {:resource, :high} -> :resource_cleanup_retry
        {:resource, :critical} -> :escalate_and_fail
        {:dependency, _} -> :dependency_retry
        {:system, _} -> :system_recovery
        {:permanent, _} -> :no_retry
        {:unknown, _} -> :cautious_retry
      end
    end

    defp extract_error_pattern(error) do
      case error do
        {atom, _} when is_atom(atom) -> Atom.to_string(atom)
        %{__struct__: module} -> module |> Module.split() |> List.last()
        binary when is_binary(binary) -> String.slice(binary, 0, 50)
        _ -> "unknown_pattern"
      end
    end

    defp extract_error_details(error) do
      %{
        error_type: error.__struct__ || :unknown,
        error_message: extract_error_message(error),
        stacktrace: extract_stacktrace(),
        timestamp: DateTime.utc_now()
      }
    end

    defp extract_error_message(error) do
      cond do
        is_exception(error) -> Exception.message(error)
        is_binary(error) -> error
        is_atom(error) -> Atom.to_string(error)
        is_tuple(error) -> inspect(error, limit: 100)
        true -> inspect(error, limit: 100)
      end
    end

    defp extract_stacktrace do
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.take(5)
    end

    defp calculate_classification_confidence(error) do
      # Simple heuristic for classification confidence
      case error do
        # Well-structured errors
        %{__struct__: _} -> 0.9
        {atom, _} when is_atom(atom) -> 0.8
        binary when is_binary(binary) -> 0.6
        _ -> 0.4
      end
    end
  end

  defmodule CircuitBreaker do
    @moduledoc """
    Circuit breaker pattern implementation for preventing cascading failures.
    """

    @type state :: :closed | :open | :half_open
    @type t :: %__MODULE__{
            name: String.t(),
            state: state(),
            failure_threshold: pos_integer(),
            recovery_timeout: pos_integer(),
            failure_count: non_neg_integer(),
            success_count: non_neg_integer(),
            last_failure_time: DateTime.t() | nil,
            state_change_history: list()
          }

    defstruct [
      :name,
      :state,
      :failure_threshold,
      :recovery_timeout,
      :failure_count,
      :success_count,
      :last_failure_time,
      :state_change_history
    ]

    def new(name, opts \\ []) do
      %__MODULE__{
        name: name,
        state: :closed,
        failure_threshold: Keyword.get(opts, :failure_threshold, 5),
        recovery_timeout: Keyword.get(opts, :recovery_timeout, 60_000),
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil,
        state_change_history: []
      }
    end

    def call(circuit_breaker, function) do
      case circuit_breaker.state do
        :closed ->
          execute_and_record(circuit_breaker, function)

        :open ->
          if should_attempt_recovery?(circuit_breaker) do
            transition_to_half_open(circuit_breaker)
            |> execute_and_record(function)
          else
            {{:error, :circuit_breaker_open}, circuit_breaker}
          end

        :half_open ->
          execute_and_record(circuit_breaker, function)
      end
    end

    defp execute_and_record(circuit_breaker, function) do
      case safe_execute(function) do
        {:ok, result} ->
          updated_breaker = record_success(circuit_breaker)
          {{:ok, result}, updated_breaker}

        {:error, error} ->
          updated_breaker = record_failure(circuit_breaker)
          {{:error, error}, updated_breaker}
      end
    end

    defp safe_execute(function) do
      try do
        result = function.()
        {:ok, result}
      rescue
        error -> {:error, error}
      catch
        :exit, reason -> {:error, {:exit, reason}}
        type, value -> {:error, {type, value}}
      end
    end

    defp record_success(circuit_breaker) do
      updated_breaker = %{
        circuit_breaker
        | success_count: circuit_breaker.success_count + 1,
          # Reset failure count on success
          failure_count: 0
      }

      case circuit_breaker.state do
        :half_open ->
          # Transition back to closed after success in half-open state
          transition_to_closed(updated_breaker)

        _ ->
          updated_breaker
      end
    end

    defp record_failure(circuit_breaker) do
      updated_failure_count = circuit_breaker.failure_count + 1

      updated_breaker = %{
        circuit_breaker
        | failure_count: updated_failure_count,
          last_failure_time: DateTime.utc_now()
      }

      if updated_failure_count >= circuit_breaker.failure_threshold do
        transition_to_open(updated_breaker)
      else
        updated_breaker
      end
    end

    defp should_attempt_recovery?(circuit_breaker) do
      case circuit_breaker.last_failure_time do
        nil ->
          true

        last_failure ->
          elapsed = DateTime.diff(DateTime.utc_now(), last_failure, :millisecond)
          elapsed >= circuit_breaker.recovery_timeout
      end
    end

    defp transition_to_closed(circuit_breaker) do
      record_state_change(circuit_breaker, :closed)
    end

    defp transition_to_open(circuit_breaker) do
      record_state_change(circuit_breaker, :open)
    end

    defp transition_to_half_open(circuit_breaker) do
      record_state_change(circuit_breaker, :half_open)
    end

    defp record_state_change(circuit_breaker, new_state) do
      state_change = %{
        from: circuit_breaker.state,
        to: new_state,
        timestamp: DateTime.utc_now(),
        failure_count: circuit_breaker.failure_count
      }

      %{
        circuit_breaker
        | state: new_state,
          state_change_history: [
            state_change | Enum.take(circuit_breaker.state_change_history, 9)
          ]
      }
    end
  end

  defmodule RecoveryManager do
    @moduledoc """
    Manages recovery strategies for different types of failures.
    """

    use GenServer

    defstruct [
      :recovery_strategies,
      :active_recoveries,
      :circuit_breakers,
      :failure_patterns,
      :recovery_metrics
    ]

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def attempt_recovery(manager \\ __MODULE__, task, error, recovery_context \\ %{}) do
      GenServer.call(manager, {:attempt_recovery, task, error, recovery_context})
    end

    def register_recovery_strategy(manager \\ __MODULE__, error_pattern, strategy) do
      GenServer.call(manager, {:register_recovery_strategy, error_pattern, strategy})
    end

    def get_recovery_metrics(manager \\ __MODULE__) do
      GenServer.call(manager, :get_recovery_metrics)
    end

    @impl true
    def init(_opts) do
      state = %__MODULE__{
        recovery_strategies: initialize_default_strategies(),
        active_recoveries: %{},
        circuit_breakers: %{},
        failure_patterns: %{},
        recovery_metrics: initialize_recovery_metrics()
      }

      {:ok, state}
    end

    @impl true
    def handle_call({:attempt_recovery, task, error, recovery_context}, _from, state) do
      classified_error = ErrorClassifier.classify_error(error)

      case find_recovery_strategy(state, classified_error) do
        {:ok, strategy} ->
          case execute_recovery_strategy(strategy, task, error, recovery_context, state) do
            {:ok, recovered_task, updated_state} ->
              {:reply, {:ok, recovered_task}, updated_state}

            {:error, recovery_error, updated_state} ->
              {:reply, {:error, recovery_error}, updated_state}
          end

        {:error, :no_strategy} ->
          {:reply, {:error, :no_recovery_strategy}, state}
      end
    end

    @impl true
    def handle_call({:register_recovery_strategy, error_pattern, strategy}, _from, state) do
      updated_strategies = Map.put(state.recovery_strategies, error_pattern, strategy)
      {:reply, :ok, %{state | recovery_strategies: updated_strategies}}
    end

    @impl true
    def handle_call(:get_recovery_metrics, _from, state) do
      {:reply, state.recovery_metrics, state}
    end

    defp initialize_default_strategies do
      %{
        "timeout" => &timeout_recovery_strategy/4,
        "resource" => &resource_recovery_strategy/4,
        "dependency" => &dependency_recovery_strategy/4,
        "transient" => &transient_recovery_strategy/4,
        "system" => &system_recovery_strategy/4
      }
    end

    defp initialize_recovery_metrics do
      %{
        total_recovery_attempts: 0,
        successful_recoveries: 0,
        failed_recoveries: 0,
        recovery_strategies_used: %{},
        average_recovery_time: 0.0
      }
    end

    defp find_recovery_strategy(state, classified_error) do
      strategy_key = determine_strategy_key(classified_error)

      case Map.get(state.recovery_strategies, strategy_key) do
        nil -> {:error, :no_strategy}
        strategy -> {:ok, strategy}
      end
    end

    defp determine_strategy_key(classified_error) do
      case classified_error.recovery_strategy do
        :simple_retry -> "transient"
        :exponential_backoff -> "timeout"
        :resource_cleanup_retry -> "resource"
        :dependency_retry -> "dependency"
        :system_recovery -> "system"
        _ -> "transient"
      end
    end

    defp execute_recovery_strategy(strategy, task, error, recovery_context, state) do
      start_time = System.monotonic_time(:millisecond)

      try do
        case strategy.(task, error, recovery_context, state) do
          {:ok, recovered_task} ->
            recovery_time = System.monotonic_time(:millisecond) - start_time
            updated_state = record_successful_recovery(state, recovery_time)
            {:ok, recovered_task, updated_state}

          {:error, recovery_error} ->
            updated_state = record_failed_recovery(state)
            {:error, recovery_error, updated_state}
        end
      rescue
        recovery_exception ->
          updated_state = record_failed_recovery(state)
          {:error, recovery_exception, updated_state}
      end
    end

    defp record_successful_recovery(state, recovery_time) do
      updated_metrics = %{
        state.recovery_metrics
        | total_recovery_attempts: state.recovery_metrics.total_recovery_attempts + 1,
          successful_recoveries: state.recovery_metrics.successful_recoveries + 1,
          average_recovery_time:
            calculate_new_average_recovery_time(
              state.recovery_metrics.average_recovery_time,
              recovery_time,
              state.recovery_metrics.successful_recoveries
            )
      }

      %{state | recovery_metrics: updated_metrics}
    end

    defp record_failed_recovery(state) do
      updated_metrics = %{
        state.recovery_metrics
        | total_recovery_attempts: state.recovery_metrics.total_recovery_attempts + 1,
          failed_recoveries: state.recovery_metrics.failed_recoveries + 1
      }

      %{state | recovery_metrics: updated_metrics}
    end

    defp calculate_new_average_recovery_time(current_avg, new_time, success_count) do
      if success_count == 0 do
        new_time
      else
        (current_avg * (success_count - 1) + new_time) / success_count
      end
    end

    # Recovery Strategy Implementations

    defp timeout_recovery_strategy(task, _error, _recovery_context, _state) do
      # Increase timeout for retry
      # Max 5 minutes
      increased_timeout = min(task.timeout * 2, 300_000)

      updated_task = %{
        task
        | timeout: increased_timeout,
          metadata: Map.put(task.metadata, :recovery_applied, :timeout_increase)
      }

      {:ok, updated_task}
    end

    defp resource_recovery_strategy(task, error, recovery_context, _state) do
      # Attempt to free up resources and retry
      perform_resource_cleanup(error, recovery_context)
      # Reduce resource requirements slightly
      reduced_resources = reduce_resource_requirements(task.resources, 0.8)

      updated_task = %{
        task
        | resources: reduced_resources,
          metadata: Map.put(task.metadata, :recovery_applied, :resource_reduction)
      }

      {:ok, updated_task}
    end

    defp dependency_recovery_strategy(task, _error, recovery_context, _state) do
      # Check if dependencies are still valid and retry
      {:ok, :valid} = validate_dependencies(task.dependencies, recovery_context)
      # Add small delay before retry
      updated_task = %{
        task
        | metadata:
            Map.merge(task.metadata, %{
              recovery_applied: :dependency_revalidation,
              retry_delay: 5000
            })
      }

      {:ok, updated_task}
    end

    defp transient_recovery_strategy(task, _error, _recovery_context, _state) do
      # Simple retry with exponential backoff
      retry_attempt = Map.get(task.metadata, :retry_attempt, 0)
      delay = min(1000 * :math.pow(2, retry_attempt), 30_000)

      updated_task = %{
        task
        | metadata:
            Map.merge(task.metadata, %{
              recovery_applied: :exponential_backoff,
              retry_delay: round(delay)
            })
      }

      {:ok, updated_task}
    end

    defp system_recovery_strategy(task, error, recovery_context, _state) do
      # System-level recovery attempts
      perform_system_recovery(error, recovery_context)

      updated_task = %{
        task
        | metadata: Map.put(task.metadata, :recovery_applied, :system_recovery)
      }

      {:ok, updated_task}
    end

    # Helper functions

    defp perform_resource_cleanup(_error, _recovery_context) do
      # Simulate resource cleanup
      # In real implementation, this would:
      # - Free memory
      # - Close unused connections
      # - Clean up temporary files
      # - etc.
      :ok
    end

    defp reduce_resource_requirements(resources, factor) do
      Enum.map(resources, fn resource ->
        %{resource | amount: resource.amount * factor}
      end)
    end

    defp validate_dependencies(_dependencies, _recovery_context) do
      # Simulate dependency validation
      # In real implementation, this would check if dependencies are still available
      {:ok, :valid}
    end

    defp perform_system_recovery(_error, _recovery_context) do
      # Simulate system recovery
      # In real implementation, this would:
      # - Restart failed services
      # - Clear system caches
      # - Reset network connections
      # etc.
      :ok
    end
  end

  # Main Error Handler API

  def handle_task_error(task, error, context \\ %{}) do
    classified_error = ErrorClassifier.classify_error(error)

    case classified_error.retryable do
      true ->
        attempt_error_recovery(task, error, classified_error, context)

      false ->
        {:error, :permanent_failure, classified_error}
    end
  end

  def should_retry_task?(task, error) do
    classified_error = ErrorClassifier.classify_error(error)

    # Check retry policy
    retry_attempts = Map.get(task.metadata, :retry_attempt, 0)

    classified_error.retryable and
      retry_attempts < task.retry_policy.max_attempts and
      error_type_allows_retry?(classified_error.category, task.retry_policy)
  end

  def calculate_retry_delay(task, error, attempt_number) do
    classified_error = ErrorClassifier.classify_error(error)
    base_delay = RetryPolicy.calculate_delay(task.retry_policy, attempt_number)

    # Adjust delay based on error type
    adjustment_factor =
      case classified_error.category do
        # Longer delays for timeouts
        :timeout -> 2.0
        # Moderate delays for resource issues
        :resource -> 1.5
        # Normal delays for transient errors
        :transient -> 1.0
        # Shorter delays for dependency issues
        :dependency -> 0.5
        _ -> 1.0
      end

    round(base_delay * adjustment_factor)
  end

  def create_circuit_breaker(name, opts \\ []) do
    CircuitBreaker.new(name, opts)
  end

  def execute_with_circuit_breaker(circuit_breaker, function) do
    CircuitBreaker.call(circuit_breaker, function)
  end

  defp attempt_error_recovery(task, error, classified_error, context) do
    case RecoveryManager.attempt_recovery(task, error, context) do
      {:ok, recovered_task} ->
        {:ok, :retry_with_recovery, recovered_task}

      {:error, recovery_error} ->
        {:error, :recovery_failed,
         %{
           original_error: error,
           recovery_error: recovery_error,
           classification: classified_error
         }}
    end
  end

  defp error_type_allows_retry?(error_category, retry_policy) do
    allowed_categories =
      Map.get(retry_policy, :retry_on, [
        :timeout,
        :transient,
        :resource,
        :dependency
      ])

    error_category in allowed_categories
  end
end
