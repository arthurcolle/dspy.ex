defmodule Dspy do
  @moduledoc """
  Elixir implementation of DSPy - a framework for algorithmically optimizing LM prompts and weights.

  DSPy provides a unified interface for composing LM programs with automatic optimization.
  
  ## Core Components

  - `Dspy.Signature` - Define typed input/output interfaces for LM calls
  - `Dspy.Module` - Composable building blocks for LM programs  
  - `Dspy.Predict` - Basic prediction modules
  - `Dspy.ChainOfThought` - Step-by-step reasoning
  - `Dspy.LM` - Language model client abstraction
  - `Dspy.Example` - Training examples and data structures
  - `Dspy.Teleprompter` - Prompt optimization algorithms

  ## Quick Start

      # Configure language model
      Dspy.configure(lm: %Dspy.LM.OpenAI{model: "gpt-4.1"})

      # Define signature
      defmodule QA do
        use Dspy.Signature
        input_field :question, :string, "Question to answer"
        output_field :answer, :string, "Answer to the question"
      end

      # Create and use module
      predict = Dspy.Predict.new(QA)
      result = Dspy.Module.forward(predict, %{question: "What is 2+2?"})
  """

  alias Dspy.{Settings, Example, Prediction}

  @doc """
  Configure global DSPy settings.

  ## Options
  
  - `:lm` - Language model client (required)
  - `:max_tokens` - Maximum tokens per generation (default: 2048)
  - `:temperature` - Sampling temperature (default: 0.0)
  - `:cache` - Enable response caching (default: true)
  """
  def configure(opts \\ []) do
    Settings.configure(opts)
  end

  @doc """
  Get current DSPy configuration.
  """
  def settings do
    Settings.get()
  end

  @doc """
  Create a new Example with the given attributes.
  """
  def example(attrs \\ %{}) do
    Example.new(attrs)
  end

  @doc """
  Create a new Prediction with the given attributes.
  """
  def prediction(attrs \\ %{}) do
    Prediction.new(attrs)
  end
end