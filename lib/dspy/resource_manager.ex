defmodule Dspy.ResourceManager do
  @moduledoc """
  Resource manager for allocating and tracking system resources
  for task execution with intelligent load balancing and optimization.
  """

  use GenServer

  defstruct [
    :name,
    :total_resources,
    :allocated_resources,
    :available_resources,
    :allocation_history,
    :resource_limits,
    :allocation_strategy,
    :load_balancer,
    :optimization_enabled,
    :metrics
  ]

  @type allocation_result :: {:ok, map()} | {:error, atom()}
  @type resource_pool :: %{atom() => number()}

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def allocate_resources(manager, resources) do
    GenServer.call(manager, {:allocate_resources, resources})
  end

  def release_resources(manager, resources) do
    GenServer.call(manager, {:release_resources, resources})
  end

  def get_resource_status(manager) do
    GenServer.call(manager, :get_resource_status)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__),
      total_resources: initialize_total_resources(opts),
      allocated_resources: %{},
      available_resources: initialize_total_resources(opts),
      allocation_history: [],
      resource_limits: Keyword.get(opts, :resource_limits, %{}),
      allocation_strategy: Keyword.get(opts, :allocation_strategy, :first_fit),
      load_balancer: initialize_load_balancer(opts),
      optimization_enabled: Keyword.get(opts, :optimization_enabled, true),
      metrics: initialize_metrics()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:allocate_resources, resources}, _from, state) do
    case can_allocate_resources(state, resources) do
      {:ok, allocation_plan} ->
        updated_state = perform_allocation(state, resources, allocation_plan)
        {:reply, {:ok, allocation_plan}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:release_resources, resources}, _from, state) do
    updated_state = perform_release(state, resources)
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:get_resource_status, _from, state) do
    status = %{
      total: state.total_resources,
      allocated: state.allocated_resources,
      available: state.available_resources,
      utilization: calculate_utilization(state),
      metrics: state.metrics
    }

    {:reply, status, state}
  end

  defp initialize_total_resources(opts) do
    defaults = %{
      # CPU units
      cpu: 100.0,
      # MB
      memory: 8192.0,
      # Mbps
      network: 1000.0,
      # MB
      storage: 10240.0,
      # GPU units
      gpu: 0.0
    }

    Keyword.get(opts, :total_resources, defaults)
  end

  defp initialize_load_balancer(_opts) do
    %{
      strategy: :round_robin,
      current_index: 0,
      node_weights: %{},
      load_history: []
    }
  end

  defp initialize_metrics do
    %{
      total_allocations: 0,
      total_releases: 0,
      allocation_failures: 0,
      average_utilization: 0.0,
      peak_utilization: %{},
      allocation_latency: []
    }
  end

  defp can_allocate_resources(state, resources) do
    allocation_plan = plan_resource_allocation(state, resources)

    case validate_allocation_plan(state, allocation_plan) do
      :ok ->
        {:ok, allocation_plan}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp plan_resource_allocation(state, resources) do
    case state.allocation_strategy do
      :first_fit -> plan_first_fit(state, resources)
      :best_fit -> plan_best_fit(state, resources)
      :worst_fit -> plan_worst_fit(state, resources)
      :load_balanced -> plan_load_balanced(state, resources)
      :optimized -> plan_optimized(state, resources)
    end
  end

  defp plan_first_fit(state, resources) do
    Enum.reduce_while(resources, %{}, fn resource, acc ->
      required_amount = resource.amount
      resource_type = resource.type
      available = Map.get(state.available_resources, resource_type, 0)

      if available >= required_amount do
        allocation = %{
          type: resource_type,
          amount: required_amount,
          node: :local,
          allocation_id: generate_allocation_id()
        }

        {:cont, Map.put(acc, resource_type, allocation)}
      else
        {:halt, {:error, {:insufficient_resources, resource_type, required_amount, available}}}
      end
    end)
  end

  defp plan_best_fit(state, resources) do
    # Find the allocation that minimizes waste
    possible_allocations = generate_possible_allocations(state, resources)

    case find_best_allocation(possible_allocations) do
      nil -> {:error, :no_suitable_allocation}
      allocation -> allocation
    end
  end

  defp plan_worst_fit(state, resources) do
    # Allocate to minimize fragmentation
    # Simplified implementation
    plan_first_fit(state, resources)
  end

  defp plan_load_balanced(state, resources) do
    # Distribute load across available nodes/resources
    load_balancer = state.load_balancer

    case balance_resource_load(load_balancer, state.available_resources, resources) do
      {:ok, balanced_plan} -> balanced_plan
      {:error, reason} -> {:error, reason}
    end
  end

  defp plan_optimized(state, resources) do
    if state.optimization_enabled do
      # Use optimization algorithms to find best allocation
      optimize_allocation(state, resources)
    else
      plan_first_fit(state, resources)
    end
  end

  defp validate_allocation_plan(state, plan) when is_map(plan) do
    # Validate that the plan doesn't exceed available resources
    valid =
      Enum.all?(plan, fn {resource_type, allocation} ->
        available = Map.get(state.available_resources, resource_type, 0)
        allocation.amount <= available
      end)

    if valid do
      :ok
    else
      {:error, :plan_exceeds_available_resources}
    end
  end

  defp validate_allocation_plan(_state, {:error, reason}), do: {:error, reason}

  defp perform_allocation(state, resources, allocation_plan) when is_map(allocation_plan) do
    start_time = System.monotonic_time(:microsecond)

    # Update allocated resources
    updated_allocated =
      Enum.reduce(allocation_plan, state.allocated_resources, fn {type, allocation}, acc ->
        current_allocated = Map.get(acc, type, 0)
        Map.put(acc, type, current_allocated + allocation.amount)
      end)

    # Update available resources
    updated_available =
      Enum.reduce(allocation_plan, state.available_resources, fn {type, allocation}, acc ->
        current_available = Map.get(acc, type, 0)
        Map.put(acc, type, current_available - allocation.amount)
      end)

    # Record allocation history
    allocation_record = %{
      timestamp: DateTime.utc_now(),
      resources: resources,
      allocation_plan: allocation_plan,
      allocation_latency: System.monotonic_time(:microsecond) - start_time
    }

    # Update metrics
    updated_metrics = update_allocation_metrics(state.metrics, allocation_record)

    %{
      state
      | allocated_resources: updated_allocated,
        available_resources: updated_available,
        allocation_history: [allocation_record | Enum.take(state.allocation_history, 99)],
        metrics: updated_metrics
    }
  end

  defp perform_release(state, resources) do
    # Update allocated resources
    updated_allocated =
      Enum.reduce(resources, state.allocated_resources, fn resource, acc ->
        current_allocated = Map.get(acc, resource.type, 0)
        new_allocated = max(0, current_allocated - resource.amount)
        Map.put(acc, resource.type, new_allocated)
      end)

    # Update available resources
    updated_available =
      Enum.reduce(resources, state.available_resources, fn resource, acc ->
        current_available = Map.get(acc, resource.type, 0)
        total_for_type = Map.get(state.total_resources, resource.type, 0)
        new_available = min(total_for_type, current_available + resource.amount)
        Map.put(acc, resource.type, new_available)
      end)

    # Update metrics
    updated_metrics = update_release_metrics(state.metrics)

    %{
      state
      | allocated_resources: updated_allocated,
        available_resources: updated_available,
        metrics: updated_metrics
    }
  end

  defp generate_possible_allocations(state, resources) do
    # Generate all possible allocation combinations
    # Simplified implementation
    [plan_first_fit(state, resources)]
  end

  defp find_best_allocation(possible_allocations) do
    # Find allocation with minimum waste
    Enum.min_by(possible_allocations, fn allocation ->
      case allocation do
        {:error, _} -> :infinity
        plan -> calculate_allocation_waste(plan)
      end
    end)
  end

  defp calculate_allocation_waste(plan) do
    # Calculate resource waste for this allocation plan
    Enum.reduce(plan, 0, fn {_type, allocation}, acc ->
      # Simplified waste calculation
      acc + allocation.amount * 0.1
    end)
  end

  defp balance_resource_load(load_balancer, available_resources, resources) do
    case load_balancer.strategy do
      :round_robin -> balance_round_robin(load_balancer, available_resources, resources)
      :weighted -> balance_weighted(load_balancer, available_resources, resources)
      :least_loaded -> balance_least_loaded(load_balancer, available_resources, resources)
    end
  end

  defp balance_round_robin(_load_balancer, available_resources, resources) do
    # Simplified round-robin balancing
    plan_map =
      Enum.reduce(resources, %{}, fn resource, acc ->
        if Map.get(available_resources, resource.type, 0) >= resource.amount do
          allocation = %{
            type: resource.type,
            amount: resource.amount,
            node: :local,
            allocation_id: generate_allocation_id()
          }

          Map.put(acc, resource.type, allocation)
        else
          acc
        end
      end)

    if map_size(plan_map) == length(resources) do
      {:ok, plan_map}
    else
      {:error, :insufficient_resources}
    end
  end

  defp balance_weighted(load_balancer, available_resources, resources) do
    # Use node weights for balancing
    # Simplified
    balance_round_robin(load_balancer, available_resources, resources)
  end

  defp balance_least_loaded(load_balancer, available_resources, resources) do
    # Allocate to least loaded nodes
    # Simplified
    balance_round_robin(load_balancer, available_resources, resources)
  end

  defp optimize_allocation(state, resources) do
    # Use optimization algorithms (genetic algorithm, simulated annealing, etc.)
    # For now, use a greedy approach
    optimization_result = greedy_optimization(state, resources)

    case optimization_result do
      {:ok, optimized_plan} -> optimized_plan
      {:error, reason} -> {:error, reason}
    end
  end

  defp greedy_optimization(state, resources) do
    # Greedy optimization: allocate resources to minimize total cost
    sorted_resources =
      Enum.sort(resources, fn r1, r2 ->
        cost1 = calculate_resource_cost(r1, state)
        cost2 = calculate_resource_cost(r2, state)
        cost1 <= cost2
      end)

    plan_first_fit(state, sorted_resources)
  end

  defp calculate_resource_cost(resource, state) do
    # Calculate cost of allocating this resource
    utilization = get_resource_utilization(state, resource.type)
    base_cost = resource.amount

    # Higher utilization increases cost
    base_cost * (1 + utilization)
  end

  defp get_resource_utilization(state, resource_type) do
    total = Map.get(state.total_resources, resource_type, 1)
    allocated = Map.get(state.allocated_resources, resource_type, 0)

    if total > 0 do
      allocated / total
    else
      0.0
    end
  end

  defp calculate_utilization(state) do
    Enum.reduce(state.total_resources, %{}, fn {type, total}, acc ->
      allocated = Map.get(state.allocated_resources, type, 0)
      utilization = if total > 0, do: allocated / total, else: 0.0
      Map.put(acc, type, utilization)
    end)
  end

  defp update_allocation_metrics(metrics, allocation_record) do
    new_latency = allocation_record.allocation_latency
    updated_latency_list = [new_latency | Enum.take(metrics.allocation_latency, 99)]

    %{
      metrics
      | total_allocations: metrics.total_allocations + 1,
        allocation_latency: updated_latency_list
    }
  end

  defp update_release_metrics(metrics) do
    %{metrics | total_releases: metrics.total_releases + 1}
  end

  defp generate_allocation_id do
    "alloc_#{System.unique_integer([:positive])}_#{System.monotonic_time(:microsecond)}"
  end
