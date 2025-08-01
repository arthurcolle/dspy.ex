defmodule Dspy.Trainset do
  @moduledoc """
  Training set management and utilities for DSPy teleprompts.
  
  Provides functionality for:
  - Training set validation and preprocessing
  - Data splitting (train/validation/test)
  - Example sampling and selection
  - Data augmentation and transformation
  - Bootstrap sampling for few-shot learning
  
  ## Usage
  
      # Validate training set
      {:ok, validated} = Dspy.Trainset.validate(trainset)
      
      # Split data
      {train, val, test} = Dspy.Trainset.split(dataset, train: 0.7, val: 0.15, test: 0.15)
      
      # Sample examples
      samples = Dspy.Trainset.sample(trainset, 5, strategy: :diverse)
  
  """
  
  alias Dspy.{Example, Signature}
  
  @type split_options :: [
    train: float(),
    val: float(), 
    test: float(),
    shuffle: boolean(),
    seed: integer()
  ]
  
  @type sampling_strategy :: :random | :diverse | :hard | :balanced | :uncertainty
  
  @doc """
  Validate a training set for compatibility with DSPy.
  
  ## Parameters
  
  - `trainset` - List of examples to validate
  - `signature` - Optional signature to validate against
  
  ## Returns
  
  `{:ok, validated_trainset}` or `{:error, reason}`
  
  """
  @spec validate(list(Example.t()), Signature.t() | nil) :: {:ok, list(Example.t())} | {:error, String.t()}
  def validate(trainset, signature \\ nil) do
    with :ok <- validate_basic_structure(trainset),
         :ok <- validate_signature_compatibility(trainset, signature) do
      
      # Clean and normalize examples
      validated = trainset
      |> Enum.map(&normalize_example/1)
      |> Enum.reject(&is_nil/1)
      
      if length(validated) > 0 do
        {:ok, validated}
      else
        {:error, "No valid examples found after validation"}
      end
    end
  end
  
  @doc """
  Split a dataset into train/validation/test sets.
  
  ## Parameters
  
  - `dataset` - Full dataset to split
  - `opts` - Split options (train/val/test ratios, shuffle, seed)
  
  ## Returns
  
  `{train_set, val_set, test_set}` tuple
  
  ## Examples
  
      {train, val, test} = Dspy.Trainset.split(data, train: 0.8, val: 0.1, test: 0.1)
  
  """
  @spec split(list(Example.t()), split_options()) :: {list(Example.t()), list(Example.t()), list(Example.t())}
  def split(dataset, opts \\ []) do
    train_ratio = Keyword.get(opts, :train, 0.8)
    val_ratio = Keyword.get(opts, :val, 0.1)
    test_ratio = Keyword.get(opts, :test, 0.1)
    shuffle = Keyword.get(opts, :shuffle, true)
    seed = Keyword.get(opts, :seed, :os.system_time(:microsecond))
    
    # Validate ratios
    total_ratio = train_ratio + val_ratio + test_ratio
    unless abs(total_ratio - 1.0) < 0.001 do
      raise ArgumentError, "Split ratios must sum to 1.0, got #{total_ratio}"
    end
    
    # Shuffle if requested
    shuffled = if shuffle do
      :rand.seed(:exsss, {seed, seed + 1, seed + 2})
      Enum.shuffle(dataset)
    else
      dataset
    end
    
    # Calculate split indices
    total_size = length(shuffled)
    train_size = round(total_size * train_ratio)
    val_size = round(total_size * val_ratio)
    
    # Split the data
    {train_set, remainder} = Enum.split(shuffled, train_size)
    {val_set, test_set} = Enum.split(remainder, val_size)
    
    {train_set, val_set, test_set}
  end
  
  @doc """
  Sample examples from a training set using various strategies.
  
  ## Parameters
  
  - `trainset` - Source training set
  - `num_samples` - Number of examples to sample
  - `opts` - Sampling options (strategy, seed, field)
  
  ## Sampling Strategies
  
  - `:random` - Random sampling
  - `:diverse` - Maximize diversity in examples
  - `:hard` - Select challenging examples
  - `:balanced` - Balance across categories/labels
  - `:uncertainty` - Select examples with high uncertainty (requires scores)
  
  """
  @spec sample(list(Example.t()), pos_integer(), keyword()) :: list(Example.t())
  def sample(trainset, num_samples, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :random)
    seed = Keyword.get(opts, :seed, :os.system_time(:microsecond))
    
    :rand.seed(:exsss, {seed, seed + 1, seed + 2})
    
    available_samples = min(num_samples, length(trainset))
    
    case strategy do
      :random -> 
        random_sample(trainset, available_samples)
        
      :diverse ->
        diverse_sample(trainset, available_samples, opts)
        
      :hard ->
        hard_sample(trainset, available_samples, opts)
        
      :balanced ->
        balanced_sample(trainset, available_samples, opts)
        
      :uncertainty ->
        uncertainty_sample(trainset, available_samples, opts)
        
      _ ->
        random_sample(trainset, available_samples)
    end
  end
  
  @doc """
  Bootstrap sample examples with replacement.
  
  Used for creating multiple training variations for ensemble methods.
  
  ## Parameters
  
  - `trainset` - Source training set
  - `num_samples` - Number of examples to sample (can exceed trainset size)
  - `opts` - Bootstrap options
  
  """
  @spec bootstrap_sample(list(Example.t()), pos_integer(), keyword()) :: list(Example.t())
  def bootstrap_sample(trainset, num_samples, opts \\ []) do
    seed = Keyword.get(opts, :seed, :os.system_time(:microsecond))
    :rand.seed(:exsss, {seed, seed + 1, seed + 2})
    
    for _ <- 1..num_samples do
      Enum.random(trainset)
    end
  end
  
  @doc """
  Create stratified samples maintaining class distribution.
  
  ## Parameters
  
  - `trainset` - Source training set
  - `num_samples` - Number of examples to sample
  - `field` - Field to use for stratification (default: :answer)
  
  """
  @spec stratified_sample(list(Example.t()), pos_integer(), atom()) :: list(Example.t())
  def stratified_sample(trainset, num_samples, field \\ :answer) do
    # Group by field value
    groups = trainset
    |> Enum.group_by(fn example -> 
      Map.get(example.attrs, field, Map.get(example.attrs, to_string(field), nil))
    end)
    
    # Calculate samples per group
    total_groups = map_size(groups)
    samples_per_group = div(num_samples, total_groups)
    remaining_samples = rem(num_samples, total_groups)
    
    # Sample from each group
    {samples, _} = groups
    |> Enum.reduce({[], remaining_samples}, fn {_label, group_examples}, {acc, remaining} ->
      group_sample_size = if remaining > 0, do: samples_per_group + 1, else: samples_per_group
      new_remaining = if remaining > 0, do: remaining - 1, else: 0
      
      group_samples = random_sample(group_examples, min(group_sample_size, length(group_examples)))
      {acc ++ group_samples, new_remaining}
    end)
    
    samples
  end
  
  @doc """
  Filter training set based on quality criteria.
  
  ## Parameters
  
  - `trainset` - Training set to filter
  - `criteria` - Filtering criteria function or keyword list
  
  """
  @spec filter_quality(list(Example.t()), function() | keyword()) :: list(Example.t())
  def filter_quality(trainset, criteria) when is_function(criteria, 1) do
    Enum.filter(trainset, criteria)
  end
  
  def filter_quality(trainset, criteria) when is_list(criteria) do
    min_length = Keyword.get(criteria, :min_length, 0)
    max_length = Keyword.get(criteria, :max_length, :infinity)
    required_fields = Keyword.get(criteria, :required_fields, [])
    exclude_patterns = Keyword.get(criteria, :exclude_patterns, [])
    
    trainset
    |> Enum.filter(fn example ->
      # Check field requirements
      fields_ok = Enum.all?(required_fields, fn field ->
        value = Map.get(example.attrs, field, Map.get(example.attrs, to_string(field), ""))
        value != nil and value != ""
      end)
      
      # Check length constraints
      text_length = example.attrs
      |> Map.values()
      |> Enum.map(&to_string/1)
      |> Enum.join(" ")
      |> String.length()
      
      length_ok = text_length >= min_length and (max_length == :infinity or text_length <= max_length)
      
      # Check exclusion patterns
      text_content = example.attrs |> Map.values() |> Enum.join(" ") |> String.downcase()
      patterns_ok = not Enum.any?(exclude_patterns, &String.contains?(text_content, String.downcase(&1)))
      
      fields_ok and length_ok and patterns_ok
    end)
  end
  
  @doc """
  Augment training set with variations of existing examples.
  
  ## Parameters
  
  - `trainset` - Source training set
  - `augmentation_fn` - Function to generate variations
  - `multiplier` - How many variations per example
  
  """
  @spec augment(list(Example.t()), function(), pos_integer()) :: list(Example.t())
  def augment(trainset, augmentation_fn, multiplier \\ 2) do
    trainset
    |> Enum.flat_map(fn example ->
      variations = for _ <- 1..multiplier do
        augmentation_fn.(example)
      end
      [example | variations]
    end)
  end
  
  # Private helper functions
  
  defp validate_basic_structure([]), do: {:error, "Empty training set"}
  
  defp validate_basic_structure(trainset) when is_list(trainset) do
    invalid = trainset
    |> Enum.with_index()
    |> Enum.find(fn {example, _idx} -> not is_struct(example, Example) end)
    
    case invalid do
      nil -> :ok
      {_example, idx} -> {:error, "Invalid example at index #{idx}: must be %Example{}"}
    end
  end
  
  defp validate_basic_structure(_), do: {:error, "Training set must be a list"}
  
  defp validate_signature_compatibility(_trainset, nil), do: :ok
  
  defp validate_signature_compatibility(trainset, signature) do
    # Check if examples have required fields from signature
    required_fields = signature.input_fields ++ signature.output_fields
    |> Enum.map(& &1.name)
    |> MapSet.new()
    
    missing_fields = trainset
    |> Enum.take(5)  # Check first 5 examples
    |> Enum.flat_map(fn example ->
      example_fields = example.attrs |> Map.keys() |> MapSet.new()
      MapSet.difference(required_fields, example_fields) |> MapSet.to_list()
    end)
    |> Enum.uniq()
    
    if length(missing_fields) > 0 do
      {:error, "Examples missing required fields: #{Enum.join(missing_fields, ", ")}"}
    else
      :ok
    end
  end
  
  defp normalize_example(%Example{} = example) do
    # Clean up attributes
    clean_attrs = example.attrs
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      clean_value = case value do
        v when is_binary(v) -> String.trim(v)
        v -> v
      end
      
      if clean_value != nil and clean_value != "" do
        Map.put(acc, key, clean_value)
      else
        acc
      end
    end)
    
    if map_size(clean_attrs) > 0 do
      %{example | attrs: clean_attrs}
    else
      nil
    end
  end
  
  defp normalize_example(_), do: nil
  
  defp random_sample(trainset, num_samples) do
    trainset |> Enum.shuffle() |> Enum.take(num_samples)
  end
  
  defp diverse_sample(trainset, num_samples, _opts) do
    # Simple diversity based on text similarity
    # Start with random example, then select most dissimilar
    if length(trainset) <= num_samples do
      trainset
    else
      [first | remaining] = Enum.shuffle(trainset)
      
      Enum.reduce(1..(num_samples - 1), [first], fn _, selected ->
        candidate = remaining
        |> Enum.reject(&Enum.member?(selected, &1))
        |> Enum.max_by(fn candidate ->
          selected |> Enum.map(&text_similarity(&1, candidate)) |> Enum.min()
        end)
        [candidate | selected]
      end)
      |> Enum.reverse()
    end
  end
  
  defp hard_sample(trainset, num_samples, opts) do
    # Requires difficulty scores - fallback to random if not available
    difficulty_field = Keyword.get(opts, :difficulty_field, :difficulty)
    
    scored_examples = trainset
    |> Enum.map(fn example ->
      difficulty = Map.get(example.attrs, difficulty_field, 0.5)
      {example, difficulty}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(num_samples)
    |> Enum.map(&elem(&1, 0))
    
    if length(scored_examples) >= num_samples do
      scored_examples
    else
      random_sample(trainset, num_samples)
    end
  end
  
  defp balanced_sample(trainset, num_samples, opts) do
    field = Keyword.get(opts, :balance_field, :answer)
    stratified_sample(trainset, num_samples, field)
  end
  
  defp uncertainty_sample(trainset, num_samples, opts) do
    # Requires uncertainty scores - fallback to random if not available  
    uncertainty_field = Keyword.get(opts, :uncertainty_field, :uncertainty)
    
    scored_examples = trainset
    |> Enum.map(fn example ->
      uncertainty = Map.get(example.attrs, uncertainty_field, 0.5)
      {example, uncertainty}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(num_samples)
    |> Enum.map(&elem(&1, 0))
    
    if length(scored_examples) >= num_samples do
      scored_examples
    else
      random_sample(trainset, num_samples)
    end
  end
  
  defp text_similarity(example1, example2) do
    text1 = example1.attrs |> Map.values() |> Enum.join(" ") |> String.downcase()
    text2 = example2.attrs |> Map.values() |> Enum.join(" ") |> String.downcase()
    
    tokens1 = String.split(text1) |> MapSet.new()
    tokens2 = String.split(text2) |> MapSet.new()
    
    intersection = MapSet.intersection(tokens1, tokens2) |> MapSet.size()
    union = MapSet.union(tokens1, tokens2) |> MapSet.size()
    
    if union > 0, do: intersection / union, else: 0.0
  end
end