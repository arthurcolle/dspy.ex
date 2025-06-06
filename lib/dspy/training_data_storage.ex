defmodule Dspy.TrainingDataStorage do
  @moduledoc """
  Training data storage system for novel AI system experiments.

  This module captures, stores, and manages all attempts at novel system generation,
  creating a comprehensive training dataset that can be used for:
  - Learning successful pattern combinations
  - Understanding failure modes
  - Improving system generation strategies
  - Building meta-learning capabilities
  """

  use GenServer

  defstruct [
    :storage_backend,
    :data_directory,
    :max_storage_size,
    :compression_enabled,
    :indexing_strategy,
    :retention_policy,
    experiments: %{},
    patterns: %{},
    statistics: %{}
  ]

  @type experiment_data :: %{
          experiment_id: String.t(),
          timestamp: DateTime.t(),
          inputs: map(),
          generated_blueprints: [map()],
          selected_system: String.t(),
          result: map(),
          success: boolean(),
          execution_time: non_neg_integer(),
          resource_usage: map(),
          failure_reason: String.t() | nil
        }

  @type pattern_data :: %{
          pattern_id: String.t(),
          components: [atom()],
          connections: [tuple()],
          success_rate: float(),
          average_performance: float(),
          usage_count: non_neg_integer(),
          last_used: DateTime.t(),
          effective_domains: [String.t()],
          failure_modes: [String.t()]
        }

  @type storage_statistics :: %{
          total_experiments: non_neg_integer(),
          successful_experiments: non_neg_integer(),
          novel_patterns_discovered: non_neg_integer(),
          average_novelty_score: float(),
          storage_size_mb: float(),
          last_cleanup: DateTime.t()
        }

  @type t :: %__MODULE__{
          storage_backend: atom(),
          data_directory: String.t(),
          max_storage_size: non_neg_integer(),
          compression_enabled: boolean(),
          indexing_strategy: atom(),
          retention_policy: map(),
          experiments: %{String.t() => experiment_data()},
          patterns: %{String.t() => pattern_data()},
          statistics: storage_statistics()
        }

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store experiment data from a novel system generation attempt.
  """
  def store_experiment(experiment_data) do
    GenServer.call(__MODULE__, {:store_experiment, experiment_data})
  end

  @doc """
  Retrieve experiment data by ID.
  """
  def get_experiment(experiment_id) do
    GenServer.call(__MODULE__, {:get_experiment, experiment_id})
  end

  @doc """
  Get all experiments matching the given criteria.
  """
  def query_experiments(criteria \\ %{}) do
    GenServer.call(__MODULE__, {:query_experiments, criteria})
  end

  @doc """
  Get pattern analysis for successful combinations.
  """
  def get_pattern_analysis(pattern_type \\ :all) do
    GenServer.call(__MODULE__, {:get_pattern_analysis, pattern_type})
  end

  @doc """
  Get storage statistics and insights.
  """
  def get_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  @doc """
  Export training data in various formats.
  """
  def export_training_data(format \\ :json, filter_criteria \\ %{}) do
    GenServer.call(__MODULE__, {:export_training_data, format, filter_criteria})
  end

  @doc """
  Get recommendations for novel system generation based on historical data.
  """
  def get_recommendations(problem_characteristics) do
    GenServer.call(__MODULE__, {:get_recommendations, problem_characteristics})
  end

  @doc """
  Clean up old data according to retention policy.
  """
  def cleanup_old_data do
    GenServer.call(__MODULE__, :cleanup_old_data)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      storage_backend: Keyword.get(opts, :storage_backend, :memory),
      data_directory: Keyword.get(opts, :data_directory, "./training_data"),
      # 1GB
      max_storage_size: Keyword.get(opts, :max_storage_size, 1_000_000_000),
      compression_enabled: Keyword.get(opts, :compression_enabled, true),
      indexing_strategy: Keyword.get(opts, :indexing_strategy, :hash_based),
      retention_policy: Keyword.get(opts, :retention_policy, default_retention_policy()),
      experiments: %{},
      patterns: %{},
      statistics: initial_statistics()
    }

    # Ensure data directory exists
    File.mkdir_p!(state.data_directory)

    # Load existing data if using persistent storage
    state =
      if state.storage_backend != :memory do
        load_persistent_data(state)
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_call({:store_experiment, experiment_data}, _from, state) do
    # Enrich experiment data with additional metadata
    enriched_data = enrich_experiment_data(experiment_data, state)

    # Store the experiment
    updated_state =
      state
      |> store_experiment_data(enriched_data)
      |> update_pattern_analysis(enriched_data)
      |> update_statistics(enriched_data)
      |> maybe_persist_data()
      |> maybe_cleanup_storage()

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:get_experiment, experiment_id}, _from, state) do
    experiment = Map.get(state.experiments, experiment_id)
    {:reply, experiment, state}
  end

  @impl true
  def handle_call({:query_experiments, criteria}, _from, state) do
    results = query_experiments_internal(state.experiments, criteria)
    {:reply, results, state}
  end

  @impl true
  def handle_call({:get_pattern_analysis, pattern_type}, _from, state) do
    analysis = analyze_patterns(state.patterns, pattern_type)
    {:reply, analysis, state}
  end

  @impl true
  def handle_call(:get_statistics, _from, state) do
    {:reply, state.statistics, state}
  end

  @impl true
  def handle_call({:export_training_data, format, filter_criteria}, _from, state) do
    filtered_data = query_experiments_internal(state.experiments, filter_criteria)
    exported_data = export_data_in_format(filtered_data, format, state)
    {:reply, exported_data, state}
  end

  @impl true
  def handle_call({:get_recommendations, problem_characteristics}, _from, state) do
    recommendations = generate_recommendations(problem_characteristics, state)
    {:reply, recommendations, state}
  end

  @impl true
  def handle_call(:cleanup_old_data, _from, state) do
    cleaned_state = perform_cleanup(state)
    {:reply, :ok, cleaned_state}
  end

  # Internal functions

  defp enrich_experiment_data(experiment_data, state) do
    experiment_data
    |> Map.put(:storage_timestamp, DateTime.utc_now())
    |> Map.put(:execution_time, calculate_execution_time(experiment_data))
    |> Map.put(:resource_usage, estimate_resource_usage(experiment_data))
    |> Map.put(:novelty_assessment, assess_novelty(experiment_data, state))
    |> Map.put(:similarity_to_previous, find_similar_experiments(experiment_data, state))
  end

  defp store_experiment_data(state, experiment_data) do
    experiment_id = experiment_data.experiment_id
    updated_experiments = Map.put(state.experiments, experiment_id, experiment_data)
    %{state | experiments: updated_experiments}
  end

  defp update_pattern_analysis(state, experiment_data) do
    # Extract patterns from the experiment
    patterns = extract_patterns_from_experiment(experiment_data)

    updated_patterns =
      Enum.reduce(patterns, state.patterns, fn pattern, acc ->
        update_pattern_statistics(acc, pattern, experiment_data)
      end)

    %{state | patterns: updated_patterns}
  end

  defp extract_patterns_from_experiment(experiment_data) do
    experiment_data.generated_blueprints
    |> Enum.map(fn blueprint ->
      %{
        pattern_id: generate_pattern_id(blueprint),
        components: blueprint.components,
        connections: blueprint.connections,
        generation_strategy: blueprint.generation_strategy,
        was_selected: blueprint.name == experiment_data.selected_system,
        success: experiment_data.success
      }
    end)
  end

  defp update_pattern_statistics(patterns, pattern, experiment_data) do
    pattern_id = pattern.pattern_id

    existing_pattern =
      Map.get(patterns, pattern_id, %{
        pattern_id: pattern_id,
        components: pattern.components,
        connections: pattern.connections,
        success_rate: 0.0,
        average_performance: 0.0,
        usage_count: 0,
        last_used: DateTime.utc_now(),
        effective_domains: [],
        failure_modes: []
      })

    # Update statistics
    new_usage_count = existing_pattern.usage_count + 1
    success_increment = if pattern.success, do: 1, else: 0

    new_success_rate =
      (existing_pattern.success_rate * existing_pattern.usage_count + success_increment) /
        new_usage_count

    # Update performance based on confidence or other metrics
    performance = extract_performance_metric(experiment_data)

    new_avg_performance =
      (existing_pattern.average_performance * existing_pattern.usage_count + performance) /
        new_usage_count

    # Update domain information
    domain = extract_domain_info(experiment_data)

    new_effective_domains =
      if pattern.success do
        Enum.uniq([domain | existing_pattern.effective_domains])
      else
        existing_pattern.effective_domains
      end

    # Update failure modes if applicable
    new_failure_modes =
      if not pattern.success do
        failure_mode = extract_failure_mode(experiment_data)
        Enum.uniq([failure_mode | existing_pattern.failure_modes])
      else
        existing_pattern.failure_modes
      end

    updated_pattern = %{
      existing_pattern
      | success_rate: new_success_rate,
        average_performance: new_avg_performance,
        usage_count: new_usage_count,
        last_used: DateTime.utc_now(),
        effective_domains: new_effective_domains,
        failure_modes: new_failure_modes
    }

    Map.put(patterns, pattern_id, updated_pattern)
  end

  defp update_statistics(state, experiment_data) do
    stats = state.statistics

    new_total = stats.total_experiments + 1

    new_successful =
      if experiment_data.success do
        stats.successful_experiments + 1
      else
        stats.successful_experiments
      end

    # Update average novelty score
    experiment_novelty = extract_novelty_score(experiment_data)

    new_avg_novelty =
      (stats.average_novelty_score * stats.total_experiments + experiment_novelty) / new_total

    # Count novel patterns discovered
    new_patterns_discovered = count_new_patterns(experiment_data, state.patterns)
    new_novel_patterns = stats.novel_patterns_discovered + new_patterns_discovered

    updated_stats = %{
      stats
      | total_experiments: new_total,
        successful_experiments: new_successful,
        novel_patterns_discovered: new_novel_patterns,
        average_novelty_score: new_avg_novelty,
        storage_size_mb: calculate_storage_size(state)
    }

    %{state | statistics: updated_stats}
  end

  defp query_experiments_internal(experiments, criteria) do
    experiments
    |> Map.values()
    |> Enum.filter(fn experiment ->
      matches_criteria?(experiment, criteria)
    end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
  end

  defp matches_criteria?(experiment, criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :success ->
          experiment.success == value

        :min_novelty ->
          extract_novelty_score(experiment) >= value

        :domain ->
          extract_domain_info(experiment) == value

        :generation_strategy ->
          Enum.any?(experiment.generated_blueprints, fn bp -> bp.generation_strategy == value end)

        :after_date ->
          DateTime.compare(experiment.timestamp, value) != :lt

        :before_date ->
          DateTime.compare(experiment.timestamp, value) != :gt

        _ ->
          true
      end
    end)
  end

  defp analyze_patterns(patterns, pattern_type) do
    filtered_patterns =
      case pattern_type do
        :all -> Map.values(patterns)
        :successful -> Map.values(patterns) |> Enum.filter(&(&1.success_rate > 0.5))
        :novel -> Map.values(patterns) |> Enum.filter(&(length(&1.components) > 2))
        :recent -> Map.values(patterns) |> Enum.filter(&recent_pattern?/1)
        _ -> Map.values(patterns)
      end

    %{
      total_patterns: length(filtered_patterns),
      top_performing: Enum.take(Enum.sort_by(filtered_patterns, & &1.success_rate, :desc), 10),
      most_used: Enum.take(Enum.sort_by(filtered_patterns, & &1.usage_count, :desc), 10),
      domain_distribution: analyze_domain_distribution(filtered_patterns),
      component_frequency: analyze_component_frequency(filtered_patterns),
      success_factors: identify_success_factors(filtered_patterns)
    }
  end

  defp generate_recommendations(problem_characteristics, state) do
    # Find similar past problems
    similar_experiments = find_similar_problems(problem_characteristics, state.experiments)

    # Analyze successful patterns for similar problems
    successful_patterns =
      similar_experiments
      |> Enum.filter(& &1.success)
      |> Enum.flat_map(&extract_patterns_from_experiment(&1))
      |> Enum.filter(& &1.success)

    # Get top-performing patterns
    top_patterns =
      state.patterns
      |> Map.values()
      |> Enum.filter(&(&1.success_rate > 0.6))
      |> Enum.sort_by(& &1.average_performance, :desc)
      |> Enum.take(5)

    # Generate recommendations
    %{
      recommended_strategies: extract_recommended_strategies(successful_patterns),
      recommended_components: extract_recommended_components(top_patterns),
      estimated_success_probability: estimate_success_probability(problem_characteristics, state),
      similar_past_problems: Enum.take(similar_experiments, 3),
      risk_factors: identify_risk_factors(problem_characteristics, state)
    }
  end

  # Helper functions

  defp default_retention_policy do
    %{
      max_age_days: 365,
      max_experiments: 10000,
      preserve_successful: true,
      preserve_novel: true
    }
  end

  defp initial_statistics do
    %{
      total_experiments: 0,
      successful_experiments: 0,
      novel_patterns_discovered: 0,
      average_novelty_score: 0.0,
      storage_size_mb: 0.0,
      last_cleanup: DateTime.utc_now()
    }
  end

  defp calculate_execution_time(experiment_data) do
    # Extract or estimate execution time
    Map.get(experiment_data, :execution_time, 1000)
  end

  defp estimate_resource_usage(experiment_data) do
    # Estimate based on experiment complexity
    blueprint_count = length(experiment_data.generated_blueprints)

    %{
      memory_mb: blueprint_count * 10,
      cpu_time_ms: blueprint_count * 500,
      io_operations: blueprint_count * 20
    }
  end

  defp assess_novelty(experiment_data, state) do
    # Compare against existing patterns to assess novelty
    existing_blueprints =
      state.experiments
      |> Map.values()
      |> Enum.flat_map(& &1.generated_blueprints)

    experiment_blueprints = experiment_data.generated_blueprints

    avg_novelty =
      experiment_blueprints
      |> Enum.map(fn blueprint ->
        calculate_blueprint_novelty(blueprint, existing_blueprints)
      end)
      |> Enum.sum()
      |> Kernel./(max(1, length(experiment_blueprints)))

    %{
      average_novelty: avg_novelty,
      novel_blueprint_count: Enum.count(experiment_blueprints, &(&1.novelty_score > 0.7)),
      most_novel_component: find_most_novel_component(experiment_blueprints)
    }
  end

  defp find_similar_experiments(experiment_data, state) do
    state.experiments
    |> Map.values()
    |> Enum.map(fn exp ->
      similarity = calculate_experiment_similarity(experiment_data, exp)
      {exp.experiment_id, similarity}
    end)
    |> Enum.filter(fn {_id, similarity} -> similarity > 0.6 end)
    |> Enum.sort_by(fn {_id, similarity} -> similarity end, :desc)
    |> Enum.take(5)
  end

  defp generate_pattern_id(blueprint) do
    components_str = Enum.join(Enum.sort(blueprint.components), "_")
    strategy_str = Atom.to_string(blueprint.generation_strategy)
    "#{strategy_str}_#{components_str}"
  end

  defp extract_performance_metric(experiment_data) do
    Map.get(experiment_data.result, :confidence, 0.5)
  end

  defp extract_domain_info(experiment_data) do
    # Extract domain from inputs or result
    Map.get(experiment_data.inputs, :domain, "general")
  end

  defp extract_failure_mode(experiment_data) do
    Map.get(experiment_data, :failure_reason, "unknown")
  end

  defp extract_novelty_score(experiment_data) do
    blueprints = experiment_data.generated_blueprints

    if length(blueprints) > 0 do
      Enum.sum(Enum.map(blueprints, & &1.novelty_score)) / length(blueprints)
    else
      0.0
    end
  end

  defp count_new_patterns(experiment_data, existing_patterns) do
    experiment_patterns = extract_patterns_from_experiment(experiment_data)

    Enum.count(experiment_patterns, fn pattern ->
      not Map.has_key?(existing_patterns, pattern.pattern_id)
    end)
  end

  defp calculate_storage_size(state) do
    # Estimate storage size in MB
    experiment_count = map_size(state.experiments)
    pattern_count = map_size(state.patterns)

    # Rough estimates
    experiment_count * 0.1 + pattern_count * 0.05
  end

  defp recent_pattern?(pattern) do
    days_ago = DateTime.diff(DateTime.utc_now(), pattern.last_used, :day)
    days_ago <= 30
  end

  defp analyze_domain_distribution(patterns) do
    patterns
    |> Enum.flat_map(& &1.effective_domains)
    |> Enum.frequencies()
  end

  defp analyze_component_frequency(patterns) do
    patterns
    |> Enum.flat_map(& &1.components)
    |> Enum.frequencies()
  end

  defp identify_success_factors(patterns) do
    successful_patterns = Enum.filter(patterns, &(&1.success_rate > 0.7))

    %{
      common_components: analyze_component_frequency(successful_patterns),
      optimal_component_count: calculate_optimal_component_count(successful_patterns),
      effective_strategies: extract_effective_strategies(successful_patterns)
    }
  end

  defp calculate_blueprint_novelty(_blueprint, _existing_blueprints) do
    # Simplified novelty calculation
    # Placeholder
    :rand.uniform()
  end

  defp find_most_novel_component(blueprints) do
    blueprints
    |> Enum.max_by(& &1.novelty_score, fn -> %{components: []} end)
    |> Map.get(:components, [])
    |> List.first()
  end

  defp calculate_experiment_similarity(_exp1, _exp2) do
    # Simplified similarity calculation
    # Placeholder
    :rand.uniform()
  end

  defp find_similar_problems(_characteristics, experiments) do
    # Simplified: return recent successful experiments
    experiments
    |> Map.values()
    |> Enum.filter(& &1.success)
    |> Enum.take(5)
  end

  defp extract_recommended_strategies(patterns) do
    patterns
    |> Enum.map(& &1.generation_strategy)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_strategy, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {strategy, _count} -> strategy end)
  end

  defp extract_recommended_components(patterns) do
    patterns
    |> Enum.flat_map(& &1.components)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_component, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {component, _count} -> component end)
  end

  defp estimate_success_probability(_characteristics, state) do
    if state.statistics.total_experiments > 0 do
      state.statistics.successful_experiments / state.statistics.total_experiments
    else
      0.5
    end
  end

  defp identify_risk_factors(_characteristics, _state) do
    ["Untested component combination", "High novelty requirement", "Complex domain"]
  end

  defp calculate_optimal_component_count(patterns) do
    if length(patterns) > 0 do
      patterns
      |> Enum.map(&length(&1.components))
      |> Enum.sum()
      |> Kernel./(length(patterns))
      |> Float.round(1)
    else
      2.0
    end
  end

  defp extract_effective_strategies(_patterns) do
    # This would be extracted from pattern metadata if available
    [:hybrid_combination, :pattern_evolution]
  end

  defp load_persistent_data(state) do
    # Load data from persistent storage
    # For now, return the state as-is
    state
  end

  defp maybe_persist_data(state) do
    # Persist data if using persistent storage
    state
  end

  defp maybe_cleanup_storage(state) do
    # Check if cleanup is needed based on storage size or retention policy
    if should_cleanup?(state) do
      perform_cleanup(state)
    else
      state
    end
  end

  defp should_cleanup?(state) do
    state.statistics.storage_size_mb > state.max_storage_size / 1_000_000 * 0.9
  end

  defp perform_cleanup(state) do
    # Remove old experiments based on retention policy
    retention_cutoff =
      DateTime.add(DateTime.utc_now(), -state.retention_policy.max_age_days, :day)

    filtered_experiments =
      state.experiments
      |> Enum.filter(fn {_id, exp} ->
        keep_experiment?(exp, retention_cutoff, state.retention_policy)
      end)
      |> Map.new()

    # Update statistics
    updated_stats = %{
      state.statistics
      | last_cleanup: DateTime.utc_now(),
        storage_size_mb: calculate_storage_size(%{state | experiments: filtered_experiments})
    }

    %{state | experiments: filtered_experiments, statistics: updated_stats}
  end

  defp keep_experiment?(experiment, cutoff, policy) do
    # Keep if within time limit
    recent = DateTime.compare(experiment.timestamp, cutoff) != :lt

    # Keep if successful and policy preserves successful
    preserve_successful = policy.preserve_successful and experiment.success

    # Keep if novel and policy preserves novel
    preserve_novel = policy.preserve_novel and extract_novelty_score(experiment) > 0.7

    recent or preserve_successful or preserve_novel
  end

  defp export_data_in_format(data, :json, _state) do
    Jason.encode!(data)
  end

  defp export_data_in_format(data, :csv, _state) do
    # Convert to CSV format
    headers = ["experiment_id", "timestamp", "success", "novelty_score", "selected_system"]

    rows =
      data
      |> Enum.map(fn exp ->
        [
          exp.experiment_id,
          DateTime.to_iso8601(exp.timestamp),
          exp.success,
          extract_novelty_score(exp),
          exp.selected_system
        ]
      end)

    csv_data = [headers | rows]

    csv_data
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp export_data_in_format(data, _format, _state) do
    # Default to Elixir term format
    inspect(data, pretty: true)
  end
end
