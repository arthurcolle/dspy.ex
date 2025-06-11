# Basic DSPy Usage Examples with GPT-4.1 Models

# Load dependencies
Mix.install([
  {:dspy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.2"},
  {:gen_stage, "~> 1.2"}
])

# Start the application
Application.ensure_all_started(:dspy)

# Configure with different GPT-4.1 variants based on your needs

# GPT-4.1 - Most capable, highest cost
Dspy.configure(lm: Dspy.LM.OpenAI.new(
  model: "gpt-4.1",
  api_key: System.get_env("OPENAI_API_KEY")
))

# GPT-4.1-mini - Balanced performance and cost
# Dspy.configure(lm: Dspy.LM.OpenAI.new(
#   model: "gpt-4.1-mini",
#   api_key: System.get_env("OPENAI_API_KEY")
# ))

# GPT-4.1-nano - Fastest, most economical
# Dspy.configure(lm: Dspy.LM.OpenAI.new(
#   model: "gpt-4.1-nano", 
#   api_key: System.get_env("OPENAI_API_KEY")
# ))

# Define a simple Q&A signature
defmodule BasicQA do
  use Dspy.Signature
  
  signature_description "Answer questions accurately and concisely"
  
  input_field :question, :string, "Question to answer"
  output_field :answer, :string, "Clear and accurate answer"
end

# Create and use a basic predict module
predict = Dspy.Predict.new(BasicQA)

# Make a prediction
case Dspy.Module.forward(predict, %{question: "What is the capital of France?"}) do
  {:ok, prediction} -> 
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

# Example with Chain of Thought reasoning
defmodule MathQA do
  use Dspy.Signature
  
  signature_description "Solve math problems with clear reasoning"
  
  input_field :problem, :string, "Math problem to solve"
  output_field :answer, :string, "Final numerical answer"
end

# Create Chain of Thought module
cot = Dspy.ChainOfThought.new(MathQA)

# Solve a math problem with reasoning
case Dspy.Module.forward(cot, %{problem: "If I have 15 apples and give away 7, then buy 12 more, how many apples do I have?"}) do
  {:ok, prediction} -> 
    IO.puts("Reasoning: #{prediction.attrs.reasoning}")
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

# Example with few-shot learning
examples = [
  Dspy.example(%{
    problem: "I have 10 cookies and eat 3. How many are left?",
    reasoning: "Starting with 10 cookies, if I eat 3, then 10 - 3 = 7 cookies remain.",
    answer: "7"
  }),
  Dspy.example(%{
    problem: "A box has 24 pencils. I take out 8. How many remain?", 
    reasoning: "The box started with 24 pencils. After taking out 8: 24 - 8 = 16 pencils remain.",
    answer: "16"
  })
]

# Create module with examples
cot_with_examples = Dspy.ChainOfThought.new(MathQA, examples: examples)

# This will now use the examples to guide reasoning
case Dspy.Module.forward(cot_with_examples, %{problem: "I start with 50 marbles and lose 13. How many do I have left?"}) do
  {:ok, prediction} -> 
    IO.puts("Reasoning with examples: #{prediction.attrs.reasoning}")
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end