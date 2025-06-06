defmodule Dspy.Prediction do
  @moduledoc """
  Language model predictions with completion metadata.

  Predictions represent the outputs from language model calls,
  including the generated content and metadata about the generation process.
  """

  defstruct [:attrs, :completions, :metadata]

  @type completion :: %{
          text: String.t(),
          tokens: pos_integer() | nil,
          logprobs: map() | nil,
          finish_reason: String.t() | nil
        }

  @type t :: %__MODULE__{
          attrs: map(),
          completions: [completion()],
          metadata: map()
        }

  @doc """
  Create a new Prediction with the given attributes.

  ## Examples

      iex> pred = Dspy.Prediction.new(%{answer: "4"})
      iex> pred.answer
      "4"

      iex> pred = Dspy.Prediction.new(answer: "4", reasoning: "2+2=4")
      iex> pred.reasoning
      "2+2=4"
  """
  def new(attrs \\ %{}, completions \\ [], metadata \\ %{}) do
    attrs = normalize_attrs(attrs)

    %__MODULE__{
      attrs: attrs,
      completions: completions,
      metadata: metadata
    }
  end

  @doc """
  Get an attribute from the prediction.
  """
  def get(prediction, key, default \\ nil) do
    Map.get(prediction.attrs, key, default)
  end

  @doc """
  Put an attribute in the prediction.
  """
  def put(prediction, key, value) do
    new_attrs = Map.put(prediction.attrs, key, value)
    %{prediction | attrs: new_attrs}
  end

  @doc """
  Delete an attribute from the prediction.
  """
  def delete(prediction, key) do
    new_attrs = Map.delete(prediction.attrs, key)
    %{prediction | attrs: new_attrs}
  end

  @doc """
  Get all attribute keys.
  """
  def keys(prediction) do
    Map.keys(prediction.attrs)
  end

  @doc """
  Convert prediction to a map.
  """
  def to_map(prediction) do
    prediction.attrs
  end

  @doc """
  Add completion metadata to the prediction.
  """
  def add_completion(prediction, completion) do
    new_completions = [completion | prediction.completions]
    %{prediction | completions: new_completions}
  end

  @doc """
  Get the most recent completion.
  """
  def latest_completion(prediction) do
    List.first(prediction.completions)
  end

  @doc """
  Get all completions.
  """
  def completions(prediction) do
    prediction.completions
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
end
