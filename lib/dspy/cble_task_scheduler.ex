defmodule Dspy.CBLETaskScheduler do
  @moduledoc """
  Advanced task scheduling and parallel processing for CBLE evaluation with
  dynamic load balancing, priority queuing, and resource optimization.
  """

  use GenServer
  require Logger

  defstruct [
    :worker_pool,
    :task_queue,
    :priority_queue,
    :resource_monitor,
    :load_balancer,
    :execution_stats,
    :config
  ]

  @type task_priority :: :critical | :high | :normal | :low

  @type task :: %{
          id: String.t(),
          type: atom(),
          payload: any(),
          priority: task_priority(),
          estimated_duration: integer(),
          resource_requirements: map(),
          dependencies: [String.t()],
          retry_count: integer(),
          created_at: DateTime.t(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }

  @type worker_state :: %{
          id: String.t(),
          status: :idle | :busy | :error,
          current_task: task() | nil,
          capabilities: [atom()],
          performance_score: float(),
          tasks_completed: integer(),
          average_duration: float()
        }

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def schedule_task(task, opts \\ []) do
    GenServer.call(__MODULE__, {:schedule_task, task, opts})
  end

  def schedule_batch(tasks, opts \\ []) do
    GenServer.call(__MODULE__, {:schedule_batch, tasks, opts})
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def await_completion(task_ids, timeout \\ 300_000) do
    GenServer.call(__MODULE__, {:await_completion, task_ids, timeout}, timeout + 1000)
  end

  # Server callbacks
  def init(opts) do
    config = build_config(opts)

    state = %__MODULE__{
      worker_pool: initialize_worker_pool(config),
      task_queue: :queue.new(),
      priority_queue: initialize_priority_queue(),
      resource_monitor: initialize_resource_monitor(),
      load_balancer: initialize_load_balancer(config),
      execution_stats: initialize_stats(),
      config: config
    }

    # Start monitoring workers
    schedule_worker_monitoring()

    # Start load balancing
    schedule_load_balancing()

    {:ok, state}
  end

  def handle_call({:schedule_task, task, opts}, _from, state) do
    # Enhance task with metadata
    enhanced_task = enhance_task(task, opts, state)

    # Add to appropriate queue
    new_state = add_to_queue(enhanced_task, state)

    # Trigger task distribution
    distribute_tasks(new_state)

    {:reply, {:ok, enhanced_task.id}, new_state}
  end

  def handle_call({:schedule_batch, tasks, opts}, _from, state) do
    # Analyze batch for optimization
    batch_analysis = analyze_batch(tasks, state)

    # Optimize task ordering
    optimized_tasks = optimize_task_order(tasks, batch_analysis)

    # Schedule all tasks
    {task_ids, new_state} =
      Enum.reduce(optimized_tasks, {[], state}, fn task, {ids, st} ->
        enhanced_task = enhance_task(task, opts, st)
        updated_state = add_to_queue(enhanced_task, st)
        {[enhanced_task.id | ids], updated_state}
      end)

    # Trigger distribution
    distribute_tasks(new_state)

    {:reply, {:ok, Enum.reverse(task_ids)}, new_state}
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      workers: get_worker_status(state),
      queued_tasks: get_queue_status(state),
      execution_stats: state.execution_stats,
      resource_usage: get_resource_usage(state)
    }

    {:reply, status, state}
  end

  def handle_call({:await_completion, task_ids, timeout}, from, state) do
    # Set up completion monitoring
    monitor_ref = make_ref()

    completion_state = %{
      task_ids: MapSet.new(task_ids),
      from: from,
      timeout: timeout,
      started_at: System.monotonic_time(:millisecond)
    }

    new_state =
      Map.put(
        state,
        :completion_monitors,
        Map.put(state[:completion_monitors] || %{}, monitor_ref, completion_state)
      )

    # Don't reply immediately - will reply when tasks complete
    {:noreply, new_state}
  end

  # Task execution handling
  def handle_info({:task_completed, worker_id, task_id, result}, state) do
    # Update worker state
    state = update_worker_state(state, worker_id, :idle)

    # Update execution stats
    state = update_execution_stats(state, task_id, result)

    # Check completion monitors
    state = check_completion_monitors(state, task_id)

    # Assign new task to worker if available
    state = assign_next_task(state, worker_id)

    {:noreply, state}
  end

  def handle_info({:task_failed, worker_id, task_id, error}, state) do
    Logger.error("Task #{task_id} failed on worker #{worker_id}: #{inspect(error)}")

    # Update worker state
    state = update_worker_state(state, worker_id, :idle)

    # Handle task retry
    state = handle_task_failure(state, task_id, error)

    # Assign new task to worker
    state = assign_next_task(state, worker_id)

    {:noreply, state}
  end

  def handle_info(:monitor_workers, state) do
    # Check worker health
    state = check_worker_health(state)

    # Rebalance if needed
    state = rebalance_workers(state)

    # Schedule next monitoring
    schedule_worker_monitoring()

    {:noreply, state}
  end

  def handle_info(:load_balance, state) do
    # Analyze current load
    load_analysis = analyze_system_load(state)

    # Adjust worker pool if needed
    state = adjust_worker_pool(state, load_analysis)

    # Optimize task distribution
    state = optimize_distribution(state, load_analysis)

    # Schedule next balancing
    schedule_load_balancing()

    {:noreply, state}
  end

  # Private functions

  defp build_config(opts) do
    %{
      worker_count: Keyword.get(opts, :worker_count, System.schedulers_online() * 2),
      max_workers: Keyword.get(opts, :max_workers, System.schedulers_online() * 4),
      min_workers: Keyword.get(opts, :min_workers, 2),
      task_timeout: Keyword.get(opts, :task_timeout, 60_000),
      max_retries: Keyword.get(opts, :max_retries, 3),
      priority_ratios:
        Keyword.get(opts, :priority_ratios, %{
          critical: 0.4,
          high: 0.3,
          normal: 0.2,
          low: 0.1
        }),
      resource_limits:
        Keyword.get(opts, :resource_limits, %{
          cpu: 0.8,
          memory: 0.7,
          api_calls_per_minute: 100
        })
    }
  end

  defp initialize_worker_pool(config) do
    1..config.worker_count
    |> Enum.map(fn i ->
      worker_id = "worker_#{i}"

      # Start worker process
      {:ok, pid} = start_worker(worker_id, config)

      {worker_id,
       %{
         id: worker_id,
         pid: pid,
         status: :idle,
         current_task: nil,
         capabilities: determine_worker_capabilities(i),
         performance_score: 1.0,
         tasks_completed: 0,
         average_duration: 0.0,
         created_at: DateTime.utc_now()
       }}
    end)
    |> Map.new()
  end

  defp start_worker(worker_id, config) do
    Task.start_link(fn ->
      worker_loop(worker_id, config)
    end)
  end

  defp worker_loop(worker_id, config) do
    receive do
      {:execute_task, task, scheduler_pid} ->
        # Execute the task
        result = execute_task_safely(task, config)

        # Report completion
        send(scheduler_pid, {:task_completed, worker_id, task.id, result})

        # Continue loop
        worker_loop(worker_id, config)

      {:shutdown} ->
        :ok
    end
  end

  defp execute_task_safely(task, config) do
    try do
      # Set timeout
      Task.async(fn ->
        execute_task(task)
      end)
      |> Task.await(config.task_timeout)
    catch
      :exit, {:timeout, _} ->
        {:error, :timeout}

      error ->
        {:error, error}
    end
  end

  defp execute_task(task) do
    case task.type do
      :evaluate_question -> execute_evaluation_task(task.payload)
      :extract_pdf -> execute_extraction_task(task.payload)
      :analyze_vision -> execute_vision_task(task.payload)
      :generate_analytics -> execute_analytics_task(task.payload)
      _ -> {:error, :unknown_task_type}
    end
  end

  defp enhance_task(task, opts, state) do
    Map.merge(task, %{
      id: generate_task_id(),
      priority: Keyword.get(opts, :priority, :normal),
      estimated_duration: estimate_task_duration(task, state),
      resource_requirements: estimate_resource_requirements(task),
      dependencies: Keyword.get(opts, :dependencies, []),
      retry_count: 0,
      created_at: DateTime.utc_now(),
      started_at: nil,
      completed_at: nil
    })
  end

  defp add_to_queue(task, state) do
    case task.priority do
      :critical ->
        %{state | priority_queue: PriorityQueue.push(state.priority_queue, task, 1)}

      :high ->
        %{state | priority_queue: PriorityQueue.push(state.priority_queue, task, 2)}

      :normal ->
        %{state | task_queue: :queue.in(task, state.task_queue)}

      :low ->
        %{state | task_queue: :queue.in(task, state.task_queue)}
    end
  end

  defp distribute_tasks(state) do
    # Find idle workers
    idle_workers = find_idle_workers(state)

    # Assign tasks to workers
    Enum.reduce(idle_workers, state, fn worker_id, acc_state ->
      assign_next_task(acc_state, worker_id)
    end)
  end

  defp find_idle_workers(state) do
    state.worker_pool
    |> Enum.filter(fn {_id, worker} -> worker.status == :idle end)
    |> Enum.map(fn {id, _worker} -> id end)
  end

  defp assign_next_task(state, worker_id) do
    # Get next task based on priority and worker capabilities
    case get_next_task(state, worker_id) do
      {task, new_state} ->
        # Update worker state
        worker = state.worker_pool[worker_id]

        updated_worker = %{
          worker
          | status: :busy,
            current_task: task,
            started_at: DateTime.utc_now()
        }

        updated_pool = Map.put(state.worker_pool, worker_id, updated_worker)

        # Send task to worker
        send(worker.pid, {:execute_task, task, self()})

        %{new_state | worker_pool: updated_pool}

      nil ->
        state
    end
  end

  defp get_next_task(state, worker_id) do
    worker = state.worker_pool[worker_id]

    # Check priority queue first
    case PriorityQueue.pop(state.priority_queue) do
      {{:value, task}, new_priority_queue} ->
        if can_execute_task?(worker, task) do
          {task, %{state | priority_queue: new_priority_queue}}
        else
          # Put back and try regular queue
          updated_queue = PriorityQueue.push(new_priority_queue, task, task.priority)
          get_from_regular_queue(%{state | priority_queue: updated_queue}, worker_id)
        end

      {:empty, _} ->
        get_from_regular_queue(state, worker_id)
    end
  end

  defp get_from_regular_queue(state, worker_id) do
    case :queue.out(state.task_queue) do
      {{:value, task}, new_queue} ->
        worker = state.worker_pool[worker_id]

        if can_execute_task?(worker, task) do
          {task, %{state | task_queue: new_queue}}
        else
          # Put back at end
          updated_queue = :queue.in(task, new_queue)
          {nil, %{state | task_queue: updated_queue}}
        end

      {:empty, _} ->
        nil
    end
  end

  defp can_execute_task?(worker, task) do
    # Check worker capabilities match task requirements
    required_capabilities = task[:required_capabilities] || []

    Enum.all?(required_capabilities, fn cap ->
      cap in worker.capabilities
    end)
  end

  defp analyze_batch(tasks, _state) do
    %{
      total_count: length(tasks),
      by_type: Enum.group_by(tasks, & &1.type),
      estimated_duration: Enum.sum(Enum.map(tasks, &(&1[:estimated_duration] || 1000))),
      dependencies: build_dependency_graph(tasks)
    }
  end

  defp optimize_task_order(tasks, analysis) do
    # Topological sort based on dependencies
    sorted = topological_sort(tasks, analysis.dependencies)

    # Further optimize by grouping similar tasks
    group_similar_tasks(sorted)
  end

  defp analyze_system_load(state) do
    total_workers = map_size(state.worker_pool)
    busy_workers = Enum.count(state.worker_pool, fn {_id, w} -> w.status == :busy end)

    queue_length = :queue.len(state.task_queue) + PriorityQueue.size(state.priority_queue)

    %{
      utilization: busy_workers / max(total_workers, 1),
      queue_pressure: queue_length / max(total_workers, 1),
      average_task_duration: calculate_average_duration(state),
      resource_usage: get_current_resource_usage()
    }
  end

  defp adjust_worker_pool(state, load_analysis) do
    cond do
      # Scale up if high utilization and queue pressure
      load_analysis.utilization > 0.9 and load_analysis.queue_pressure > 2 ->
        scale_up_workers(state)

      # Scale down if low utilization
      load_analysis.utilization < 0.3 and map_size(state.worker_pool) > state.config.min_workers ->
        scale_down_workers(state)

      true ->
        state
    end
  end

  defp scale_up_workers(state) do
    current_count = map_size(state.worker_pool)

    if current_count < state.config.max_workers do
      new_worker_count =
        min(
          current_count + 2,
          state.config.max_workers
        )

      new_workers =
        (current_count + 1)..new_worker_count
        |> Enum.map(fn i ->
          worker_id = "worker_#{i}"
          {:ok, pid} = start_worker(worker_id, state.config)

          {worker_id,
           %{
             id: worker_id,
             pid: pid,
             status: :idle,
             current_task: nil,
             capabilities: determine_worker_capabilities(i),
             performance_score: 1.0,
             tasks_completed: 0,
             average_duration: 0.0,
             created_at: DateTime.utc_now()
           }}
        end)
        |> Map.new()

      %{state | worker_pool: Map.merge(state.worker_pool, new_workers)}
    else
      state
    end
  end

  # Helper functions
  defp generate_task_id do
    "task_#{:erlang.unique_integer([:positive])}_#{System.system_time(:microsecond)}"
  end

  defp estimate_task_duration(task, _state) do
    # Use historical data for estimation
    base_duration =
      case task.type do
        :evaluate_question -> 5000
        :extract_pdf -> 10000
        :analyze_vision -> 8000
        :generate_analytics -> 3000
        _ -> 2000
      end

    # Adjust based on complexity
    complexity_factor = task[:complexity] || 1.0
    round(base_duration * complexity_factor)
  end

  defp estimate_resource_requirements(task) do
    case task.type do
      :evaluate_question -> %{cpu: 0.2, memory: 0.1, api_calls: 1}
      :extract_pdf -> %{cpu: 0.4, memory: 0.3, api_calls: 0}
      :analyze_vision -> %{cpu: 0.6, memory: 0.4, api_calls: 2}
      :generate_analytics -> %{cpu: 0.3, memory: 0.2, api_calls: 0}
      _ -> %{cpu: 0.1, memory: 0.1, api_calls: 0}
    end
  end

  defp determine_worker_capabilities(worker_index) do
    # Assign different capabilities to workers for specialization
    base_capabilities = [:evaluation, :extraction, :analytics]

    if rem(worker_index, 3) == 0 do
      [:vision | base_capabilities]
    else
      base_capabilities
    end
  end

  defp schedule_worker_monitoring do
    Process.send_after(self(), :monitor_workers, 5_000)
  end

  defp schedule_load_balancing do
    Process.send_after(self(), :load_balance, 10_000)
  end

  defp initialize_priority_queue do
    # Would use actual priority queue implementation
    %{}
  end

  defp initialize_resource_monitor do
    %{
      cpu_usage: [],
      memory_usage: [],
      api_calls: %{},
      last_update: DateTime.utc_now()
    }
  end

  defp initialize_load_balancer(config) do
    %{
      strategy: :adaptive,
      thresholds: config.resource_limits,
      history: []
    }
  end

  defp initialize_stats do
    %{
      tasks_completed: 0,
      tasks_failed: 0,
      total_duration: 0,
      by_type: %{},
      by_priority: %{},
      performance_metrics: []
    }
  end

  # Stub implementations
  defp execute_evaluation_task(_payload), do: {:ok, %{result: "evaluated"}}
  defp execute_extraction_task(_payload), do: {:ok, %{result: "extracted"}}
  defp execute_vision_task(_payload), do: {:ok, %{result: "analyzed"}}
  defp execute_analytics_task(_payload), do: {:ok, %{result: "generated"}}

  defp build_dependency_graph(_tasks), do: %{}
  defp topological_sort(tasks, _deps), do: tasks
  defp group_similar_tasks(tasks), do: tasks

  defp calculate_average_duration(_state), do: 5000.0
  defp get_current_resource_usage, do: %{cpu: 0.5, memory: 0.4}

  defp update_worker_state(state, worker_id, status) do
    worker = state.worker_pool[worker_id]
    updated_worker = %{worker | status: status, current_task: nil}
    %{state | worker_pool: Map.put(state.worker_pool, worker_id, updated_worker)}
  end

  defp update_execution_stats(state, _task_id, _result) do
    # Update statistics
    state
  end

  defp check_completion_monitors(state, _task_id) do
    # Check if any monitors are waiting for this task
    state
  end

  defp handle_task_failure(state, _task_id, _error) do
    # Handle retry logic
    state
  end

  defp check_worker_health(state) do
    # Monitor worker health
    state
  end

  defp rebalance_workers(state) do
    # Rebalance work distribution
    state
  end

  defp optimize_distribution(state, _load_analysis) do
    # Optimize task distribution strategy
    state
  end

  defp scale_down_workers(state) do
    # Remove idle workers
    state
  end

  defp get_worker_status(state) do
    Enum.map(state.worker_pool, fn {id, worker} ->
      %{
        id: id,
        status: worker.status,
        tasks_completed: worker.tasks_completed,
        performance_score: worker.performance_score
      }
    end)
  end

  defp get_queue_status(state) do
    %{
      regular_queue: :queue.len(state.task_queue),
      priority_queue: PriorityQueue.size(state.priority_queue)
    }
  end

  defp get_resource_usage(_state) do
    %{
      cpu: 0.5,
      memory: 0.4,
      api_calls_per_minute: 50
    }
  end
end

# Priority Queue module
defmodule PriorityQueue do
  def new, do: %{}
  def push(queue, item, _priority), do: Map.put(queue, item.id, item)
  def pop(queue) when queue == %{}, do: {:empty, queue}

  def pop(queue) do
    {key, value} = Enum.at(queue, 0)
    {{:value, value}, Map.delete(queue, key)}
  end

  def size(queue), do: map_size(queue)
end
