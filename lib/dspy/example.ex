defmodule Dspy.Example do
  @moduledoc """
  Training examples for DSPy programs.

  Examples represent input-output pairs used for few-shot learning,
  optimization, and evaluation. They support flexible attribute access
  and can contain arbitrary fields.
  """

  defstruct [:attrs, :metadata]

  @type t :: %__MODULE__{
          attrs: map(),
          metadata: map()
        }

  @doc """
  Create a new Example with the given attributes.

  ## Examples

      iex> ex = Dspy.Example.new(%{question: "What is 2+2?", answer: "4"})
      iex> ex.question
      "What is 2+2?"

      iex> ex = Dspy.Example.new(question: "What is 2+2?", answer: "4")
      iex> ex.answer
      "4"
  """
  def new(attrs \\ %{}, metadata \\ %{}) do
    attrs = normalize_attrs(attrs)
    %__MODULE__{attrs: attrs, metadata: metadata}
  end

  @doc """
  Get an attribute from the example.
  """
  def get(example, key, default \\ nil) do
    Map.get(example.attrs, key, default)
  end

  @doc """
  Put an attribute in the example.
  """
  def put(example, key, value) do
    new_attrs = Map.put(example.attrs, key, value)
    %{example | attrs: new_attrs}
  end

  @doc """
  Delete an attribute from the example.
  """
  def delete(example, key) do
    new_attrs = Map.delete(example.attrs, key)
    %{example | attrs: new_attrs}
  end

  @doc """
  Get all attribute keys.
  """
  def keys(example) do
    Map.keys(example.attrs)
  end

  @doc """
  Convert example to a map.
  """
  def to_map(example) do
    example.attrs
  end

  @doc """
  Merge two examples, with the second taking precedence.
  """
  def merge(example1, example2) do
    new_attrs = Map.merge(example1.attrs, example2.attrs)
    new_metadata = Map.merge(example1.metadata, example2.metadata)
    %__MODULE__{attrs: new_attrs, metadata: new_metadata}
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
end
