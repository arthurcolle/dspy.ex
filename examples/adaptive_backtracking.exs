# Example: Adaptive Backtracking with Reflection
# This demonstrates the new Dspy.AdaptiveBacktracking module that combines
# reflection with intelligent backtracking strategies.

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
  model: "gpt-4o-mini",
  api_key: System.get_env("OPENAI_API_KEY")
))

# Define a custom constraint function for mathematical problems
defmodule MathConstraints do
  def valid_mathematical_reasoning(step, _inputs) do
    reasoning = step.content
    
    # Check if mathematical operations are reasonable
    cond do
      String.contains?(reasoning, "divide by 0") ->
        false
      
      String.contains?(reasoning, "negative square root") and 
      not String.contains?(String.downcase(reasoning), "complex") ->
        false
      
      true ->
        true
    end
  end
  
  def logical_consistency(step, _inputs) do
    reasoning = step.content
    
    # Simple contradiction detection
    contradictory_phrases = [
      {"always true", "never true"},
      {"impossible", "definitely possible"},
      {"cannot be", "must be"}
    ]
    
    reasoning_lower = String.downcase(reasoning)
    
    not Enum.any?(contradictory_phrases, fn {phrase1, phrase2} ->
      String.contains?(reasoning_lower, phrase1) and 
      String.contains?(reasoning_lower, phrase2)
    end)
  end
end

# Example 1: Mathematical Problem Solving with Constraints
defmodule MathProblemSignature do
  use Dspy.Signature
  
  signature_description "Given a mathematical problem, solve it step by step with detailed reasoning."
  
  input_field :problem, :string, "The mathematical problem to solve"
  output_field :solution, :number, "The numerical solution"
  output_field :explanation, :string, "Detailed explanation of the solution"
end

IO.puts("=== Adaptive Backtracking Example ===\n")

# Create the adaptive backtracking module with confidence and constraint settings
adaptive_solver = Dspy.AdaptiveBacktracking.new(
  MathProblemSignature,
  confidence_threshold: 0.8,
  max_backtrack_depth: 4,
  constraint_functions: [
    &MathConstraints.valid_mathematical_reasoning/2,
    &MathConstraints.logical_consistency/2
  ],
  exploration_strategy: :adaptive,
  memory_enabled: true,
  adaptive_depth: true
)

# Test with a complex mathematical problem
problem_input = %{
  problem: "Find the roots of the quadratic equation 2x² - 7x + 3 = 0"
}

IO.puts("Problem: #{problem_input.problem}")
IO.puts("Solving with adaptive backtracking...\n")

case Dspy.Module.forward(adaptive_solver, problem_input) do
  {:ok, prediction} ->
    IO.puts("Solution found!")
    IO.puts("Answer: #{prediction.attrs.solution}")
    IO.puts("Explanation: #{prediction.attrs.explanation}")
  
  {:error, reason} ->
    IO.puts("Failed to solve: #{inspect(reason)}")
end

IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

# Example 2: Logical Reasoning with High Confidence Requirements
defmodule LogicProblemSignature do
  use Dspy.Signature
  
  signature_description "Solve this logical reasoning problem with clear justification."
  
  input_field :premises, :string, "The logical premises to analyze"
  output_field :conclusion, :string, "The logical conclusion"
  output_field :justification, :string, "Clear justification for the conclusion"
end

logic_solver = Dspy.AdaptiveBacktracking.new(
  LogicProblemSignature,
  confidence_threshold: 0.9,  # Higher threshold for logical problems
  max_backtrack_depth: 3,
  constraint_functions: [&MathConstraints.logical_consistency/2],
  exploration_strategy: :adaptive
)

logic_input = %{
  premises: "All birds can fly. Penguins are birds. Penguins cannot fly."
}

IO.puts("Logic Problem: #{logic_input.premises}")
IO.puts("Solving with high confidence requirements...\n")

case Dspy.Module.forward(logic_solver, logic_input) do
  {:ok, prediction} ->
    IO.puts("Logic analysis complete!")
    IO.puts("Conclusion: #{prediction.attrs.conclusion}")
    IO.puts("Justification: #{prediction.attrs.justification}")
  
  {:error, reason} ->
    IO.puts("Failed to analyze: #{inspect(reason)}")
end

IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

# Example 3: Comparing Adaptive Backtracking vs Simple Reflection
defmodule SimpleQuestionSignature do
  use Dspy.Signature
  
  signature_description "Answer this question thoughtfully."
  
  input_field :question, :string, "The question to answer"
  output_field :answer, :string, "A thoughtful answer to the question"
end

question_input = %{
  question: "What are the main advantages of renewable energy sources?"
}

IO.puts("Question: #{question_input.question}")
IO.puts("\n--- Comparison: Adaptive Backtracking vs Simple Reflection ---\n")

# Simple reflection approach
simple_reflection = Dspy.Reflection.new(SimpleQuestionSignature, max_reflections: 2)

IO.puts("1. Simple Reflection Result:")
case Dspy.Module.forward(simple_reflection, question_input) do
  {:ok, prediction} ->
    IO.puts("   Answer: #{prediction.attrs.answer}")
  {:error, reason} ->
    IO.puts("   Failed: #{inspect(reason)}")
end

# Adaptive backtracking approach
adaptive_answerer = Dspy.AdaptiveBacktracking.new(
  SimpleQuestionSignature,
  confidence_threshold: 0.75,
  max_backtrack_depth: 2,
  exploration_strategy: :adaptive
)

IO.puts("\n2. Adaptive Backtracking Result:")
case Dspy.Module.forward(adaptive_answerer, question_input) do
  {:ok, prediction} ->
    IO.puts("   Answer: #{prediction.attrs.answer}")
  {:error, reason} ->
    IO.puts("   Failed: #{inspect(reason)}")
end

IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

# Example 4: Custom Constraint Function
defmodule CustomConstraints do
  def requires_citations(step, inputs) do
    # Require citations for research-related questions
    reasoning = step.content
    question = Map.get(inputs, :question, "")
    
    if String.contains?(String.downcase(question), "research") or 
       String.contains?(String.downcase(question), "study") do
      String.contains?(reasoning, "according to") or 
      String.contains?(reasoning, "studies show") or
      String.contains?(reasoning, "research indicates")
    else
      true
    end
  end
end

research_solver = Dspy.AdaptiveBacktracking.new(
  SimpleQuestionSignature,
  confidence_threshold: 0.8,
  constraint_functions: [&CustomConstraints.requires_citations/2],
  exploration_strategy: :adaptive
)

research_input = %{
  question: "What does research say about the effectiveness of meditation for stress reduction?"
}

IO.puts("Research Question: #{research_input.question}")
IO.puts("(Note: This example requires citations in the reasoning)\n")

case Dspy.Module.forward(research_solver, research_input) do
  {:ok, prediction} ->
    IO.puts("Research Answer: #{prediction.attrs.answer}")
  {:error, reason} ->
    IO.puts("Failed (likely due to missing citations): #{inspect(reason)}")
end

IO.puts("\n=== Key Features Demonstrated ===")
IO.puts("✓ Confidence-based backtracking")
IO.puts("✓ Custom constraint validation")
IO.puts("✓ Multi-path exploration with memory")
IO.puts("✓ Adaptive depth control")
IO.puts("✓ Comparison with simple reflection")
IO.puts("✓ Different exploration strategies")