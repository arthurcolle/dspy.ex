defmodule Dspy.Module do
  @moduledoc """
  Behaviour for composable DSPy modules.

  Modules are the building blocks of DSPy programs. They define
  forward passes for inference and can contain optimizable parameters.
  """

  @type t :: struct()
  @type inputs :: map()
  @type outputs :: Dspy.Prediction.t()

  @doc """
  Execute the module's forward pass.
  """
  @callback forward(module :: t(), inputs :: inputs()) :: {:ok, outputs()} | {:error, any()}

  @doc """
  Get the module's optimizable parameters.
  """
  @callback parameters(module :: t()) :: [Dspy.Parameter.t()]

  @doc """
  Update the module with new parameters.
  """
  @callback update_parameters(module :: t(), parameters :: [Dspy.Parameter.t()]) :: t()

  @optional_callbacks [parameters: 1, update_parameters: 2]

  @doc """
  Execute a module's forward pass.
  """
  def forward(module, inputs) do
    module.__struct__.forward(module, inputs)
  end

  @doc """
  Get a module's parameters if it implements the callback.
  """
  def parameters(module) do
    if function_exported?(module.__struct__, :parameters, 1) do
      module.__struct__.parameters(module)
    else
      []
    end
  end

  @doc """
  Update a module's parameters if it implements the callback.
  """
  def update_parameters(module, parameters) do
    if function_exported?(module.__struct__, :update_parameters, 2) do
      module.__struct__.update_parameters(module, parameters)
    else
      module
    end
  end

  @doc """
  Compose multiple modules in sequence.
  """
  def compose(modules) when is_list(modules) do
    fn inputs ->
      Enum.reduce_while(modules, {:ok, inputs}, fn module, {:ok, current_inputs} ->
        case forward(module, current_inputs) do
          {:ok, prediction} -> {:cont, {:ok, prediction.attrs}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  @doc """
  Run modules in parallel and merge results.
  """
  def parallel(modules) when is_list(modules) do
    fn inputs ->
      tasks =
        modules
        |> Enum.map(fn module ->
          Task.async(fn -> forward(module, inputs) end)
        end)

      results = Task.await_many(tasks)

      case Enum.find(results, fn
             {:error, _} -> true
             _ -> false
           end) do
        {:error, reason} ->
          {:error, reason}

        nil ->
          merged_attrs =
            results
            |> Enum.map(fn {:ok, prediction} -> prediction.attrs end)
            |> Enum.reduce(%{}, &Map.merge/2)

          {:ok, Dspy.Prediction.new(merged_attrs)}
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Dspy.Module

      def forward(_module, _inputs), do: {:error, :not_implemented}
      def parameters(_module), do: []
      def update_parameters(module, _parameters), do: module

      defoverridable forward: 2, parameters: 1, update_parameters: 2
    end
  end
end
