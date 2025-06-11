# Quick setup example for using GPT-4.1 with DSPy

# Make sure you have your OpenAI API key set:
# export OPENAI_API_KEY='your-api-key-here'

# Load dependencies
Mix.install([
  {:dspy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.2"},
  {:gen_stage, "~> 1.2"}
])

# Start the application
{:ok, _} = Application.ensure_all_started(:dspy)

# Option 1: Direct configuration
openai_client = Dspy.LM.OpenAI.new(
  model: "gpt-4.1",  # Can also use "gpt-4.1-mini" or "gpt-4.1-nano"
  api_key: System.get_env("OPENAI_API_KEY")
)

# Configure DSPy to use this client
Dspy.configure(lm: openai_client)

IO.puts("✅ DSPy configured with GPT-4.1!")

# Test it with a simple signature
defmodule SimpleTest do
  use Dspy.Signature
  
  signature_description "Answer a simple question"
  
  input_field :question, :string, "A question"
  output_field :answer, :string, "The answer"
end

# Create a basic predictor
predictor = Dspy.Predict.new(SimpleTest)

# Test it
result = Dspy.Module.forward(predictor, %{question: "What is 2+2?"})

case result do
  {:ok, prediction} ->
    IO.puts("\nQuestion: What is 2+2?")
    IO.puts("Answer: #{prediction.attrs.answer}")
    IO.puts("\n✨ GPT-4.1 is working with DSPy!")
  {:error, reason} ->
    IO.puts("\n❌ Error: #{inspect(reason)}")
    IO.puts("Make sure your OPENAI_API_KEY is set correctly")
end