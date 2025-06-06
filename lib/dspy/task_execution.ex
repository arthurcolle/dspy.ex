defmodule Dspy.TaskExecution do
  @moduledoc """
  Core task execution abstraction layer providing foundational interfaces
  and behaviors for real-world task execution in DSPy.

  This module defines the fundamental abstractions needed for executing
  complex, multi-step tasks in real-world environments with proper error
  handling, monitoring, and resource management.
  """

  @type task_id :: String.t()
  @type task_status :: :pending | :running | :paused | :completed | :failed | :cancelled
  @type priority :: :low | :medium | :high | :critical
  @type resource_type :: :cpu | :memory | :network | :storage | :gpu | :custom

  @doc """
  Behavior for task executors that can run tasks.
  """
  @callback execute(task :: Task.t(), context :: map()) ::
              {:ok, result :: any()} | {:error, reason :: any()}

  @doc """
  Behavior for task schedulers that manage task execution.
  """
  @callback schedule(task :: Task.t(), opts :: keyword()) ::
              {:ok, task_id()} | {:error, reason :: any()}

  @doc """
  Behavior for task monitors that track execution.
  """
  @callback monitor(task_id(), opts :: keyword()) ::
              {:ok, status :: task_status()} | {:error, reason :: any()}

  defmodule Task do
    @moduledoc """
    Core task representation with metadata, dependencies, and execution context.
    """

    defstruct [
      :id,
      :name,
      :description,
      :type,
      :module,
      :function,
      :args,
      :dependencies,
      :requirements,
      :constraints,
      :metadata,
      :priority,
      :timeout,
      :retry_policy,
      :resources,
      :created_at,
      :started_at,
      :completed_at,
      :status,
      :result,
      :error,
      :execution_context,
      :progress,
      :checkpoints,
      :rollback_strategy,
      :side_effects
    ]

    @type t :: %__MODULE__{
            id: Dspy.TaskExecution.task_id(),
            name: String.t(),
            description: String.t(),
            type: atom(),
            module: module(),
            function: atom(),
            args: [any()],
            dependencies: [Dspy.TaskExecution.task_id()],
            requirements: map(),
            constraints: map(),
            metadata: map(),
            priority: Dspy.TaskExecution.priority(),
            timeout: pos_integer(),
            retry_policy: RetryPolicy.t(),
            resources: [Resource.t()],
            created_at: DateTime.t(),
            started_at: DateTime.t() | nil,
            completed_at: DateTime.t() | nil,
            status: Dspy.TaskExecution.task_status(),
            result: any(),
            error: any(),
            execution_context: ExecutionContext.t(),
            progress: Progress.t(),
            checkpoints: [Checkpoint.t()],
            rollback_strategy: RollbackStrategy.t(),
            side_effects: [SideEffect.t()]
          }

    def new(module, function, args, opts \\ []) do
      id = generate_task_id()

      %__MODULE__{
        id: id,
        name: Keyword.get(opts, :name, "#{module}.#{function}"),
        description: Keyword.get(opts, :description, ""),
        type: Keyword.get(opts, :type, :computation),
        module: module,
        function: function,
        args: args,
        dependencies: Keyword.get(opts, :dependencies, []),
        requirements: Keyword.get(opts, :requirements, %{}),
        constraints: Keyword.get(opts, :constraints, %{}),
        metadata: Keyword.get(opts, :metadata, %{}),
        priority: Keyword.get(opts, :priority, :medium),
        timeout: Keyword.get(opts, :timeout, 30_000),
        retry_policy: Keyword.get(opts, :retry_policy, Dspy.TaskExecution.RetryPolicy.default()),
        resources: Keyword.get(opts, :resources, []),
        created_at: DateTime.utc_now(),
        started_at: nil,
        completed_at: nil,
        status: :pending,
        result: nil,
        error: nil,
        execution_context: Dspy.TaskExecution.ExecutionContext.new(opts),
        progress: Dspy.TaskExecution.Progress.new(),
        checkpoints: [],
        rollback_strategy:
          Keyword.get(opts, :rollback_strategy, Dspy.TaskExecution.RollbackStrategy.default()),
        side_effects: []
      }
    end

    def mark_started(task) do
      %{task | status: :running, started_at: DateTime.utc_now()}
    end

    def mark_completed(task, result) do
      %{task | status: :completed, result: result, completed_at: DateTime.utc_now()}
    end

    def mark_failed(task, error) do
      %{task | status: :failed, error: error, completed_at: DateTime.utc_now()}
    end

    def update_progress(task, progress_data) do
      updated_progress = Dspy.TaskExecution.Progress.update(task.progress, progress_data)
      %{task | progress: updated_progress}
    end

    def add_checkpoint(task, checkpoint_data) do
      checkpoint = Dspy.TaskExecution.Checkpoint.new(checkpoint_data)
      %{task | checkpoints: [checkpoint | task.checkpoints]}
    end

    defp generate_task_id do
      "task_#{System.unique_integer([:positive])}_#{DateTime.utc_now() |> DateTime.to_unix()}"
    end
  end

  defmodule ExecutionContext do
    @moduledoc """
    Execution context containing environment, resources, and runtime information.
    """

    defstruct [
      :environment,
      :resources,
      :variables,
      :working_directory,
      :user_context,
      :security_context,
      :performance_context,
      :logging_context,
      :monitoring_context,
      :feature_flags
    ]

    @type t :: %__MODULE__{
            environment: atom(),
            resources: map(),
            variables: map(),
            working_directory: String.t(),
            user_context: map(),
            security_context: map(),
            performance_context: map(),
            logging_context: map(),
            monitoring_context: map(),
            feature_flags: map()
          }

    def new(opts \\ []) do
      %__MODULE__{
        environment: Keyword.get(opts, :environment, :development),
        resources: Keyword.get(opts, :resources, %{}),
        variables: Keyword.get(opts, :variables, %{}),
        working_directory: Keyword.get(opts, :working_directory, File.cwd!()),
        user_context: Keyword.get(opts, :user_context, %{}),
        security_context: Keyword.get(opts, :security_context, %{}),
        performance_context: Keyword.get(opts, :performance_context, %{}),
        logging_context: Keyword.get(opts, :logging_context, %{}),
        monitoring_context: Keyword.get(opts, :monitoring_context, %{}),
        feature_flags: Keyword.get(opts, :feature_flags, %{})
      }
    end

    def set_variable(context, key, value) do
      %{context | variables: Map.put(context.variables, key, value)}
    end

    def get_variable(context, key, default \\ nil) do
      Map.get(context.variables, key, default)
    end
  end

  defmodule Progress do
    @moduledoc """
    Task progress tracking with percentage, steps, and metadata.
    """

    defstruct [
      :percentage,
      :current_step,
      :total_steps,
      :step_name,
      :estimated_remaining,
      :metadata,
      :updated_at
    ]

    @type t :: %__MODULE__{
            percentage: float(),
            current_step: non_neg_integer(),
            total_steps: pos_integer(),
            step_name: String.t(),
            estimated_remaining: pos_integer(),
            metadata: map(),
            updated_at: DateTime.t()
          }

    def new(opts \\ []) do
      %__MODULE__{
        percentage: 0.0,
        current_step: 0,
        total_steps: Keyword.get(opts, :total_steps, 1),
        step_name: "Initializing",
        estimated_remaining: nil,
        metadata: %{},
        updated_at: DateTime.utc_now()
      }
    end

    def update(progress, data) do
      %{
        progress
        | percentage: Map.get(data, :percentage, progress.percentage),
          current_step: Map.get(data, :current_step, progress.current_step),
          step_name: Map.get(data, :step_name, progress.step_name),
          estimated_remaining: Map.get(data, :estimated_remaining, progress.estimated_remaining),
          metadata: Map.merge(progress.metadata, Map.get(data, :metadata, %{})),
          updated_at: DateTime.utc_now()
      }
    end

    def calculate_percentage(current_step, total_steps) when total_steps > 0 do
      current_step / total_steps * 100.0
    end

    def calculate_percentage(_, _), do: 0.0
  end

  defmodule Checkpoint do
    @moduledoc """
    Task checkpoints for recovery and rollback capabilities.
    """

    defstruct [
      :id,
      :name,
      :timestamp,
      :state,
      :metadata,
      :recovery_data
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            timestamp: DateTime.t(),
            state: map(),
            metadata: map(),
            recovery_data: any()
          }

    def new(data) do
      %__MODULE__{
        id: "checkpoint_#{System.unique_integer([:positive])}",
        name: Map.get(data, :name, "Checkpoint"),
        timestamp: DateTime.utc_now(),
        state: Map.get(data, :state, %{}),
        metadata: Map.get(data, :metadata, %{}),
        recovery_data: Map.get(data, :recovery_data, nil)
      }
    end
  end

  defmodule RetryPolicy do
    @moduledoc """
    Retry policy configuration for failed tasks.
    """

    defstruct [
      :max_attempts,
      :backoff_strategy,
      :base_delay,
      :max_delay,
      :jitter,
      :retry_on,
      :stop_on
    ]

    @type backoff_strategy :: :linear | :exponential | :constant | :custom
    @type t :: %__MODULE__{
            max_attempts: pos_integer(),
            backoff_strategy: backoff_strategy(),
            base_delay: pos_integer(),
            max_delay: pos_integer(),
            jitter: boolean(),
            retry_on: [atom()],
            stop_on: [atom()]
          }

    def default do
      %__MODULE__{
        max_attempts: 3,
        backoff_strategy: :exponential,
        base_delay: 1000,
        max_delay: 30_000,
        jitter: true,
        retry_on: [:timeout, :temporary_failure],
        stop_on: [:fatal_error, :invalid_input]
      }
    end

    def calculate_delay(policy, attempt_number) do
      base_delay =
        case policy.backoff_strategy do
          :constant -> policy.base_delay
          :linear -> policy.base_delay * attempt_number
          :exponential -> policy.base_delay * :math.pow(2, attempt_number - 1)
          # Would call custom function
          :custom -> policy.base_delay
        end

      delay = min(base_delay, policy.max_delay)

      if policy.jitter do
        jitter_amount = delay * 0.1 * :rand.uniform()
        round(delay + jitter_amount)
      else
        round(delay)
      end
    end
  end

  defmodule RollbackStrategy do
    @moduledoc """
    Rollback strategy for task failure recovery.
    """

    defstruct [
      :type,
      :checkpoints_to_keep,
      :rollback_function,
      :cleanup_function
    ]

    @type rollback_type :: :none | :checkpoint | :full | :custom
    @type t :: %__MODULE__{
            type: rollback_type(),
            checkpoints_to_keep: pos_integer(),
            rollback_function: function() | nil,
            cleanup_function: function() | nil
          }

    def default do
      %__MODULE__{
        type: :checkpoint,
        checkpoints_to_keep: 5,
        rollback_function: nil,
        cleanup_function: nil
      }
    end
  end

  defmodule Resource do
    @moduledoc """
    Resource requirements and allocations for tasks.
    """

    defstruct [
      :type,
      :amount,
      :unit,
      :max_amount,
      :allocation_strategy,
      :constraints,
      :fallback_resources
    ]

    @type allocation_strategy :: :immediate | :lazy | :shared | :exclusive
    @type t :: %__MODULE__{
            type: Dspy.TaskExecution.resource_type(),
            amount: number(),
            unit: String.t(),
            max_amount: number(),
            allocation_strategy: allocation_strategy(),
            constraints: map(),
            fallback_resources: [t()]
          }

    def new(type, amount, opts \\ []) do
      %__MODULE__{
        type: type,
        amount: amount,
        unit: Keyword.get(opts, :unit, "units"),
        max_amount: Keyword.get(opts, :max_amount, amount),
        allocation_strategy: Keyword.get(opts, :allocation_strategy, :immediate),
        constraints: Keyword.get(opts, :constraints, %{}),
        fallback_resources: Keyword.get(opts, :fallback_resources, [])
      }
    end
  end

  defmodule SideEffect do
    @moduledoc """
    Side effects tracking for task execution.
    """

    defstruct [
      :type,
      :description,
      :timestamp,
      :reversible,
      :cleanup_function,
      :impact_assessment,
      :metadata
    ]

    @type side_effect_type ::
            :file_creation
            | :file_modification
            | :network_call
            | :database_write
            | :external_service
            | :custom
    @type t :: %__MODULE__{
            type: side_effect_type(),
            description: String.t(),
            timestamp: DateTime.t(),
            reversible: boolean(),
            cleanup_function: function() | nil,
            impact_assessment: map(),
            metadata: map()
          }

    def new(type, description, opts \\ []) do
      %__MODULE__{
        type: type,
        description: description,
        timestamp: DateTime.utc_now(),
        reversible: Keyword.get(opts, :reversible, false),
        cleanup_function: Keyword.get(opts, :cleanup_function, nil),
        impact_assessment: Keyword.get(opts, :impact_assessment, %{}),
        metadata: Keyword.get(opts, :metadata, %{})
      }
    end
  end
end
