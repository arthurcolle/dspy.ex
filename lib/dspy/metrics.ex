defmodule Dspy.Metrics do
  @moduledoc """
  Standard evaluation metrics for DSPy programs.
  
  Provides common metrics used in language model evaluation:
  - Exact match
  - F1 score (token-level)
  - BLEU score
  - ROUGE scores
  - Accuracy
  - Custom metric composition
  
  ## Usage
  
      # Use predefined metrics
      score = Dspy.Metrics.exact_match(example, prediction)
      f1 = Dspy.Metrics.f1_score(example, prediction)
      
      # Create custom metrics
      custom_metric = Dspy.Metrics.create_metric(fn example, pred ->
        # Custom scoring logic
        if String.contains?(pred.answer, example.answer), do: 1.0, else: 0.0
      end)
  
  """
  
  alias Dspy.{Example, Prediction}
  
  @type metric_function :: (Example.t(), Prediction.t() -> number())
  @type metric_result :: %{
    score: number(),
    details: map()
  }
  
  @doc """
  Exact match metric - returns 1.0 if answers match exactly, 0.0 otherwise.
  
  ## Parameters
  
  - `example` - Ground truth example
  - `prediction` - Model prediction
  - `field` - Field to compare (default: :answer)
  
  ## Examples
  
      score = Dspy.Metrics.exact_match(example, prediction)
      # 1.0 or 0.0
  
  """
  @spec exact_match(Example.t(), Prediction.t(), atom()) :: number()
  def exact_match(example, prediction, field \\ :answer) do
    truth = get_field_value(example, field)
    pred = get_field_value(prediction, field)
    
    if normalize_text(truth) == normalize_text(pred), do: 1.0, else: 0.0
  end
  
  @doc """
  Token-level F1 score between ground truth and prediction.
  
  ## Parameters
  
  - `example` - Ground truth example
  - `prediction` - Model prediction  
  - `field` - Field to compare (default: :answer)
  
  ## Returns
  
  F1 score between 0.0 and 1.0
  
  """
  @spec f1_score(Example.t(), Prediction.t(), atom()) :: number()
  def f1_score(example, prediction, field \\ :answer) do
    truth = get_field_value(example, field)
    pred = get_field_value(prediction, field)
    
    truth_tokens = tokenize(truth)
    pred_tokens = tokenize(pred)
    
    if length(truth_tokens) == 0 and length(pred_tokens) == 0 do
      1.0
    else
      common = MapSet.intersection(MapSet.new(truth_tokens), MapSet.new(pred_tokens))
      precision = if length(pred_tokens) > 0, do: MapSet.size(common) / length(pred_tokens), else: 0.0
      recall = if length(truth_tokens) > 0, do: MapSet.size(common) / length(truth_tokens), else: 0.0
      
      if precision + recall > 0 do
        2 * precision * recall / (precision + recall)
      else
        0.0
      end
    end
  end
  
  @doc """
  Accuracy metric for classification tasks.
  
  ## Parameters
  
  - `example` - Ground truth example
  - `prediction` - Model prediction
  - `field` - Field to compare (default: :answer)
  
  """
  @spec accuracy(Example.t(), Prediction.t(), atom()) :: number()
  def accuracy(example, prediction, field \\ :answer) do
    exact_match(example, prediction, field)
  end
  
  @doc """
  Contains metric - returns 1.0 if prediction contains ground truth.
  
  Useful for checking if key information is present in longer responses.
  
  """
  @spec contains(Example.t(), Prediction.t(), atom()) :: number()
  def contains(example, prediction, field \\ :answer) do
    truth = get_field_value(example, field) |> normalize_text()
    pred = get_field_value(prediction, field) |> normalize_text() 
    
    if String.contains?(pred, truth), do: 1.0, else: 0.0
  end
  
  @doc """
  Substring match metric with partial credit.
  
  Returns the ratio of matching substrings.
  
  """
  @spec substring_match(Example.t(), Prediction.t(), atom()) :: number()
  def substring_match(example, prediction, field \\ :answer) do
    truth = get_field_value(example, field) |> normalize_text()
    pred = get_field_value(prediction, field) |> normalize_text()
    
    if String.length(truth) == 0 and String.length(pred) == 0 do
      1.0
    else
      max_len = max(String.length(truth), String.length(pred))
      if max_len == 0, do: 0.0, else: longest_common_substring(truth, pred) / max_len
    end
  end
  
  @doc """
  BLEU score approximation for text generation evaluation.
  
  Simplified BLEU-1 implementation based on unigram precision.
  
  """
  @spec bleu_score(Example.t(), Prediction.t(), atom()) :: number()
  def bleu_score(example, prediction, field \\ :answer) do
    truth = get_field_value(example, field)
    pred = get_field_value(prediction, field)
    
    truth_tokens = tokenize(truth)
    pred_tokens = tokenize(pred)
    
    if length(pred_tokens) == 0 do
      0.0
    else
      truth_set = MapSet.new(truth_tokens)
      matches = pred_tokens |> Enum.count(&MapSet.member?(truth_set, &1))
      
      precision = matches / length(pred_tokens)
      
      # Add brevity penalty
      brevity_penalty = if length(pred_tokens) < length(truth_tokens) do
        :math.exp(1 - length(truth_tokens) / length(pred_tokens))
      else
        1.0
      end
      
      precision * brevity_penalty
    end
  end
  
  @doc """
  Numeric accuracy for mathematical problems.
  
  Compares numeric values with optional tolerance.
  
  """
  @spec numeric_accuracy(Example.t(), Prediction.t(), atom(), number()) :: number()
  def numeric_accuracy(example, prediction, field \\ :answer, tolerance \\ 1.0e-6) do
    truth = extract_number(get_field_value(example, field))
    pred = extract_number(get_field_value(prediction, field))
    
    case {truth, pred} do
      {nil, nil} -> 1.0
      {nil, _} -> 0.0
      {_, nil} -> 0.0
      {t, p} -> if abs(t - p) <= tolerance, do: 1.0, else: 0.0
    end
  end
  
  @doc """
  Create a custom metric function with pre/post processing.
  
  ## Parameters
  
  - `metric_fn` - Function that takes (example, prediction) and returns score
  - `opts` - Options: normalize, field, transform
  
  ## Examples
  
      custom_metric = Dspy.Metrics.create_metric(fn example, pred ->
        # Custom logic here
        similarity_score(example.answer, pred.answer)
      end, normalize: true)
  
  """
  @spec create_metric(function(), keyword()) :: metric_function()
  def create_metric(metric_fn, opts \\ []) do
    normalize = Keyword.get(opts, :normalize, false)
    field = Keyword.get(opts, :field, :answer)
    transform = Keyword.get(opts, :transform, &Function.identity/1)
    
    fn example, prediction ->
      try do
        # Apply transformations
        processed_example = if normalize do
          update_field(example, field, &normalize_text/1)
        else
          example
        end
        
        processed_prediction = if normalize do
          update_field(prediction, field, &normalize_text/1) 
        else
          prediction
        end
        
        # Apply custom transform
        final_example = transform.(processed_example)
        final_prediction = transform.(processed_prediction)
        
        # Run metric
        score = metric_fn.(final_example, final_prediction)
        if is_number(score), do: score, else: 0.0
      rescue
        _ -> 0.0
      end
    end
  end
  
  @doc """
  Combine multiple metrics with weights.
  
  ## Parameters
  
  - `metrics` - List of {metric_function, weight} tuples
  
  ## Returns
  
  Combined metric function
  
  """
  @spec combine_metrics(list({metric_function(), number()})) :: metric_function()
  def combine_metrics(metrics) do
    total_weight = metrics |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    
    fn example, prediction ->
      weighted_sum = metrics
      |> Enum.map(fn {metric_fn, weight} ->
        score = metric_fn.(example, prediction)
        score * weight
      end)
      |> Enum.sum()
      
      if total_weight > 0, do: weighted_sum / total_weight, else: 0.0
    end
  end
  
  # Private helper functions
  
  defp get_field_value(%Example{attrs: attrs}, field) do
    Map.get(attrs, field, Map.get(attrs, to_string(field), ""))
  end
  
  defp get_field_value(%Prediction{attrs: attrs}, field) do
    Map.get(attrs, field, Map.get(attrs, to_string(field), ""))
  end
  
  defp get_field_value(map, field) when is_map(map) do
    Map.get(map, field, Map.get(map, to_string(field), ""))
  end
  
  defp get_field_value(value, _field), do: to_string(value)
  
  defp update_field(%Example{attrs: attrs} = example, field, transform_fn) do
    new_value = get_field_value(example, field) |> transform_fn.()
    %{example | attrs: Map.put(attrs, field, new_value)}
  end
  
  defp update_field(%Prediction{attrs: attrs} = prediction, field, transform_fn) do
    new_value = get_field_value(prediction, field) |> transform_fn.()
    %{prediction | attrs: Map.put(attrs, field, new_value)}
  end
  
  defp normalize_text(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
  
  defp normalize_text(value), do: value |> to_string() |> normalize_text()
  
  defp tokenize(text) when is_binary(text) do
    text
    |> normalize_text()
    |> String.split()
    |> Enum.reject(&(&1 == ""))
  end
  
  defp tokenize(value), do: value |> to_string() |> tokenize()
  
  defp extract_number(text) when is_binary(text) do
    case Regex.scan(~r/-?\d+\.?\d*/, text) do
      [[number_str] | _] -> 
        case Float.parse(number_str) do
          {num, _} -> num
          :error -> 
            case Integer.parse(number_str) do
              {num, _} -> num * 1.0
              :error -> nil
            end
        end
      _ -> nil
    end
  end
  
  defp extract_number(num) when is_number(num), do: num * 1.0
  defp extract_number(_), do: nil
  
  defp longest_common_substring(s1, s2) do
    len1 = String.length(s1)
    len2 = String.length(s2)
    
    if len1 == 0 or len2 == 0 do
      0
    else
      # Dynamic programming approach for LCS length
      dp = Enum.reduce(0..len1, %{}, fn i, acc_i ->
        Enum.reduce(0..len2, acc_i, fn j, acc_j ->
          value = cond do
            i == 0 or j == 0 -> 0
            String.at(s1, i-1) == String.at(s2, j-1) -> Map.get(acc_j, {i-1, j-1}, 0) + 1
            true -> max(Map.get(acc_j, {i-1, j}, 0), Map.get(acc_j, {i, j-1}, 0))
          end
          Map.put(acc_j, {i, j}, value)
        end)
      end)
      
      Map.get(dp, {len1, len2}, 0)
    end
  end
end