end

defmodule Dspy.DependencyResolver do
  @moduledoc """
  Dependency resolver for managing task dependencies and determining
  execution order based on dependency graphs.
  """

  use GenServer

  defstruct [
    :dependency_graph,
    :waiting_tasks,
    :satisfied_dependencies,
    :resolution_strategy,
    :circular_detection,
    :metrics
  ]

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def check_dependencies(resolver, task) do
    GenServer.call(resolver, {:check_dependencies, task})
  end

  def add_waiting_task(resolver, task) do
    GenServer.call(resolver, {:add_waiting_task, task})
  end

  def task_completed(resolver, task_id) do
    GenServer.cast(resolver, {:task_completed, task_id})
  end

  def get_dependency_status(resolver) do
    GenServer.call(resolver, :get_dependency_status)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      dependency_graph: :digraph.new([:acyclic]),
      waiting_tasks: %{},
      satisfied_dependencies: MapSet.new(),
      resolution_strategy: Keyword.get(opts, :resolution_strategy, :topological),
      circular_detection: Keyword.get(opts, :circular_detection, true),
      metrics: %{
        dependency_checks: 0,
        circular_dependencies_detected: 0,
        tasks_unblocked: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:check_dependencies, task}, _from, state) do
    case check_task_dependencies(state, task) do
      {:satisfied, updated_state} ->
        {:reply, {:ok, :satisfied}, updated_state}

      {:waiting, updated_state} ->
        {:reply, {:ok, :waiting}, updated_state}

      {:error, reason, updated_state} ->
        {:reply, {:error, reason}, updated_state}
    end
  end

  @impl true
  def handle_call({:add_waiting_task, task}, _from, state) do
    updated_waiting = Map.put(state.waiting_tasks, task.id, task)
    add_task_to_graph(state.dependency_graph, task)

    updated_state = %{state | waiting_tasks: updated_waiting}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:get_dependency_status, _from, state) do
    status = %{
      waiting_tasks: map_size(state.waiting_tasks),
      satisfied_dependencies: MapSet.size(state.satisfied_dependencies),
      graph_vertices: length(:digraph.vertices(state.dependency_graph)),
      graph_edges: length(:digraph.edges(state.dependency_graph)),
      metrics: state.metrics
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:task_completed, task_id}, state) do
    # Mark dependency as satisfied
    updated_satisfied = MapSet.put(state.satisfied_dependencies, task_id)

    # Check if any waiting tasks can now proceed
    {ready_tasks, updated_waiting} = find_ready_tasks(state.waiting_tasks, updated_satisfied)

    # Notify scheduler about ready tasks
    Enum.each(ready_tasks, fn _task ->
      # Send to scheduler (would need scheduler reference)
      # send(scheduler_pid, {:dependencies_satisfied, task})
      :ok
    end)

    updated_metrics = %{
      state.metrics
      | tasks_unblocked: state.metrics.tasks_unblocked + length(ready_tasks)
    }

    updated_state = %{
      state
      | satisfied_dependencies: updated_satisfied,
        waiting_tasks: updated_waiting,
        metrics: updated_metrics
    }

    {:noreply, updated_state}
  end

  defp check_task_dependencies(state, task) do
    dependencies = task.dependencies

    # Update metrics
    updated_metrics = %{state.metrics | dependency_checks: state.metrics.dependency_checks + 1}
    updated_state = %{state | metrics: updated_metrics}

    # Check for circular dependencies if enabled
    if state.circular_detection do
      case detect_circular_dependencies(state.dependency_graph, task) do
        {:circular, cycle} ->
          updated_circular_metrics = %{
            updated_metrics
            | circular_dependencies_detected: updated_metrics.circular_dependencies_detected + 1
          }

          {:error, {:circular_dependency, cycle},
           %{updated_state | metrics: updated_circular_metrics}}

        :ok ->
          check_dependency_satisfaction(updated_state, task, dependencies)
      end
    else
      check_dependency_satisfaction(updated_state, task, dependencies)
    end
  end

  defp check_dependency_satisfaction(state, _task, dependencies) do
    case dependencies do
      [] ->
        # No dependencies, can proceed immediately
        {:satisfied, state}

      deps ->
        satisfied_deps =
          Enum.filter(deps, fn dep_id ->
            MapSet.member?(state.satisfied_dependencies, dep_id)
          end)

        if length(satisfied_deps) == length(deps) do
          {:satisfied, state}
        else
          {:waiting, state}
        end
    end
  end

  defp add_task_to_graph(graph, task) do
    # Add task as vertex
    :digraph.add_vertex(graph, task.id, task)

    # Add dependency edges
    Enum.each(task.dependencies, fn dep_id ->
      # Add dependency vertex if not exists
      case :digraph.vertex(graph, dep_id) do
        false -> :digraph.add_vertex(graph, dep_id, nil)
        _ -> :ok
      end

      # Add edge from dependency to task
      :digraph.add_edge(graph, dep_id, task.id)
    end)
  end

  defp detect_circular_dependencies(graph, task) do
    # Check if adding this task would create a cycle
    temp_graph = :digraph_utils.subgraph(graph, :digraph.vertices(graph))

    # Add task temporarily
    :digraph.add_vertex(temp_graph, task.id, task)

    Enum.each(task.dependencies, fn dep_id ->
      case :digraph.vertex(temp_graph, dep_id) do
        false -> :digraph.add_vertex(temp_graph, dep_id, nil)
        _ -> :ok
      end

      :digraph.add_edge(temp_graph, dep_id, task.id)
    end)

    # Check for cycles
    case :digraph_utils.is_acyclic(temp_graph) do
      true ->
        :digraph.delete(temp_graph)
        :ok

      false ->
        # Find the cycle
        cycle = find_cycle_in_graph(temp_graph)
        :digraph.delete(temp_graph)
        {:circular, cycle}
    end
  end

  defp find_cycle_in_graph(graph) do
    # Find a cycle in the graph (simplified implementation)
    vertices = :digraph.vertices(graph)
    find_cycle_dfs(graph, vertices, MapSet.new(), [])
  end

  defp find_cycle_dfs(_graph, [], _visited, _path), do: []

  defp find_cycle_dfs(graph, [vertex | rest], visited, path) do
    if MapSet.member?(visited, vertex) do
      # Found cycle
      cycle_start_index = Enum.find_index(path, &(&1 == vertex))

      if cycle_start_index do
        Enum.drop(path, cycle_start_index)
      else
        []
      end
    else
      new_visited = MapSet.put(visited, vertex)
      new_path = [vertex | path]

      neighbors = :digraph.out_neighbours(graph, vertex)

      case find_cycle_dfs(graph, neighbors, new_visited, new_path) do
        [] -> find_cycle_dfs(graph, rest, visited, path)
        cycle -> cycle
      end
    end
  end

  defp find_ready_tasks(waiting_tasks, satisfied_dependencies) do
    {ready, still_waiting} =
      Enum.split_with(waiting_tasks, fn {_id, task} ->
        all_dependencies_satisfied?(task.dependencies, satisfied_dependencies)
      end)

    ready_tasks = Enum.map(ready, fn {_id, task} -> task end)
    still_waiting_map = Map.new(still_waiting)

    {ready_tasks, still_waiting_map}
  end

  defp all_dependencies_satisfied?(dependencies, satisfied_dependencies) do
    Enum.all?(dependencies, fn dep_id ->
      MapSet.member?(satisfied_dependencies, dep_id)
    end)
  end
end
