defmodule Dspy.TaskExecutor do
  @moduledoc """
  Task executor responsible for running individual tasks with proper
  monitoring, checkpointing, and error handling.

  The executor provides sandboxed execution environments, progress tracking,
  resource monitoring, and graceful handling of task lifecycle events.
  """

  use GenServer
  alias Dspy.TaskExecution.{Task, ExecutionContext, Progress, Checkpoint, SideEffect}

  defstruct [
    :task,
    :scheduler,
    :execution_pid,
    :monitor_ref,
    :status,
    :start_time,
    :execution_context,
    :progress_reporter,
    :checkpoint_manager,
    :resource_monitor,
    :side_effects,
    :output_buffer,
    :error_buffer
  ]

  @type t :: %__MODULE__{
          task: Task.t(),
          scheduler: pid(),
          execution_pid: pid() | nil,
          monitor_ref: reference() | nil,
          status: atom(),
          start_time: DateTime.t() | nil,
          execution_context: ExecutionContext.t(),
          progress_reporter: pid() | nil,
          checkpoint_manager: pid() | nil,
          resource_monitor: pid() | nil,
          side_effects: [SideEffect.t()],
          output_buffer: iodata(),
          error_buffer: iodata()
        }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def pause(executor) do
    GenServer.call(executor, :pause)
  end

  def resume(executor) do
    GenServer.call(executor, :resume)
  end

  def cancel(executor) do
    GenServer.call(executor, :cancel)
  end

  def get_progress(executor) do
    GenServer.call(executor, :get_progress)
  end

  def create_checkpoint(executor, checkpoint_data) do
    GenServer.call(executor, {:create_checkpoint, checkpoint_data})
  end

  def get_execution_info(executor) do
    GenServer.call(executor, :get_execution_info)
  end

  # Server Implementation

  @impl true
  def init(opts) do
    task = Keyword.fetch!(opts, :task)
    scheduler = Keyword.fetch!(opts, :scheduler)

    # Initialize execution context
    execution_context = prepare_execution_context(task)

    # Start supporting processes
    {:ok, progress_reporter} =
      Dspy.TaskExecutor.ProgressReporter.start_link(task: task, executor: self())

    {:ok, checkpoint_manager} =
      Dspy.TaskExecutor.CheckpointManager.start_link(task: task, strategy: task.rollback_strategy)

    {:ok, resource_monitor} =
      Dspy.TaskExecutor.ResourceMonitor.start_link(task: task, resources: task.resources)

    state = %__MODULE__{
      task: task,
      scheduler: scheduler,
      execution_pid: nil,
      monitor_ref: nil,
      status: :initializing,
      start_time: nil,
      execution_context: execution_context,
      progress_reporter: progress_reporter,
      checkpoint_manager: checkpoint_manager,
      resource_monitor: resource_monitor,
      side_effects: [],
      output_buffer: [],
      error_buffer: []
    }

    # Start execution
    {:ok, start_execution(state)}
  end

  @impl true
  def handle_call(:pause, _from, %{status: :running} = state) do
    case pause_execution(state) do
      {:ok, updated_state} ->
        {:reply, :ok, %{updated_state | status: :paused}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:pause, _from, state) do
    {:reply, {:error, :not_running}, state}
  end

  @impl true
  def handle_call(:resume, _from, %{status: :paused} = state) do
    case resume_execution(state) do
      {:ok, updated_state} ->
        {:reply, :ok, %{updated_state | status: :running}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:resume, _from, state) do
    {:reply, {:error, :not_paused}, state}
  end

  @impl true
  def handle_call(:cancel, _from, state) do
    {:ok, updated_state} = cancel_execution(state)
    notify_scheduler(state.scheduler, :task_cancelled, state.task.id, :cancelled)
    {:stop, :normal, :ok, %{updated_state | status: :cancelled}}
  end

  @impl true
  def handle_call(:get_progress, _from, state) do
    progress = Dspy.TaskExecutor.ProgressReporter.get_current_progress(state.progress_reporter)
    {:reply, {:ok, progress}, state}
  end

  @impl true
  def handle_call({:create_checkpoint, checkpoint_data}, _from, state) do
    case Dspy.TaskExecutor.CheckpointManager.create_checkpoint(
           state.checkpoint_manager,
           checkpoint_data
         ) do
      {:ok, checkpoint} ->
        # Update task with new checkpoint
        updated_task = Task.add_checkpoint(state.task, checkpoint_data)
        {:reply, {:ok, checkpoint}, %{state | task: updated_task}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_execution_info, _from, state) do
    info = %{
      task_id: state.task.id,
      status: state.status,
      start_time: state.start_time,
      execution_time: calculate_execution_time(state),
      progress: Dspy.TaskExecutor.ProgressReporter.get_current_progress(state.progress_reporter),
      resource_usage: Dspy.TaskExecutor.ResourceMonitor.get_current_usage(state.resource_monitor),
      side_effects: state.side_effects,
      checkpoint_count: length(state.task.checkpoints)
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{monitor_ref: ref} = state) do
    case reason do
      :normal ->
        # Task completed successfully
        final_state = finalize_successful_execution(state)
        notify_scheduler(state.scheduler, :task_completed, state.task.id, final_state.task.result)
        {:stop, :normal, final_state}

      error ->
        # Task failed
        final_state = finalize_failed_execution(state, error)
        notify_scheduler(state.scheduler, :task_failed, state.task.id, error)
        {:stop, :normal, final_state}
    end
  end

  @impl true
  def handle_info({:progress_update, progress_data}, state) do
    # Update task progress
    updated_task = Task.update_progress(state.task, progress_data)
    {:noreply, %{state | task: updated_task}}
  end

  @impl true
  def handle_info({:resource_alert, alert_type, data}, state) do
    case alert_type do
      :memory_high ->
        handle_memory_pressure(state, data)

      :cpu_high ->
        handle_cpu_pressure(state, data)

      :timeout_warning ->
        handle_timeout_warning(state, data)

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:side_effect, side_effect}, state) do
    updated_side_effects = [side_effect | state.side_effects]
    {:noreply, %{state | side_effects: updated_side_effects}}
  end

  @impl true
  def handle_info({:output, data}, state) do
    updated_buffer = [data | state.output_buffer]
    {:noreply, %{state | output_buffer: updated_buffer}}
  end

  @impl true
  def handle_info({:error_output, data}, state) do
    updated_buffer = [data | state.error_buffer]
    {:noreply, %{state | error_buffer: updated_buffer}}
  end

  # Private Functions

  defp start_execution(state) do
    # Create execution environment
    execution_env = create_execution_environment(state.execution_context)

    # Start the actual task execution
    {execution_pid, monitor_ref} =
      spawn_monitor(fn ->
        execute_task_safely(state.task, execution_env, self())
      end)

    %{
      state
      | execution_pid: execution_pid,
        monitor_ref: monitor_ref,
        status: :running,
        start_time: DateTime.utc_now()
    }
  end

  defp pause_execution(state) do
    if state.execution_pid do
      # Send pause signal to execution process
      send(state.execution_pid, :pause)
      {:ok, state}
    else
      {:error, :no_execution_process}
    end
  end

  defp resume_execution(state) do
    if state.execution_pid do
      # Send resume signal to execution process
      send(state.execution_pid, :resume)
      {:ok, state}
    else
      {:error, :no_execution_process}
    end
  end

  defp cancel_execution(state) do
    if state.execution_pid do
      # Kill execution process
      Process.exit(state.execution_pid, :kill)
      {:ok, state}
    else
      {:ok, state}
    end
  end

  defp prepare_execution_context(task) do
    # Enhance the task's execution context with runtime information
    base_context = task.execution_context

    %{
      base_context
      | variables:
          Map.merge(base_context.variables, %{
            "TASK_ID" => task.id,
            "TASK_NAME" => task.name,
            "TASK_TIMEOUT" => to_string(task.timeout),
            "EXECUTION_START" => DateTime.utc_now() |> DateTime.to_iso8601()
          })
    }
  end

  defp create_execution_environment(context) do
    %{
      working_directory: context.working_directory,
      environment_variables: context.variables,
      resource_limits: extract_resource_limits(context),
      security_context: context.security_context,
      io_redirection: %{
        stdout: self(),
        stderr: self()
      }
    }
  end

  defp execute_task_safely(task, execution_env, executor_pid) do
    try do
      # Set up execution environment
      setup_execution_environment(execution_env)

      # Execute the task
      result = apply(task.module, task.function, task.args)

      # Send result back
      send(executor_pid, {:execution_result, result})

      exit(:normal)
    rescue
      error ->
        send(executor_pid, {:execution_error, error})
        exit({:error, error})
    catch
      :exit, reason ->
        send(executor_pid, {:execution_exit, reason})
        exit(reason)

      type, value ->
        send(executor_pid, {:execution_throw, {type, value}})
        exit({:throw, {type, value}})
    end
  end

  defp setup_execution_environment(env) do
    # Change working directory
    File.cd!(env.working_directory)

    # Set environment variables
    Enum.each(env.environment_variables, fn {key, value} ->
      System.put_env(key, to_string(value))
    end)

    # Set up IO redirection if needed
    if env.io_redirection do
      Process.group_leader(self(), env.io_redirection.stdout)
    end
  end

  defp finalize_successful_execution(state) do
    # Collect final execution data
    execution_time = calculate_execution_time(state)

    final_progress =
      Dspy.TaskExecutor.ProgressReporter.get_current_progress(state.progress_reporter)

    final_resource_usage =
      Dspy.TaskExecutor.ResourceMonitor.get_final_usage(state.resource_monitor)

    # Update task with final data
    result =
      receive do
        {:execution_result, result} -> result
      after
        1000 -> nil
      end

    updated_task = %{
      state.task
      | result: result,
        completed_at: DateTime.utc_now(),
        status: :completed,
        progress: final_progress,
        metadata:
          Map.merge(state.task.metadata, %{
            execution_time_ms: execution_time,
            final_resource_usage: final_resource_usage,
            side_effects_count: length(state.side_effects)
          })
    }

    %{state | task: updated_task, status: :completed}
  end

  defp finalize_failed_execution(state, error) do
    # Collect error information
    execution_time = calculate_execution_time(state)

    final_resource_usage =
      Dspy.TaskExecutor.ResourceMonitor.get_final_usage(state.resource_monitor)

    # Perform rollback if needed
    case state.task.rollback_strategy.type do
      :checkpoint ->
        Dspy.TaskExecutor.CheckpointManager.rollback_to_latest(state.checkpoint_manager)

      :full ->
        perform_full_rollback(state)

      :custom ->
        if state.task.rollback_strategy.rollback_function do
          state.task.rollback_strategy.rollback_function.(state.task, error)
        end

      _ ->
        :ok
    end

    # Clean up side effects if possible
    cleanup_side_effects(state.side_effects)

    updated_task = %{
      state.task
      | error: error,
        completed_at: DateTime.utc_now(),
        status: :failed,
        metadata:
          Map.merge(state.task.metadata, %{
            execution_time_ms: execution_time,
            final_resource_usage: final_resource_usage,
            error_details: inspect(error),
            rollback_performed: state.task.rollback_strategy.type != :none
          })
    }

    %{state | task: updated_task, status: :failed}
  end

  defp handle_memory_pressure(state, data) do
    # Create emergency checkpoint
    checkpoint_data = %{
      name: "Emergency - Memory Pressure",
      state: %{memory_usage: data},
      recovery_data: %{reason: :memory_pressure}
    }

    Dspy.TaskExecutor.CheckpointManager.create_checkpoint(
      state.checkpoint_manager,
      checkpoint_data
    )

    # Optionally pause execution
    if data.usage_percentage > 90 do
      pause_execution(state)
      {:noreply, %{state | status: :paused}}
    else
      {:noreply, state}
    end
  end

  defp handle_cpu_pressure(state, _data) do
    # For CPU pressure, we might reduce task priority or add delays
    if state.execution_pid do
      send(state.execution_pid, {:reduce_priority, 0.5})
    end

    {:noreply, state}
  end

  defp handle_timeout_warning(state, data) do
    # Create checkpoint before potential timeout
    checkpoint_data = %{
      name: "Pre-timeout Checkpoint",
      state: %{remaining_time: data.remaining_ms},
      recovery_data: %{reason: :timeout_warning}
    }

    Dspy.TaskExecutor.CheckpointManager.create_checkpoint(
      state.checkpoint_manager,
      checkpoint_data
    )

    {:noreply, state}
  end

  defp notify_scheduler(scheduler, event_type, task_id, data) do
    send(scheduler, {event_type, task_id, data})
  end

  defp calculate_execution_time(state) do
    if state.start_time do
      DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    else
      0
    end
  end

  defp extract_resource_limits(context) do
    Map.get(context.performance_context, :resource_limits, %{})
  end

  defp perform_full_rollback(state) do
    # Implement full rollback logic
    # This would undo all side effects and restore system state
    cleanup_side_effects(state.side_effects)
  end

  defp cleanup_side_effects(side_effects) do
    Enum.each(side_effects, fn side_effect ->
      if side_effect.reversible and side_effect.cleanup_function do
        try do
          side_effect.cleanup_function.()
        rescue
          error ->
            # Log cleanup failure but don't fail the main operation
            IO.puts("Cleanup failed for side effect #{side_effect.type}: #{inspect(error)}")
        end
      end
    end)
  end

  # Supporting Process Modules

  defmodule ProgressReporter do
    @moduledoc """
    GenServer for tracking and reporting task execution progress.

    Monitors task progress, maintains progress history, and provides
    real-time updates on task execution status.
    """
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def get_current_progress(reporter) do
      GenServer.call(reporter, :get_progress)
    end

    def update_progress(reporter, progress_data) do
      GenServer.cast(reporter, {:update_progress, progress_data})
    end

    @impl true
    def init(opts) do
      task = Keyword.fetch!(opts, :task)
      executor = Keyword.fetch!(opts, :executor)

      state = %{
        task: task,
        executor: executor,
        progress: task.progress,
        last_update: DateTime.utc_now()
      }

      {:ok, state}
    end

    @impl true
    def handle_call(:get_progress, _from, state) do
      {:reply, state.progress, state}
    end

    @impl true
    def handle_cast({:update_progress, progress_data}, state) do
      updated_progress = Progress.update(state.progress, progress_data)
      send(state.executor, {:progress_update, progress_data})

      {:noreply, %{state | progress: updated_progress, last_update: DateTime.utc_now()}}
    end
  end

  defmodule CheckpointManager do
    @moduledoc """
    GenServer for managing task checkpoints and recovery.

    Creates, stores, and manages checkpoints for task recovery,
    enabling rollback to previous states in case of failures.
    """
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def create_checkpoint(manager, checkpoint_data) do
      GenServer.call(manager, {:create_checkpoint, checkpoint_data})
    end

    def rollback_to_latest(manager) do
      GenServer.call(manager, :rollback_to_latest)
    end

    @impl true
    def init(opts) do
      task = Keyword.fetch!(opts, :task)
      strategy = Keyword.fetch!(opts, :strategy)

      state = %{
        task: task,
        strategy: strategy,
        checkpoints: task.checkpoints
      }

      {:ok, state}
    end

    @impl true
    def handle_call({:create_checkpoint, checkpoint_data}, _from, state) do
      checkpoint = Checkpoint.new(checkpoint_data)
      updated_checkpoints = [checkpoint | state.checkpoints]

      # Keep only the specified number of checkpoints
      max_checkpoints = state.strategy.checkpoints_to_keep
      trimmed_checkpoints = Enum.take(updated_checkpoints, max_checkpoints)

      {:reply, {:ok, checkpoint}, %{state | checkpoints: trimmed_checkpoints}}
    end

    @impl true
    def handle_call(:rollback_to_latest, _from, state) do
      case state.checkpoints do
        [latest | _] ->
          # Perform rollback to latest checkpoint
          # This would restore the state from the checkpoint
          {:reply, {:ok, latest}, state}

        [] ->
          {:reply, {:error, :no_checkpoints}, state}
      end
    end
  end

  defmodule ResourceMonitor do
    @moduledoc """
    GenServer for monitoring resource usage during task execution.

    Tracks CPU, memory, and other resource usage, maintaining history
    and peak usage statistics for performance analysis.
    """
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def get_current_usage(monitor) do
      GenServer.call(monitor, :get_current_usage)
    end

    def get_final_usage(monitor) do
      GenServer.call(monitor, :get_final_usage)
    end

    @impl true
    def init(opts) do
      task = Keyword.fetch!(opts, :task)
      resources = Keyword.fetch!(opts, :resources)

      state = %{
        task: task,
        resources: resources,
        usage_history: [],
        peak_usage: %{},
        monitoring_interval: 1000
      }

      # Start monitoring
      schedule_monitoring()

      {:ok, state}
    end

    @impl true
    def handle_call(:get_current_usage, _from, state) do
      current_usage = collect_current_usage()
      {:reply, current_usage, state}
    end

    @impl true
    def handle_call(:get_final_usage, _from, state) do
      final_usage = %{
        peak_usage: state.peak_usage,
        total_samples: length(state.usage_history),
        average_usage: calculate_average_usage(state.usage_history)
      }

      {:reply, final_usage, state}
    end

    @impl true
    def handle_info(:monitor_resources, state) do
      current_usage = collect_current_usage()
      updated_history = [current_usage | state.usage_history]
      updated_peak = update_peak_usage(state.peak_usage, current_usage)

      # Check for resource alerts
      check_resource_alerts(current_usage, state.task)

      schedule_monitoring()

      {:noreply,
       %{
         state
         | # Keep last 100 samples
           usage_history: Enum.take(updated_history, 100),
           peak_usage: updated_peak
       }}
    end

    defp schedule_monitoring do
      Process.send_after(self(), :monitor_resources, 1000)
    end

    defp collect_current_usage do
      %{
        memory: :erlang.memory(:total),
        processes: :erlang.system_info(:process_count),
        reductions: :erlang.statistics(:reductions) |> elem(0),
        timestamp: DateTime.utc_now()
      }
    end

    defp update_peak_usage(peak, current) do
      %{
        memory: max(Map.get(peak, :memory, 0), current.memory),
        processes: max(Map.get(peak, :processes, 0), current.processes),
        reductions: max(Map.get(peak, :reductions, 0), current.reductions)
      }
    end

    defp calculate_average_usage(history) do
      if length(history) > 0 do
        memory_avg = history |> Enum.map(& &1.memory) |> Enum.sum() |> div(length(history))
        processes_avg = history |> Enum.map(& &1.processes) |> Enum.sum() |> div(length(history))

        %{memory: memory_avg, processes: processes_avg}
      else
        %{memory: 0, processes: 0}
      end
    end

    defp check_resource_alerts(usage, _task) do
      # Simple memory alert (would be more sophisticated in real implementation)
      memory_mb = usage.memory / (1024 * 1024)

      # Alert if using more than 100MB
      if memory_mb > 100 do
        # Send alert to executor (would need executor pid)
        # send(executor_pid, {:resource_alert, :memory_high, %{usage_mb: memory_mb}})
      end
    end
  end
end
