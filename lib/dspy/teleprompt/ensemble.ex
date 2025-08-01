defmodule Dspy.Teleprompt.Ensemble do
  @moduledoc """
  Ensemble teleprompt - Combines multiple programs for improved performance.
  
  Creates an ensemble of programs that can be combined using various strategies:
  - Majority voting for classification
  - Weighted averaging for regression
  - Confidence-based selection
  - Stacking with meta-learner
  
  ## Usage
  
      teleprompt = Dspy.Teleprompt.Ensemble.new(
        size: 5,
        combination_strategy: :majority_vote,
        base_teleprompt: :bootstrap_few_shot
      )
      
      {:ok, ensemble_program} = Dspy.Teleprompt.Ensemble.compile(
        teleprompt, 
        program, 
        trainset
      )
  
  """
  
  @behaviour Dspy.Teleprompt
  
  alias Dspy.{Example, Module, Prediction, Evaluate, Trainset}
  alias Dspy.Teleprompt.{BootstrapFewShot, LabeledFewShot, COPRO}
  
  defstruct [
    :size,                    # Number of ensemble members
    :combination_strategy,    # How to combine predictions
    :base_teleprompt,         # Base teleprompt to use for members
    :base_teleprompt_config,  # Configuration for base teleprompt
    :diversity_strategy,      # How to ensure diversity
    :validation_split,        # Fraction of data for validation
    :num_threads,             # Parallel processing threads
    :seed,                    # Random seed
    :verbose                  # Whether to print progress
  ]
  
  @type combination_strategy :: :majority_vote | :weighted_average | :confidence_based | :stacking
  @type diversity_strategy :: :random_samples | :different_configs | :bootstrap_aggregating
  
  @type t :: %__MODULE__{
    size: pos_integer(),
    combination_strategy: combination_strategy(),
    base_teleprompt: atom(),
    base_teleprompt_config: keyword(),
    diversity_strategy: diversity_strategy(),
    validation_split: float(),
    num_threads: pos_integer(),
    seed: integer(),
    verbose: boolean()
  }
  
  @doc """
  Create a new Ensemble teleprompt.
  
  ## Options
  
  - `:size` - Number of ensemble members (default: 5)
  - `:combination_strategy` - How to combine predictions (default: :majority_vote)
  - `:base_teleprompt` - Base teleprompt type (default: :bootstrap_few_shot)
  - `:base_teleprompt_config` - Config for base teleprompt (default: [])
  - `:diversity_strategy` - How to ensure diversity (default: :random_samples)
  - `:validation_split` - Validation data fraction (default: 0.2)
  - `:num_threads` - Parallel threads (default: auto)
  - `:seed` - Random seed for reproducibility
  - `:verbose` - Print progress (default: true)
  
  """
  @impl Dspy.Teleprompt
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      size: Keyword.get(opts, :size, 5),
      combination_strategy: Keyword.get(opts, :combination_strategy, :majority_vote),
      base_teleprompt: Keyword.get(opts, :base_teleprompt, :bootstrap_few_shot),
      base_teleprompt_config: Keyword.get(opts, :base_teleprompt_config, []),
      diversity_strategy: Keyword.get(opts, :diversity_strategy, :random_samples),
      validation_split: Keyword.get(opts, :validation_split, 0.2),
      num_threads: Keyword.get(opts, :num_threads, System.schedulers_online()),
      seed: Keyword.get(opts, :seed, :os.system_time(:microsecond)),
      verbose: Keyword.get(opts, :verbose, true)
    }
  end
  
  @doc """
  Compile an ensemble of programs.
  
  ## Process
  
  1. Split training data into ensemble training sets
  2. Train multiple programs using base teleprompt
  3. Validate ensemble members
  4. Create ensemble program with combination strategy
  
  """
  @impl Dspy.Teleprompt
  @spec compile(t(), module(), list(Example.t())) :: {:ok, module()} | {:error, term()}
  def compile(%__MODULE__{} = teleprompt, program, trainset) do
    if teleprompt.verbose do
      IO.puts("Starting Ensemble compilation with #{teleprompt.size} members...")
    end
    
    with {:ok, validated_trainset} <- validate_trainset(trainset),
         {:ok, {train_data, val_data}} <- split_data(teleprompt, validated_trainset),
         {:ok, ensemble_members} <- train_ensemble_members(teleprompt, program, train_data),
         {:ok, member_weights} <- calculate_member_weights(teleprompt, ensemble_members, val_data),
         {:ok, ensemble_program} <- create_ensemble_program(teleprompt, ensemble_members, member_weights) do
      
      if teleprompt.verbose do
        IO.puts("Ensemble compilation completed successfully")
      end
      
      {:ok, ensemble_program}
    end
  end
  
  # Private functions
  
  defp validate_trainset(trainset) do
    if length(trainset) < 10 do
      {:error, "Insufficient training data for ensemble (need at least 10 examples)"}
    else
      {:ok, trainset}
    end
  end
  
  defp split_data(%__MODULE__{validation_split: val_split, seed: seed}, trainset) do
    :rand.seed(:exsss, {seed, seed + 1, seed + 2})
    
    {train_data, val_data, _} = Trainset.split(trainset, 
      train: 1.0 - val_split, 
      val: val_split, 
      test: 0.0,
      shuffle: true,
      seed: seed
    )
    
    {:ok, {train_data, val_data}}
  end
  
  defp train_ensemble_members(%__MODULE__{} = teleprompt, program, train_data) do
    %{
      size: size,
      base_teleprompt: base_type,
      base_teleprompt_config: base_config,
      diversity_strategy: diversity_strategy,
      num_threads: num_threads,
      verbose: verbose,
      seed: seed
    } = teleprompt
    
    if verbose do
      IO.puts("Training #{size} ensemble members...")
    end
    
    # Generate diverse training configurations
    training_configs = generate_diverse_configurations(diversity_strategy, size, train_data, base_config, seed)
    
    # Train ensemble members in parallel
    members = training_configs
    |> Enum.with_index(1)
    |> Task.async_stream(fn {config, idx} ->
      if verbose do
        IO.puts("  Training member #{idx}/#{size}")
      end
      
      train_single_member(base_type, program, config)
    end, max_concurrency: num_threads, timeout: 300_000)
    |> Enum.map(fn {:ok, result} -> result end)
    |> Enum.filter(fn
      {:ok, _member} -> true
      {:error, _reason} -> false
    end)
    |> Enum.map(fn {:ok, member} -> member end)
    
    if length(members) < 2 do
      {:error, "Failed to train sufficient ensemble members"}
    else
      {:ok, members}
    end
  end
  
  defp generate_diverse_configurations(strategy, size, train_data, base_config, seed) do
    :rand.seed(:exsss, {seed + 100, seed + 101, seed + 102})
    
    case strategy do
      :random_samples ->
        # Each member gets a different random sample of training data
        for i <- 1..size do
          sampled_data = Trainset.bootstrap_sample(train_data, length(train_data), seed: seed + i)
          {sampled_data, Keyword.put(base_config, :seed, seed + i)}
        end
        
      :different_configs ->
        # Each member gets different hyperparameters
        for i <- 1..size do
          varied_config = vary_config(base_config, i, seed)
          {train_data, varied_config}
        end
        
      :bootstrap_aggregating ->
        # Bootstrap aggregating (bagging)
        for i <- 1..size do
          bootstrap_size = round(length(train_data) * (0.8 + :rand.uniform() * 0.4))
          sampled_data = Trainset.bootstrap_sample(train_data, bootstrap_size, seed: seed + i)
          {sampled_data, Keyword.put(base_config, :seed, seed + i)}
        end
    end
  end
  
  defp vary_config(base_config, member_idx, seed) do
    :rand.seed(:exsss, {seed + member_idx, seed + member_idx + 1, seed + member_idx + 2})
    
    # Vary configuration parameters
    base_config
    |> Keyword.put(:seed, seed + member_idx)
    |> vary_parameter(:max_bootstrapped_demos, [2, 3, 4, 5, 6])
    |> vary_parameter(:max_labeled_demos, [2, 3, 4, 5, 6])
    |> vary_parameter(:num_trials, [5, 8, 10, 12, 15])
    |> vary_parameter(:temperature, [0.5, 0.7, 1.0, 1.2, 1.5])
  end
  
  defp vary_parameter(config, param, values) do
    if Keyword.has_key?(config, param) do
      new_value = Enum.random(values)
      Keyword.put(config, param, new_value)
    else
      config
    end
  end
  
  defp train_single_member(base_type, program, {training_data, config}) do
    try do
      # Create base teleprompt instance
      base_teleprompt = case base_type do
        :bootstrap_few_shot -> BootstrapFewShot.new(config)
        :labeled_few_shot -> LabeledFewShot.new(config)
        :copro -> COPRO.new(config)
        _ -> BootstrapFewShot.new(config)  # fallback
      end
      
      # Train the member
      case Dspy.Teleprompt.compile(base_teleprompt, program, training_data) do
        {:ok, trained_program} -> {:ok, trained_program}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
  
  defp calculate_member_weights(%__MODULE__{combination_strategy: strategy} = teleprompt, members, val_data) do
    case strategy do
      :majority_vote ->
        # Equal weights for majority voting
        weights = members |> Enum.map(fn _ -> 1.0 end)
        {:ok, weights}
        
      :weighted_average ->
        # Weights based on validation performance
        calculate_performance_weights(teleprompt, members, val_data)
        
      :confidence_based ->
        # Weights will be calculated dynamically based on confidence
        weights = members |> Enum.map(fn _ -> 1.0 end)
        {:ok, weights}
        
      :stacking ->
        # Train meta-learner (simplified implementation)
        calculate_stacking_weights(teleprompt, members, val_data)
    end
  end
  
  defp calculate_performance_weights(%__MODULE__{base_teleprompt_config: config}, members, val_data) do
    # Get metric from base config or use default
    metric = Keyword.get(config, :metric, &Dspy.Metrics.exact_match/2)
    
    # Evaluate each member on validation data
    performances = members
    |> Task.async_stream(fn member ->
      result = Evaluate.evaluate(member, val_data, metric, progress: false)
      result.mean
    end, timeout: 30_000)
    |> Enum.map(fn {:ok, perf} -> perf end)
    
    # Convert to weights (softmax)
    total_exp = performances |> Enum.map(&:math.exp/1) |> Enum.sum()
    weights = performances |> Enum.map(fn perf -> :math.exp(perf) / total_exp end)
    
    {:ok, weights}
  end
  
  defp calculate_stacking_weights(_teleprompt, members, _val_data) do
    # Simplified stacking - equal weights for now
    # In practice, would train a meta-learner
    weights = members |> Enum.map(fn _ -> 1.0 / length(members) end)
    {:ok, weights}
  end
  
  defp create_ensemble_program(%__MODULE__{} = teleprompt, members, weights) do
    {:module, ensemble_program, _binary, _exports} = defmodule EnsembleProgram do
      @behaviour Dspy.Module
      
      @members members
      @weights weights
      @strategy teleprompt.combination_strategy
      @size length(members)
      
      def __members__, do: @members
      def __weights__, do: @weights
      def __strategy__, do: @strategy
      def __size__, do: @size
      
      @impl Dspy.Module
      def forward(input) do
        members = __members__()
        weights = __weights__()
        strategy = __strategy__()
        
        # Get predictions from all members
        member_predictions = members
        |> Task.async_stream(fn member ->
          Module.forward(member, input)
        end, timeout: 30_000)
        |> Enum.map(fn
          {:ok, {:ok, prediction}} -> prediction
          _ -> nil
        end)
        |> Enum.filter(&(&1 != nil))
        
        if length(member_predictions) == 0 do
          {:error, "All ensemble members failed"}
        else
          # Combine predictions using strategy
          combined_prediction = combine_predictions(member_predictions, weights, strategy)
          {:ok, combined_prediction}
        end
      end
      
      @impl Dspy.Module
      def parameters do
        %{
          ensemble_size: __size__(),
          combination_strategy: __strategy__(),
          member_weights: __weights__(),
          ensemble_type: "Ensemble"
        }
      end
      
      defp combine_predictions(predictions, weights, strategy) do
        case strategy do
          :majority_vote ->
            majority_vote_combination(predictions)
            
          :weighted_average ->
            weighted_average_combination(predictions, weights)
            
          :confidence_based ->
            confidence_based_combination(predictions)
            
          :stacking ->
            stacking_combination(predictions, weights)
        end
      end
      
      defp majority_vote_combination(predictions) do
        # Simple majority vote for each output field
        all_attrs = predictions |> Enum.map(& &1.attrs) |> Enum.reduce(%{}, &Map.merge/2)
        
        voted_attrs = all_attrs
        |> Enum.map(fn {field, _} ->
          values = predictions |> Enum.map(&Map.get(&1.attrs, field)) |> Enum.filter(&(&1 != nil))
          most_common = values |> Enum.frequencies() |> Enum.max_by(&elem(&1, 1)) |> elem(0)
          {field, most_common}
        end)
        |> Map.new()
        
        Dspy.Prediction.new(voted_attrs)
      end
      
      defp weighted_average_combination(predictions, weights) do
        # Weighted combination for numeric values, majority vote for others
        all_attrs = predictions |> Enum.map(& &1.attrs) |> Enum.reduce(%{}, &Map.merge/2)
        
        combined_attrs = all_attrs
        |> Enum.map(fn {field, _} ->
          values = predictions 
          |> Enum.zip(weights)
          |> Enum.map(fn {pred, weight} -> {Map.get(pred.attrs, field), weight} end)
          |> Enum.filter(fn {val, _} -> val != nil end)
          
          combined_value = if length(values) > 0 do
            case hd(values) |> elem(0) do
              val when is_number(val) ->
                # Weighted average for numbers
                weighted_sum = values |> Enum.map(fn {v, w} -> v * w end) |> Enum.sum()
                total_weight = values |> Enum.map(&elem(&1, 1)) |> Enum.sum()
                if total_weight > 0, do: weighted_sum / total_weight, else: val
                
              _ ->
                # Majority vote for non-numeric
                values |> Enum.map(&elem(&1, 0)) |> Enum.frequencies() |> Enum.max_by(&elem(&1, 1)) |> elem(0)
            end
          else
            nil
          end
          
          {field, combined_value}
        end)
        |> Enum.filter(fn {_, val} -> val != nil end)
        |> Map.new()
        
        Dspy.Prediction.new(combined_attrs)
      end
      
      defp confidence_based_combination(predictions) do
        # Select prediction with highest confidence
        best_prediction = predictions
        |> Enum.max_by(fn pred ->
          Map.get(pred.attrs, :confidence, 0.5)
        end)
        
        best_prediction
      end
      
      defp stacking_combination(predictions, weights) do
        # Simplified stacking - weighted combination
        weighted_average_combination(predictions, weights)
      end
    end
    
    {:ok, ensemble_program}
  end
end