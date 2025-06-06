defmodule Dspy.TaskScheduler do
  @moduledoc """
  Advanced task scheduler with priority queuing, dependency resolution,
  resource allocation, and intelligent scheduling strategies.

  The scheduler supports multiple scheduling algorithms, load balancing,
  task prioritization, and deadline-aware scheduling for real-world
  task execution scenarios.
  """

  use GenServer
  alias Dspy.TaskExecution.{RetryPolicy}
  alias Dspy.{TaskQueue, ResourceManager, DependencyResolver}

  defstruct [
    :name,
    :scheduling_strategy,
    :max_concurrent_tasks,
    :resource_manager,
    :dependency_resolver,
    :task_queue,
    :running_tasks,
    :completed_tasks,
    :failed_tasks,
    :metrics,
    :config,
    :event_handlers
  ]

  @type scheduling_strategy :: :fifo | :priority | :deadline | :resource_aware | :ml_optimized
  @type scheduler_config :: %{
          max_concurrent_tasks: pos_integer(),
          scheduling_interval: pos_integer(),
          resource_allocation_timeout: pos_integer(),
          dependency_check_interval: pos_integer(),
          cleanup_interval: pos_integer(),
          metrics_collection: boolean(),
          load_balancing: boolean()
        }

  @type t :: %__MODULE__{
          name: atom(),
          scheduling_strategy: scheduling_strategy(),
          max_concurrent_tasks: pos_integer(),
          resource_manager: pid(),
          dependency_resolver: pid(),
          task_queue: TaskQueue.t(),
          running_tasks: map(),
          completed_tasks: map(),
          failed_tasks: map(),
          metrics: map(),
          config: scheduler_config(),
          event_handlers: [function()]
        }

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def schedule_task(scheduler, task, opts \\ []) do
    GenServer.call(scheduler, {:schedule_task, task, opts})
  end

  def cancel_task(scheduler, task_id) do
    GenServer.call(scheduler, {:cancel_task, task_id})
  end

  def pause_task(scheduler, task_id) do
    GenServer.call(scheduler, {:pause_task, task_id})
  end

  def resume_task(scheduler, task_id) do
    GenServer.call(scheduler, {:resume_task, task_id})
  end

  def get_task_status(scheduler, task_id) do
    GenServer.call(scheduler, {:get_task_status, task_id})
  end

  def list_tasks(scheduler, filter \\ :all) do
    GenServer.call(scheduler, {:list_tasks, filter})
  end

  def get_metrics(scheduler) do
    GenServer.call(scheduler, :get_metrics)
  end

  def update_config(scheduler, config_updates) do
    GenServer.call(scheduler, {:update_config, config_updates})
  end

  def set_scheduling_strategy(scheduler, strategy) do
    GenServer.call(scheduler, {:set_scheduling_strategy, strategy})
  end

  # Server Implementation

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    strategy = Keyword.get(opts, :scheduling_strategy, :priority)
    max_concurrent = Keyword.get(opts, :max_concurrent_tasks, 10)

    # Start resource manager
    {:ok, resource_manager} = ResourceManager.start_link(name: :"#{name}_resource_manager")

    # Start dependency resolver
    {:ok, dependency_resolver} =
      DependencyResolver.start_link(name: :"#{name}_dependency_resolver")

    state = %__MODULE__{
      name: name,
      scheduling_strategy: strategy,
      max_concurrent_tasks: max_concurrent,
      resource_manager: resource_manager,
      dependency_resolver: dependency_resolver,
      task_queue: TaskQueue.new(strategy: strategy),
      running_tasks: %{},
      completed_tasks: %{},
      failed_tasks: %{},
      metrics: initialize_metrics(),
      config: initialize_config(opts),
      event_handlers: Keyword.get(opts, :event_handlers, [])
    }

    # Start periodic scheduling
    schedule_tick()

    {:ok, state}
  end

  @impl true
  def handle_call({:schedule_task, task, opts}, _from, state) do
    case validate_task(task) do
      :ok ->
        # Check dependencies
        case DependencyResolver.check_dependencies(state.dependency_resolver, task) do
          {:ok, :satisfied} ->
            # Add to queue
            updated_queue = TaskQueue.enqueue(state.task_queue, task, opts)
            updated_state = %{state | task_queue: updated_queue}

            # Emit event
            emit_event(state, :task_scheduled, %{task_id: task.id, priority: task.priority})

            # Try immediate scheduling if capacity available
            final_state = maybe_schedule_immediately(updated_state)

            {:reply, {:ok, task.id}, final_state}

          {:ok, :waiting} ->
            # Add to dependency wait queue
            DependencyResolver.add_waiting_task(state.dependency_resolver, task)
            emit_event(state, :task_waiting_dependencies, %{task_id: task.id})
            {:reply, {:ok, task.id}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:cancel_task, task_id}, _from, state) do
    case cancel_task_internal(state, task_id) do
      {:ok, updated_state} ->
        emit_event(state, :task_cancelled, %{task_id: task_id})
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:pause_task, task_id}, _from, state) do
    case Map.get(state.running_tasks, task_id) do
      nil ->
        {:reply, {:error, :task_not_running}, state}

      {task, executor_pid} ->
        # Signal executor to pause
        Dspy.TaskExecutor.pause(executor_pid)
        updated_task = %{task | status: :paused}
        updated_running = Map.put(state.running_tasks, task_id, {updated_task, executor_pid})

        emit_event(state, :task_paused, %{task_id: task_id})
        {:reply, :ok, %{state | running_tasks: updated_running}}
    end
  end

  @impl true
  def handle_call({:resume_task, task_id}, _from, state) do
    case Map.get(state.running_tasks, task_id) do
      {%{status: :paused} = task, executor_pid} ->
        # Signal executor to resume
        Dspy.TaskExecutor.resume(executor_pid)
        updated_task = %{task | status: :running}
        updated_running = Map.put(state.running_tasks, task_id, {updated_task, executor_pid})

        emit_event(state, :task_resumed, %{task_id: task_id})
        {:reply, :ok, %{state | running_tasks: updated_running}}

      _ ->
        {:reply, {:error, :task_not_paused}, state}
    end
  end

  @impl true
  def handle_call({:get_task_status, task_id}, _from, state) do
    status = find_task_status(state, task_id)
    {:reply, status, state}
  end

  @impl true
  def handle_call({:list_tasks, filter}, _from, state) do
    tasks = list_tasks_by_filter(state, filter)
    {:reply, tasks, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    current_metrics = calculate_current_metrics(state)
    {:reply, current_metrics, state}
  end

  @impl true
  def handle_call({:update_config, config_updates}, _from, state) do
    updated_config = Map.merge(state.config, config_updates)
    updated_state = %{state | config: updated_config}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:set_scheduling_strategy, strategy}, _from, state) do
    updated_queue = TaskQueue.change_strategy(state.task_queue, strategy)
    updated_state = %{state | scheduling_strategy: strategy, task_queue: updated_queue}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_info(:schedule_tick, state) do
    updated_state = schedule_next_tasks(state)
    schedule_tick()
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:task_completed, task_id, result}, state) do
    case Map.pop(state.running_tasks, task_id) do
      {{task, _executor_pid}, updated_running} ->
        completed_task = %{
          task
          | status: :completed,
            result: result,
            completed_at: DateTime.utc_now()
        }

        updated_completed = Map.put(state.completed_tasks, task_id, completed_task)

        # Release resources
        ResourceManager.release_resources(state.resource_manager, task.resources)

        # Check if this completion unblocks other tasks
        DependencyResolver.task_completed(state.dependency_resolver, task_id)

        # Update metrics
        updated_metrics = update_completion_metrics(state.metrics, completed_task)

        emit_event(state, :task_completed, %{task_id: task_id, result: result})

        updated_state = %{
          state
          | running_tasks: updated_running,
            completed_tasks: updated_completed,
            metrics: updated_metrics
        }

        # Try to schedule more tasks
        final_state = schedule_next_tasks(updated_state)
        {:noreply, final_state}

      {nil, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:task_failed, task_id, error}, state) do
    case Map.pop(state.running_tasks, task_id) do
      {{task, _executor_pid}, updated_running} ->
        # Check if we should retry
        case should_retry_task(task, error) do
          true ->
            # Retry the task
            retry_task = prepare_retry_task(task, error)
            updated_queue = TaskQueue.enqueue(state.task_queue, retry_task)

            emit_event(state, :task_retried, %{
              task_id: task_id,
              attempt: retry_task.metadata.retry_attempt
            })

            updated_state = %{state | running_tasks: updated_running, task_queue: updated_queue}

            {:noreply, updated_state}

          false ->
            # Mark as permanently failed
            failed_task = %{task | status: :failed, error: error, failed_at: DateTime.utc_now()}
            updated_failed = Map.put(state.failed_tasks, task_id, failed_task)

            # Release resources
            ResourceManager.release_resources(state.resource_manager, task.resources)

            # Update metrics
            updated_metrics = update_failure_metrics(state.metrics, failed_task)

            emit_event(state, :task_failed, %{task_id: task_id, error: error})

            updated_state = %{
              state
              | running_tasks: updated_running,
                failed_tasks: updated_failed,
                metrics: updated_metrics
            }

            # Try to schedule more tasks
            final_state = schedule_next_tasks(updated_state)
            {:noreply, final_state}
        end

      {nil, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:dependencies_satisfied, task}, state) do
    # Task dependencies are now satisfied, add to queue
    updated_queue = TaskQueue.enqueue(state.task_queue, task)
    updated_state = %{state | task_queue: updated_queue}

    emit_event(state, :dependencies_satisfied, %{task_id: task.id})

    # Try immediate scheduling
    final_state = maybe_schedule_immediately(updated_state)
    {:noreply, final_state}
  end

  # Private Functions

  defp validate_task(%Dspy.TaskExecution.Task{} = task) do
    cond do
      is_nil(task.module) or is_nil(task.function) ->
        {:error, :invalid_task_definition}

      not is_list(task.args) ->
        {:error, :invalid_arguments}

      task.timeout <= 0 ->
        {:error, :invalid_timeout}

      true ->
        :ok
    end
  end

  defp validate_task(_), do: {:error, :invalid_task}

  defp maybe_schedule_immediately(state) do
    if map_size(state.running_tasks) < state.max_concurrent_tasks do
      schedule_next_tasks(state)
    else
      state
    end
  end

  defp schedule_next_tasks(state) do
    available_slots = state.max_concurrent_tasks - map_size(state.running_tasks)

    if available_slots > 0 do
      {tasks_to_run, updated_queue} =
        TaskQueue.dequeue_multiple(state.task_queue, available_slots)

      # Start tasks
      {new_running_tasks, started_tasks} = start_tasks(tasks_to_run, state)

      updated_running = Map.merge(state.running_tasks, new_running_tasks)
      updated_metrics = update_scheduling_metrics(state.metrics, started_tasks)

      %{
        state
        | task_queue: updated_queue,
          running_tasks: updated_running,
          metrics: updated_metrics
      }
    else
      state
    end
  end

  defp start_tasks(tasks, state) do
    Enum.reduce(tasks, {%{}, []}, fn task, {running_acc, started_acc} ->
      case start_single_task(task, state) do
        {:ok, executor_pid} ->
          running_task =
            {%{task | status: :running, started_at: DateTime.utc_now()}, executor_pid}

          {
            Map.put(running_acc, task.id, running_task),
            [task.id | started_acc]
          }

        {:error, reason} ->
          # Failed to start, put back in queue or mark failed
          emit_event(state, :task_start_failed, %{task_id: task.id, reason: reason})
          {running_acc, started_acc}
      end
    end)
  end

  defp start_single_task(task, state) do
    # Allocate resources
    case ResourceManager.allocate_resources(state.resource_manager, task.resources) do
      {:ok, _allocation} ->
        # Start task executor
        case Dspy.TaskExecutor.start_link(task: task, scheduler: self()) do
          {:ok, executor_pid} ->
            emit_event(state, :task_started, %{task_id: task.id})
            {:ok, executor_pid}

          {:error, reason} ->
            # Release resources on failure
            ResourceManager.release_resources(state.resource_manager, task.resources)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cancel_task_internal(state, task_id) do
    cond do
      Map.has_key?(state.running_tasks, task_id) ->
        # Cancel running task
        {task, executor_pid} = Map.get(state.running_tasks, task_id)
        Dspy.TaskExecutor.cancel(executor_pid)

        updated_running = Map.delete(state.running_tasks, task_id)
        ResourceManager.release_resources(state.resource_manager, task.resources)

        {:ok, %{state | running_tasks: updated_running}}

      TaskQueue.contains?(state.task_queue, task_id) ->
        # Remove from queue
        updated_queue = TaskQueue.remove(state.task_queue, task_id)
        {:ok, %{state | task_queue: updated_queue}}

      true ->
        {:error, :task_not_found}
    end
  end

  defp find_task_status(state, task_id) do
    cond do
      Map.has_key?(state.running_tasks, task_id) ->
        {task, _} = Map.get(state.running_tasks, task_id)
        {:ok, task.status}

      Map.has_key?(state.completed_tasks, task_id) ->
        {:ok, :completed}

      Map.has_key?(state.failed_tasks, task_id) ->
        {:ok, :failed}

      TaskQueue.contains?(state.task_queue, task_id) ->
        {:ok, :pending}

      true ->
        {:error, :task_not_found}
    end
  end

  defp list_tasks_by_filter(state, filter) do
    all_tasks = %{
      running: Map.values(state.running_tasks) |> Enum.map(fn {task, _} -> task end),
      pending: TaskQueue.list_tasks(state.task_queue),
      completed: Map.values(state.completed_tasks),
      failed: Map.values(state.failed_tasks)
    }

    case filter do
      :all -> all_tasks
      :running -> all_tasks.running
      :pending -> all_tasks.pending
      :completed -> all_tasks.completed
      :failed -> all_tasks.failed
      _ -> all_tasks
    end
  end

  defp should_retry_task(task, _error) do
    retry_attempt = Map.get(task.metadata, :retry_attempt, 0)
    retry_attempt < task.retry_policy.max_attempts
  end

  defp prepare_retry_task(task, error) do
    retry_attempt = Map.get(task.metadata, :retry_attempt, 0) + 1
    delay = RetryPolicy.calculate_delay(task.retry_policy, retry_attempt)

    # Wait for delay
    Process.send_after(self(), {:delayed_retry, task.id}, delay)

    updated_metadata =
      Map.merge(task.metadata, %{
        retry_attempt: retry_attempt,
        previous_errors: [error | Map.get(task.metadata, :previous_errors, [])]
      })

    %{task | status: :pending, metadata: updated_metadata, started_at: nil, error: nil}
  end

  defp emit_event(state, event_type, data) do
    event = %{
      type: event_type,
      data: data,
      timestamp: DateTime.utc_now(),
      scheduler: state.name
    }

    Enum.each(state.event_handlers, fn handler ->
      spawn(fn -> handler.(event) end)
    end)
  end

  defp schedule_tick do
    Process.send_after(self(), :schedule_tick, 100)
  end

  defp initialize_metrics do
    %{
      tasks_scheduled: 0,
      tasks_completed: 0,
      tasks_failed: 0,
      tasks_cancelled: 0,
      average_execution_time: 0.0,
      average_wait_time: 0.0,
      resource_utilization: %{},
      throughput: 0.0,
      error_rate: 0.0
    }
  end

  defp initialize_config(opts) do
    defaults = %{
      max_concurrent_tasks: 10,
      scheduling_interval: 100,
      resource_allocation_timeout: 5000,
      dependency_check_interval: 1000,
      cleanup_interval: 60_000,
      metrics_collection: true,
      load_balancing: false
    }

    Enum.reduce(opts, defaults, fn {key, value}, acc ->
      if Map.has_key?(defaults, key) do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp calculate_current_metrics(state) do
    total_tasks = state.metrics.tasks_scheduled

    updated_metrics =
      if total_tasks > 0 do
        error_rate = state.metrics.tasks_failed / total_tasks
        completion_rate = state.metrics.tasks_completed / total_tasks

        %{
          state.metrics
          | error_rate: error_rate,
            completion_rate: completion_rate,
            current_running: map_size(state.running_tasks),
            pending_in_queue: TaskQueue.size(state.task_queue)
        }
      else
        state.metrics
      end

    Map.merge(updated_metrics, %{
      timestamp: DateTime.utc_now(),
      system_load: :erlang.statistics(:run_queue),
      memory_usage: :erlang.memory(:total)
    })
  end

  defp update_completion_metrics(metrics, _completed_task) do
    %{metrics | tasks_completed: metrics.tasks_completed + 1}
  end

  defp update_failure_metrics(metrics, _failed_task) do
    %{metrics | tasks_failed: metrics.tasks_failed + 1}
  end

  defp update_scheduling_metrics(metrics, started_tasks) do
    %{metrics | tasks_scheduled: metrics.tasks_scheduled + length(started_tasks)}
  end
end
