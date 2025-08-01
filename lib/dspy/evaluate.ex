defmodule Dspy.Evaluate do
  @moduledoc """
  DSPy Evaluation Framework for measuring program performance.
  
  Provides comprehensive evaluation capabilities including:
  - Single program evaluation
  - Cross-validation
  - Batch evaluation
  - Performance tracking and comparison
  
  ## Usage
  
      # Basic evaluation
      result = Dspy.Evaluate.evaluate(program, testset, metric_fn)
      
      # Cross-validation
      cv_result = Dspy.Evaluate.cross_validate(program, dataset, metric_fn, k: 5)
      
      # Batch evaluation with multiple metrics
      batch_result = Dspy.Evaluate.batch_evaluate(programs, testset, metrics)
  
  """
  
  alias Dspy.{Example, Prediction, Module, Metrics}
  
  @type evaluation_result :: %{
    scores: list(number()),
    mean: number(),
    std: number(),
    min: number(),
    max: number(),
    count: pos_integer(),
    successes: pos_integer(),
    failures: pos_integer()
  }
  
  @type cross_validation_result :: %{
    fold_scores: list(number()),
    mean_score: number(),
    std_score: number(),
    fold_results: list(evaluation_result())
  }
  
  @doc """
  Evaluate a program on a test set using the given metric.
  
  ## Parameters
  
  - `program` - DSPy program module to evaluate
  - `testset` - List of test examples
  - `metric_fn` - Metric function (example, prediction -> score)
  - `opts` - Options: num_threads, progress, return_all
  
  ## Returns
  
  `evaluation_result()` with detailed statistics
  
  ## Examples
  
      result = Dspy.Evaluate.evaluate(program, testset, &Dspy.Metrics.exact_match/2)
      # %{mean: 0.85, std: 0.36, count: 100, ...}
  
  """
  @spec evaluate(module(), list(Example.t()), function(), keyword()) :: evaluation_result()
  def evaluate(program, testset, metric_fn, opts \\ []) do
    num_threads = Keyword.get(opts, :num_threads, System.schedulers_online())
    show_progress = Keyword.get(opts, :progress, false)
    return_all = Keyword.get(opts, :return_all, false)
    
    if show_progress do
      IO.puts("Evaluating #{length(testset)} examples...")
    end
    
    # Chunk testset for parallel processing
    chunk_size = max(1, div(length(testset), num_threads))
    chunks = Enum.chunk_every(testset, chunk_size)
    
    # Process chunks in parallel
    results = chunks
    |> Task.async_stream(fn chunk ->
      evaluate_chunk(program, chunk, metric_fn, show_progress)
    end, max_concurrency: num_threads, timeout: :infinity)
    |> Enum.flat_map(fn {:ok, chunk_results} -> chunk_results end)
    
    # Separate scores and predictions
    {scores, predictions} = Enum.unzip(results)
    valid_scores = Enum.filter(scores, &is_number/1)
    
    # Calculate statistics
    mean_score = if length(valid_scores) > 0, do: Enum.sum(valid_scores) / length(valid_scores), else: 0.0
    std_score = calculate_std(valid_scores, mean_score)
    
    result = %{
      scores: if(return_all, do: scores, else: valid_scores),
      predictions: if(return_all, do: predictions, else: []),
      mean: mean_score,
      std: std_score,
      min: if(length(valid_scores) > 0, do: Enum.min(valid_scores), else: 0),
      max: if(length(valid_scores) > 0, do: Enum.max(valid_scores), else: 0),
      count: length(testset),
      successes: length(valid_scores),
      failures: length(testset) - length(valid_scores)
    }
    
    if show_progress do
      IO.puts("Evaluation complete: #{Float.round(result.mean, 3)} ± #{Float.round(result.std, 3)}")
    end
    
    result
  end
  
  @doc """
  Perform k-fold cross-validation on a dataset.
  
  ## Parameters
  
  - `program` - DSPy program to evaluate
  - `dataset` - Full dataset to split into folds
  - `metric_fn` - Metric function
  - `opts` - Options: k (default 5), shuffle, seed
  
  ## Returns
  
  `cross_validation_result()` with fold-by-fold results
  
  """
  @spec cross_validate(module(), list(Example.t()), function(), keyword()) :: cross_validation_result()
  def cross_validate(program, dataset, metric_fn, opts \\ []) do
    k = Keyword.get(opts, :k, 5)
    shuffle = Keyword.get(opts, :shuffle, true)
    seed = Keyword.get(opts, :seed, :os.system_time(:microsecond))
    
    # Shuffle dataset if requested
    shuffled_dataset = if shuffle do
      :rand.seed(:exsss, {seed, seed + 1, seed + 2})
      Enum.shuffle(dataset)
    else
      dataset
    end
    
    # Create folds
    fold_size = div(length(shuffled_dataset), k)
    folds = shuffled_dataset
    |> Enum.chunk_every(fold_size)
    |> Enum.take(k)
    
    # Evaluate each fold
    fold_results = folds
    |> Enum.with_index()
    |> Enum.map(fn {test_fold, idx} ->
      train_folds = folds |> Enum.with_index() |> Enum.reject(fn {_, i} -> i == idx end) |> Enum.map(&elem(&1, 0))
      _train_set = List.flatten(train_folds)
      
      IO.puts("Cross-validation fold #{idx + 1}/#{k}")
      evaluate(program, test_fold, metric_fn, progress: false)
    end)
    
    # Calculate overall statistics
    fold_scores = Enum.map(fold_results, & &1.mean)
    mean_score = Enum.sum(fold_scores) / length(fold_scores)
    std_score = calculate_std(fold_scores, mean_score)
    
    %{
      fold_scores: fold_scores,
      mean_score: mean_score,
      std_score: std_score,
      fold_results: fold_results
    }
  end
  
  @doc """
  Evaluate multiple programs on the same test set.
  
  ## Parameters
  
  - `programs` - List of {name, program} tuples
  - `testset` - Test examples
  - `metrics` - List of {name, metric_fn} tuples
  - `opts` - Options
  
  ## Returns
  
  Map of program_name -> metric_name -> result
  
  """
  @spec batch_evaluate(list({String.t(), module()}), list(Example.t()), list({String.t(), function()}), keyword()) :: map()
  def batch_evaluate(programs, testset, metrics, opts \\ []) do
    for {prog_name, program} <- programs, into: %{} do
      metric_results = for {metric_name, metric_fn} <- metrics, into: %{} do
        {metric_name, evaluate(program, testset, metric_fn, opts)}
      end
      {prog_name, metric_results}
    end
  end
  
  @doc """
  Compare two evaluation results and return improvement statistics.
  
  ## Parameters
  
  - `baseline_result` - Baseline evaluation result
  - `optimized_result` - Optimized evaluation result
  
  ## Returns
  
  Map with improvement statistics
  
  """
  @spec compare_results(evaluation_result(), evaluation_result()) :: map()
  def compare_results(baseline, optimized) do
    improvement = optimized.mean - baseline.mean
    relative_improvement = if baseline.mean != 0, do: improvement / baseline.mean, else: 0
    
    %{
      baseline_score: baseline.mean,
      optimized_score: optimized.mean,
      absolute_improvement: improvement,
      relative_improvement: relative_improvement,
      improvement_pct: relative_improvement * 100,
      statistical_significance: statistical_significance_test(baseline, optimized)
    }
  end
  
  # Private functions
  
  defp evaluate_chunk(program, examples, metric_fn, _show_progress) do
    examples
    |> Enum.map(fn example ->
      try do
        # Run program on example
        case Module.forward(program, example.attrs) do
          {:ok, prediction} ->
            score = Dspy.Teleprompt.run_metric(metric_fn, example, prediction)
            {score, prediction}
          
          {:error, _reason} ->
            {:error, nil}
        end
      rescue
        _ -> {:error, nil}
      end
    end)
  end
  
  defp calculate_std([], _mean), do: 0.0
  defp calculate_std([_], _mean), do: 0.0
  defp calculate_std(values, mean) do
    variance = values
    |> Enum.map(&:math.pow(&1 - mean, 2))
    |> Enum.sum()
    |> Kernel./(length(values) - 1)
    
    :math.sqrt(variance)
  end
  
  defp statistical_significance_test(baseline, optimized) do
    # Simple t-test approximation
    if baseline.count > 10 and optimized.count > 10 do
      pooled_std = :math.sqrt((baseline.std * baseline.std + optimized.std * optimized.std) / 2)
      
      if pooled_std > 0 do
        t_stat = abs(optimized.mean - baseline.mean) / 
                 (pooled_std * :math.sqrt(2 / min(baseline.count, optimized.count)))
        
        cond do
          t_stat > 2.58 -> :highly_significant  # p < 0.01
          t_stat > 1.96 -> :significant         # p < 0.05
          t_stat > 1.65 -> :marginally_significant  # p < 0.10
          true -> :not_significant
        end
      else
        :insufficient_data
      end
    else
      :insufficient_data
    end
  end
end