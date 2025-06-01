defmodule Dspy.Parameter do
  @moduledoc """
  Optimizable parameters for DSPy modules.
  
  Parameters represent components that can be optimized by teleprompters,
  such as prompts, few-shot examples, and model weights.
  """

  defstruct [:name, :type, :value, :metadata, :history]

  @type parameter_type :: :prompt | :examples | :weights | :custom
  @type t :: %__MODULE__{
    name: String.t(),
    type: parameter_type(),
    value: any(),
    metadata: map(),
    history: [any()]
  }

  @doc """
  Create a new parameter.
  """
  def new(name, type, value, metadata \\ %{}) do
    %__MODULE__{
      name: name,
      type: type,
      value: value,
      metadata: metadata,
      history: [value]
    }
  end

  @doc """
  Update a parameter's value.
  """
  def update(parameter, new_value) do
    %{parameter | 
      value: new_value,
      history: [new_value | parameter.history]
    }
  end

  @doc """
  Get the parameter's current value.
  """
  def value(parameter), do: parameter.value

  @doc """
  Get the parameter's history of values.
  """
  def history(parameter), do: parameter.history

  @doc """
  Revert to the previous value.
  """
  def revert(parameter) do
    case parameter.history do
      [_current, previous | rest] ->
        %{parameter | value: previous, history: [previous | rest]}
      _ ->
        parameter
    end
  end
end