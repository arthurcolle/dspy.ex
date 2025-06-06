defmodule Dspy.TaskQueue do
  @moduledoc """
  Advanced task queue with multiple prioritization strategies, intelligent
  scheduling algorithms, and dynamic queue management.

  Supports priority-based queuing, deadline scheduling, resource-aware
  prioritization, and machine learning-optimized task ordering.
  """

  defstruct [
    :strategy,
    :primary_queue,
    :priority_queues,
    :deadline_queue,
    :resource_queue,
    :ml_queue,
    :metadata,
    :statistics
  ]

  @type strategy :: :fifo | :priority | :deadline | :resource_aware | :ml_optimized | :hybrid
  @type queue_stats :: %{
          total_tasks: non_neg_integer(),
          enqueue_count: non_neg_integer(),
          dequeue_count: non_neg_integer(),
          average_wait_time: float(),
          priority_distribution: map()
        }

  @type t :: %__MODULE__{
          strategy: strategy(),
          primary_queue: :queue.queue(),
          priority_queues: map(),
          deadline_queue: list(),
          resource_queue: list(),
          ml_queue: list(),
          metadata: map(),
          statistics: queue_stats()
        }

  # Public API

  def new(opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :priority)

    %__MODULE__{
      strategy: strategy,
      primary_queue: :queue.new(),
      priority_queues: initialize_priority_queues(),
      deadline_queue: [],
      resource_queue: [],
      ml_queue: [],
      metadata: %{
        created_at: DateTime.utc_now(),
        last_optimization: DateTime.utc_now()
      },
      statistics: initialize_statistics()
    }
  end

  def enqueue(queue, task, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, queue.strategy)

    updated_queue =
      case strategy do
        :fifo -> enqueue_fifo(queue, task)
        :priority -> enqueue_priority(queue, task)
        :deadline -> enqueue_deadline(queue, task)
        :resource_aware -> enqueue_resource_aware(queue, task)
        :ml_optimized -> enqueue_ml_optimized(queue, task)
        :hybrid -> enqueue_hybrid(queue, task, opts)
      end

    update_enqueue_statistics(updated_queue, task)
  end

  def dequeue(queue) do
    case queue.strategy do
      :fifo -> dequeue_fifo(queue)
      :priority -> dequeue_priority(queue)
      :deadline -> dequeue_deadline(queue)
      :resource_aware -> dequeue_resource_aware(queue)
      :ml_optimized -> dequeue_ml_optimized(queue)
      :hybrid -> dequeue_hybrid(queue)
    end
  end

  def dequeue_multiple(queue, count) do
    dequeue_multiple_recursive(queue, count, [])
  end

  def peek(queue) do
    case queue.strategy do
      :fifo -> peek_fifo(queue)
      :priority -> peek_priority(queue)
      :deadline -> peek_deadline(queue)
      :resource_aware -> peek_resource_aware(queue)
      :ml_optimized -> peek_ml_optimized(queue)
      :hybrid -> peek_hybrid(queue)
    end
  end

  def size(queue) do
    case queue.strategy do
      :fifo -> :queue.len(queue.primary_queue)
      :priority -> calculate_priority_queue_size(queue.priority_queues)
      :deadline -> length(queue.deadline_queue)
      :resource_aware -> length(queue.resource_queue)
      :ml_optimized -> length(queue.ml_queue)
      :hybrid -> calculate_total_queue_size(queue)
    end
  end

  def empty?(queue) do
    size(queue) == 0
  end

  def contains?(queue, task_id) do
    find_task_in_queue(queue, task_id) != nil
  end

  def remove(queue, task_id) do
    case queue.strategy do
      :fifo -> remove_from_fifo(queue, task_id)
      :priority -> remove_from_priority(queue, task_id)
      :deadline -> remove_from_deadline(queue, task_id)
      :resource_aware -> remove_from_resource_aware(queue, task_id)
      :ml_optimized -> remove_from_ml_optimized(queue, task_id)
      :hybrid -> remove_from_hybrid(queue, task_id)
    end
  end

  def list_tasks(queue) do
    case queue.strategy do
      :fifo -> :queue.to_list(queue.primary_queue)
      :priority -> flatten_priority_queues(queue.priority_queues)
      :deadline -> queue.deadline_queue
      :resource_aware -> queue.resource_queue
      :ml_optimized -> queue.ml_queue
      :hybrid -> combine_all_queues(queue)
    end
  end

  def change_strategy(queue, new_strategy) do
    # Extract all tasks
    all_tasks = list_tasks(queue)

    # Create new queue with new strategy
    new_queue = new(strategy: new_strategy)

    # Re-enqueue all tasks
    Enum.reduce(all_tasks, new_queue, fn task, acc_queue ->
      enqueue(acc_queue, task)
    end)
  end

  def optimize_queue(queue) do
    case queue.strategy do
      :ml_optimized -> optimize_ml_queue(queue)
      :hybrid -> optimize_hybrid_queue(queue)
      :resource_aware -> optimize_resource_queue(queue)
      # No optimization needed for other strategies
      _ -> queue
    end
  end

  def get_queue_statistics(queue) do
    Map.merge(queue.statistics, %{
      current_size: size(queue),
      strategy: queue.strategy,
      last_updated: DateTime.utc_now(),
      queue_efficiency: calculate_queue_efficiency(queue)
    })
  end

  # Strategy-specific implementations

  defp enqueue_fifo(queue, task) do
    updated_primary = :queue.in(task, queue.primary_queue)
    %{queue | primary_queue: updated_primary}
  end

  defp dequeue_fifo(queue) do
    case :queue.out(queue.primary_queue) do
      {{:value, task}, updated_queue} ->
        {task, %{queue | primary_queue: updated_queue}}

      {:empty, _} ->
        {nil, queue}
    end
  end

  defp peek_fifo(queue) do
    case :queue.peek(queue.primary_queue) do
      {:value, task} -> task
      :empty -> nil
    end
  end

  defp enqueue_priority(queue, task) do
    priority = task.priority
    priority_queue = Map.get(queue.priority_queues, priority, :queue.new())
    updated_priority_queue = :queue.in(task, priority_queue)
    updated_priority_queues = Map.put(queue.priority_queues, priority, updated_priority_queue)

    %{queue | priority_queues: updated_priority_queues}
  end

  defp dequeue_priority(queue) do
    # Dequeue from highest priority first
    priorities = [:critical, :high, :medium, :low]

    case find_non_empty_priority_queue(queue.priority_queues, priorities) do
      {priority, priority_queue} ->
        case :queue.out(priority_queue) do
          {{:value, task}, updated_queue} ->
            updated_priority_queues = Map.put(queue.priority_queues, priority, updated_queue)
            {task, %{queue | priority_queues: updated_priority_queues}}

          {:empty, _} ->
            {nil, queue}
        end

      nil ->
        {nil, queue}
    end
  end

  defp peek_priority(queue) do
    priorities = [:critical, :high, :medium, :low]

    case find_non_empty_priority_queue(queue.priority_queues, priorities) do
      {_priority, priority_queue} ->
        case :queue.peek(priority_queue) do
          {:value, task} -> task
          :empty -> nil
        end

      nil ->
        nil
    end
  end

  defp enqueue_deadline(queue, task) do
    # Insert task in deadline-sorted order
    deadline = get_task_deadline(task)
    updated_deadline_queue = insert_by_deadline(queue.deadline_queue, task, deadline)

    %{queue | deadline_queue: updated_deadline_queue}
  end

  defp dequeue_deadline(queue) do
    case queue.deadline_queue do
      [task | rest] ->
        {task, %{queue | deadline_queue: rest}}

      [] ->
        {nil, queue}
    end
  end

  defp peek_deadline(queue) do
    case queue.deadline_queue do
      [task | _] -> task
      [] -> nil
    end
  end

  defp enqueue_resource_aware(queue, task) do
    # Calculate resource score and insert accordingly
    resource_score = calculate_resource_score(task)
    updated_resource_queue = insert_by_resource_score(queue.resource_queue, task, resource_score)

    %{queue | resource_queue: updated_resource_queue}
  end

  defp dequeue_resource_aware(queue) do
    case queue.resource_queue do
      [task | rest] ->
        {task, %{queue | resource_queue: rest}}

      [] ->
        {nil, queue}
    end
  end

  defp peek_resource_aware(queue) do
    case queue.resource_queue do
      [task | _] -> task
      [] -> nil
    end
  end

  defp enqueue_ml_optimized(queue, task) do
    # Use ML model to predict optimal position
    optimal_position = predict_optimal_position(task, queue.ml_queue)
    updated_ml_queue = insert_at_position(queue.ml_queue, task, optimal_position)

    %{queue | ml_queue: updated_ml_queue}
  end

  defp dequeue_ml_optimized(queue) do
    case queue.ml_queue do
      [task | rest] ->
        # Update ML model with dequeue information
        update_ml_model_on_dequeue(task, rest)
        {task, %{queue | ml_queue: rest}}

      [] ->
        {nil, queue}
    end
  end

  defp peek_ml_optimized(queue) do
    case queue.ml_queue do
      [task | _] -> task
      [] -> nil
    end
  end

  defp enqueue_hybrid(queue, task, opts) do
    # Hybrid strategy combines multiple approaches
    weight_config =
      Keyword.get(opts, :weights, %{
        priority: 0.4,
        deadline: 0.3,
        resource: 0.2,
        ml: 0.1
      })

    hybrid_score = calculate_hybrid_score(task, weight_config)

    # Use the score to determine which queue to use or position within queue
    target_queue = determine_hybrid_target_queue(hybrid_score, weight_config)

    case target_queue do
      :priority -> enqueue_priority(queue, task)
      :deadline -> enqueue_deadline(queue, task)
      :resource_aware -> enqueue_resource_aware(queue, task)
      :ml_optimized -> enqueue_ml_optimized(queue, task)
    end
  end

  defp dequeue_hybrid(queue) do
    # Hybrid dequeue strategy looks across multiple queues
    strategies_to_try = [:deadline, :priority, :resource_aware, :ml_optimized]

    case try_dequeue_from_strategies(queue, strategies_to_try) do
      {task, updated_queue} when not is_nil(task) ->
        {task, updated_queue}

      _ ->
        {nil, queue}
    end
  end

  defp peek_hybrid(queue) do
    strategies_to_try = [:deadline, :priority, :resource_aware, :ml_optimized]
    try_peek_from_strategies(queue, strategies_to_try)
  end

  # Utility functions

  defp dequeue_multiple_recursive(queue, 0, acc), do: {Enum.reverse(acc), queue}

  defp dequeue_multiple_recursive(queue, count, acc) do
    case dequeue(queue) do
      {nil, updated_queue} ->
        {Enum.reverse(acc), updated_queue}

      {task, updated_queue} ->
        dequeue_multiple_recursive(updated_queue, count - 1, [task | acc])
    end
  end

  defp initialize_priority_queues do
    %{
      critical: :queue.new(),
      high: :queue.new(),
      medium: :queue.new(),
      low: :queue.new()
    }
  end

  defp initialize_statistics do
    %{
      total_tasks: 0,
      enqueue_count: 0,
      dequeue_count: 0,
      average_wait_time: 0.0,
      priority_distribution: %{
        critical: 0,
        high: 0,
        medium: 0,
        low: 0
      }
    }
  end

  defp update_enqueue_statistics(queue, task) do
    updated_stats = %{
      queue.statistics
      | total_tasks: queue.statistics.total_tasks + 1,
        enqueue_count: queue.statistics.enqueue_count + 1,
        priority_distribution:
          Map.update!(
            queue.statistics.priority_distribution,
            task.priority,
            &(&1 + 1)
          )
    }

    %{queue | statistics: updated_stats}
  end

  defp find_non_empty_priority_queue(_priority_queues, []), do: nil

  defp find_non_empty_priority_queue(priority_queues, [priority | rest]) do
    case Map.get(priority_queues, priority) do
      queue when queue != nil ->
        if :queue.is_empty(queue) do
          find_non_empty_priority_queue(priority_queues, rest)
        else
          {priority, queue}
        end

      nil ->
        find_non_empty_priority_queue(priority_queues, rest)
    end
  end

  defp calculate_priority_queue_size(priority_queues) do
    priority_queues
    |> Map.values()
    |> Enum.map(&:queue.len/1)
    |> Enum.sum()
  end

  defp calculate_total_queue_size(queue) do
    fifo_size = :queue.len(queue.primary_queue)
    priority_size = calculate_priority_queue_size(queue.priority_queues)
    deadline_size = length(queue.deadline_queue)
    resource_size = length(queue.resource_queue)
    ml_size = length(queue.ml_queue)

    fifo_size + priority_size + deadline_size + resource_size + ml_size
  end

  defp find_task_in_queue(queue, task_id) do
    all_tasks = list_tasks(queue)
    Enum.find(all_tasks, fn task -> task.id == task_id end)
  end

  defp remove_from_fifo(queue, task_id) do
    queue_list = :queue.to_list(queue.primary_queue)
    filtered_list = Enum.reject(queue_list, fn task -> task.id == task_id end)
    updated_primary = :queue.from_list(filtered_list)

    %{queue | primary_queue: updated_primary}
  end

  defp remove_from_priority(queue, task_id) do
    updated_priority_queues =
      queue.priority_queues
      |> Enum.map(fn {priority, priority_queue} ->
        queue_list = :queue.to_list(priority_queue)
        filtered_list = Enum.reject(queue_list, fn task -> task.id == task_id end)
        updated_queue = :queue.from_list(filtered_list)
        {priority, updated_queue}
      end)
      |> Map.new()

    %{queue | priority_queues: updated_priority_queues}
  end

  defp remove_from_deadline(queue, task_id) do
    updated_deadline_queue = Enum.reject(queue.deadline_queue, fn task -> task.id == task_id end)
    %{queue | deadline_queue: updated_deadline_queue}
  end

  defp remove_from_resource_aware(queue, task_id) do
    updated_resource_queue = Enum.reject(queue.resource_queue, fn task -> task.id == task_id end)
    %{queue | resource_queue: updated_resource_queue}
  end

  defp remove_from_ml_optimized(queue, task_id) do
    updated_ml_queue = Enum.reject(queue.ml_queue, fn task -> task.id == task_id end)
    %{queue | ml_queue: updated_ml_queue}
  end

  defp remove_from_hybrid(queue, task_id) do
    # Remove from all queues in hybrid mode
    queue
    |> remove_from_fifo(task_id)
    |> remove_from_priority(task_id)
    |> remove_from_deadline(task_id)
    |> remove_from_resource_aware(task_id)
    |> remove_from_ml_optimized(task_id)
  end

  defp flatten_priority_queues(priority_queues) do
    [:critical, :high, :medium, :low]
    |> Enum.flat_map(fn priority ->
      Map.get(priority_queues, priority, :queue.new())
      |> :queue.to_list()
    end)
  end

  defp combine_all_queues(queue) do
    fifo_tasks = :queue.to_list(queue.primary_queue)
    priority_tasks = flatten_priority_queues(queue.priority_queues)

    fifo_tasks ++
      priority_tasks ++
      queue.deadline_queue ++
      queue.resource_queue ++ queue.ml_queue
  end

  defp get_task_deadline(task) do
    # Extract deadline from task metadata or calculate based on creation time + timeout
    case Map.get(task.metadata, :deadline) do
      nil ->
        DateTime.add(task.created_at, task.timeout, :millisecond)

      deadline ->
        deadline
    end
  end

  defp insert_by_deadline(queue_list, task, _deadline) do
    _task_deadline = get_task_deadline(task)

    Enum.sort([task | queue_list], fn task1, task2 ->
      deadline1 = get_task_deadline(task1)
      deadline2 = get_task_deadline(task2)
      DateTime.compare(deadline1, deadline2) == :lt
    end)
  end

  defp calculate_resource_score(task) do
    # Calculate a score based on resource requirements
    base_score =
      case task.priority do
        :critical -> 1000
        :high -> 100
        :medium -> 10
        :low -> 1
      end

    # Adjust based on resource requirements
    resource_factor = calculate_resource_factor(task.resources)
    base_score * resource_factor
  end

  defp calculate_resource_factor(resources) do
    if length(resources) == 0 do
      1.0
    else
      # Simpler resource calculation
      total_resource_weight =
        Enum.reduce(resources, 0.0, fn resource, acc ->
          acc + resource.amount
        end)

      # Lower resource requirements get higher scores (executed first)
      1.0 / (1.0 + total_resource_weight)
    end
  end

  defp insert_by_resource_score(queue_list, task, _score) do
    # Insert task maintaining resource score order (highest score first)
    Enum.sort([task | queue_list], fn task1, task2 ->
      score1 = calculate_resource_score(task1)
      score2 = calculate_resource_score(task2)
      score1 > score2
    end)
  end

  defp predict_optimal_position(_task, queue_list) do
    # Simplified ML prediction - in reality would use trained model
    # For now, use a simple heuristic
    queue_length = length(queue_list)

    # Random position for demonstration
    if queue_length == 0 do
      0
    else
      :rand.uniform(queue_length + 1) - 1
    end
  end

  defp insert_at_position(list, item, position) do
    {before, after_part} = Enum.split(list, position)
    before ++ [item] ++ after_part
  end

  defp update_ml_model_on_dequeue(_task, _remaining_queue) do
    # Update ML model with dequeue information
    # This would feed back to the ML model for learning
    :ok
  end

  defp calculate_hybrid_score(task, weight_config) do
    priority_score = priority_to_score(task.priority) * weight_config.priority
    deadline_score = deadline_to_score(task) * weight_config.deadline
    resource_score = calculate_resource_score(task) * weight_config.resource
    ml_score = predict_ml_score(task) * weight_config.ml

    priority_score + deadline_score + resource_score + ml_score
  end

  defp priority_to_score(:critical), do: 100
  defp priority_to_score(:high), do: 75
  defp priority_to_score(:medium), do: 50
  defp priority_to_score(:low), do: 25

  defp deadline_to_score(task) do
    deadline = get_task_deadline(task)
    now = DateTime.utc_now()

    time_until_deadline = DateTime.diff(deadline, now, :millisecond)

    # Higher score for tasks with closer deadlines
    max(0, 100 - time_until_deadline / 1000)
  end

  defp predict_ml_score(_task) do
    # Simplified ML score prediction
    :rand.uniform() * 100
  end

  defp determine_hybrid_target_queue(hybrid_score, weight_config) do
    # Determine which queue to use based on which component contributed most to score
    components = %{
      priority: hybrid_score * weight_config.priority,
      deadline: hybrid_score * weight_config.deadline,
      resource: hybrid_score * weight_config.resource,
      ml: hybrid_score * weight_config.ml
    }

    {max_component, _} = Enum.max_by(components, fn {_, score} -> score end)

    case max_component do
      :priority -> :priority
      :deadline -> :deadline
      :resource -> :resource_aware
      :ml -> :ml_optimized
    end
  end

  defp try_dequeue_from_strategies(queue, []), do: {nil, queue}

  defp try_dequeue_from_strategies(queue, [strategy | rest]) do
    case apply_strategy_dequeue(queue, strategy) do
      {nil, _} ->
        try_dequeue_from_strategies(queue, rest)

      result ->
        result
    end
  end

  defp try_peek_from_strategies(_queue, []), do: nil

  defp try_peek_from_strategies(queue, [strategy | rest]) do
    case apply_strategy_peek(queue, strategy) do
      nil ->
        try_peek_from_strategies(queue, rest)

      task ->
        task
    end
  end

  defp apply_strategy_dequeue(queue, :deadline), do: dequeue_deadline(queue)
  defp apply_strategy_dequeue(queue, :priority), do: dequeue_priority(queue)
  defp apply_strategy_dequeue(queue, :resource_aware), do: dequeue_resource_aware(queue)
  defp apply_strategy_dequeue(queue, :ml_optimized), do: dequeue_ml_optimized(queue)

  defp apply_strategy_peek(queue, :deadline), do: peek_deadline(queue)
  defp apply_strategy_peek(queue, :priority), do: peek_priority(queue)
  defp apply_strategy_peek(queue, :resource_aware), do: peek_resource_aware(queue)
  defp apply_strategy_peek(queue, :ml_optimized), do: peek_ml_optimized(queue)

  defp optimize_ml_queue(queue) do
    # Re-optimize ML queue based on current performance data
    optimized_ml_queue = reorder_ml_queue(queue.ml_queue)
    %{queue | ml_queue: optimized_ml_queue}
  end

  defp optimize_hybrid_queue(queue) do
    # Re-balance tasks across different queues in hybrid mode
    all_tasks = combine_all_queues(queue)

    # Clear all queues
    cleared_queue = %{
      queue
      | primary_queue: :queue.new(),
        priority_queues: initialize_priority_queues(),
        deadline_queue: [],
        resource_queue: [],
        ml_queue: []
    }

    # Re-enqueue all tasks with updated hybrid logic
    Enum.reduce(all_tasks, cleared_queue, fn task, acc_queue ->
      enqueue_hybrid(acc_queue, task, [])
    end)
  end

  defp optimize_resource_queue(queue) do
    # Re-calculate resource scores and reorder
    optimized_resource_queue =
      Enum.sort(queue.resource_queue, fn task1, task2 ->
        score1 = calculate_resource_score(task1)
        score2 = calculate_resource_score(task2)
        score1 > score2
      end)

    %{queue | resource_queue: optimized_resource_queue}
  end

  defp reorder_ml_queue(ml_queue) do
    # Simple reordering based on updated ML predictions
    Enum.sort(ml_queue, fn task1, task2 ->
      score1 = predict_ml_score(task1)
      score2 = predict_ml_score(task2)
      score1 > score2
    end)
  end

  defp calculate_queue_efficiency(queue) do
    stats = queue.statistics

    if stats.dequeue_count > 0 do
      # Simple efficiency metric
      completed_ratio = stats.dequeue_count / stats.enqueue_count
      wait_time_factor = max(0, 1.0 - stats.average_wait_time / 10_000)

      completed_ratio * wait_time_factor
    else
      0.0
    end
  end
end
