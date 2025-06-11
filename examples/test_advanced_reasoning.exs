# Test Advanced Reasoning Examples with DSPy
# Simplified version to test which modules work

# Load dependencies
Mix.install([
  {:dspy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.2"},
  {:gen_stage, "~> 1.2"}
])

# Start the application
Application.ensure_all_started(:dspy)

# Configure DSPy with OpenAI
Dspy.configure(lm: Dspy.LM.OpenAI.new(
  model: "gpt-4.1-mini",
  api_key: System.get_env("OPENAI_API_KEY")
))

# Test 1: Basic Predict
defmodule SimpleQA do
  use Dspy.Signature
  
  signature_description "Answer a simple question"
  
  input_field :question, :string, "Question to answer"
  output_field :answer, :string, "Answer to the question"
end

IO.puts("=== Test 1: Basic Predict ===")
predict = Dspy.Predict.new(SimpleQA)
case Dspy.Module.forward(predict, %{question: "What is 2 + 2?"}) do
  {:ok, prediction} -> 
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

# Test 2: Chain of Thought
IO.puts("\n=== Test 2: Chain of Thought ===")
cot = Dspy.ChainOfThought.new(SimpleQA)
case Dspy.Module.forward(cot, %{question: "If I have 5 apples and eat 2, how many do I have left?"}) do
  {:ok, prediction} -> 
    IO.puts("Reasoning: #{prediction.attrs.reasoning}")
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

# Test 3: Self-Consistency
IO.puts("\n=== Test 3: Self-Consistency ===")
self_cons = Dspy.SelfConsistency.new(SimpleQA, num_samples: 3)
case Dspy.Module.forward(self_cons, %{question: "What day comes after Tuesday?"}) do
  {:ok, prediction} -> 
    IO.puts("Answer: #{prediction.attrs.answer}")
    if Map.has_key?(prediction.attrs, :reasoning) do
      IO.puts("Reasoning: #{prediction.attrs.reasoning}")
    end
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

# Test 4: Reflection
IO.puts("\n=== Test 4: Reflection ===")
reflection = Dspy.Reflection.new(SimpleQA, max_reflections: 2)
case Dspy.Module.forward(reflection, %{question: "What is the capital of Japan?"}) do
  {:ok, prediction} -> 
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

# Test 5: Tree of Thoughts
IO.puts("\n=== Test 5: Tree of Thoughts ===")
tot = Dspy.TreeOfThoughts.new(SimpleQA, branches: 2, depth: 2)
case Dspy.Module.forward(tot, %{question: "What is the best way to learn programming?"}) do
  {:ok, prediction} -> 
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== All Tests Complete ===")