# Advanced Reasoning Examples with DSPy
# Demonstrates various sophisticated reasoning techniques

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
  api_key: System.get_env("OPENAI_API_KEY"),
  timeout: 120_000  # 2 minutes for complex reasoning
))

# Define problem signatures for different types of reasoning
defmodule ComplexMathQA do
  use Dspy.Signature
  
  signature_description "Solve complex mathematical problems with detailed reasoning"
  
  input_field :problem, :string, "Complex mathematical problem to solve"
  output_field :answer, :string, "Final numerical answer"
end

defmodule LogicalReasoning do
  use Dspy.Signature
  
  signature_description "Solve logical reasoning problems step by step"
  
  input_field :premise, :string, "Logical premise or scenario"
  input_field :question, :string, "Question to answer based on the premise"
  output_field :conclusion, :string, "Logical conclusion"
end

defmodule MultiStepProblem do
  use Dspy.Signature
  
  signature_description "Solve problems requiring multiple sequential steps"
  
  input_field :scenario, :string, "Problem scenario"
  output_field :final_result, :string, "Final result after all steps"
end

IO.puts("=== Testing Self-Consistency Reasoning ===")

# Self-Consistency: Generate multiple reasoning paths and select most consistent
self_consistency = Dspy.SelfConsistency.new(ComplexMathQA, num_samples: 5, temperature: 0.7)

case Dspy.Module.forward(self_consistency, %{
  problem: "A train travels 120 km in 1.5 hours, then slows down and travels 80 km in 2 hours. What is its average speed for the entire journey?"
}) do
  {:ok, prediction} -> 
    IO.puts("Self-Consistency Reasoning: #{prediction.attrs.reasoning}")
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Testing Multi-Step Reasoning ===")

# Multi-Step: Break complex problems into sequential steps
steps = [
  %{
    name: :identify_problem,
    signature: %{
      input_fields: [%{name: :scenario, type: :string, description: "Problem scenario", required: true, default: nil}],
      output_fields: [%{name: :problem_type, type: :string, description: "Type of problem identified", required: true, default: nil}],
      instructions: "Identify what type of problem this is and what needs to be solved."
    },
    description: "Identify the problem type",
    depends_on: []
  },
  %{
    name: :plan_solution,
    signature: %{
      input_fields: [
        %{name: :scenario, type: :string, description: "Problem scenario", required: true, default: nil},
        %{name: :problem_type, type: :string, description: "Identified problem type", required: true, default: nil}
      ],
      output_fields: [%{name: :solution_plan, type: :string, description: "Step-by-step solution plan", required: true, default: nil}],
      instructions: "Create a detailed plan to solve this problem."
    },
    description: "Create solution plan",
    depends_on: [:identify_problem]
  },
  %{
    name: :execute_solution,
    signature: %{
      input_fields: [
        %{name: :scenario, type: :string, description: "Problem scenario", required: true, default: nil},
        %{name: :solution_plan, type: :string, description: "Solution plan to execute", required: true, default: nil}
      ],
      output_fields: [%{name: :final_result, type: :string, description: "Final result", required: true, default: nil}],
      instructions: "Execute the solution plan and provide the final result."
    },
    description: "Execute the solution",
    depends_on: [:plan_solution]
  }
]

multi_step = Dspy.MultiStep.new(steps)

case Dspy.Module.forward(multi_step, %{
  scenario: "A company has 150 employees. 40% work remotely, 35% work in the office, and the rest work hybrid. If hybrid workers spend 60% of their time in the office, what's the average daily office occupancy percentage?"
}) do
  {:ok, prediction} -> 
    IO.puts("Multi-Step Result: #{prediction.attrs.final_result}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Testing Reflection Reasoning ===")

# Reflection: Generate answer, then reflect and potentially revise
reflection = Dspy.Reflection.new(LogicalReasoning, max_reflections: 2)

case Dspy.Module.forward(reflection, %{
  premise: "All cats are mammals. All mammals are animals. Fluffy is a cat.",
  question: "Is Fluffy an animal? Explain your reasoning."
}) do
  {:ok, prediction} -> 
    IO.puts("Reflection Reasoning: #{prediction.attrs.reasoning}")
    IO.puts("Conclusion: #{prediction.attrs.conclusion}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Testing Program of Thoughts (PoT) ===")

# Program of Thoughts: Combine reasoning with executable code
pot = Dspy.ProgramOfThoughts.new(ComplexMathQA, executor: :elixir, language: :elixir)

case Dspy.Module.forward(pot, %{
  problem: "Calculate the compound interest on $1000 invested at 5% annual rate for 3 years, compounded annually."
}) do
  {:ok, prediction} -> 
    IO.puts("PoT Reasoning: #{prediction.attrs.reasoning}")
    IO.puts("Generated Code: #{prediction.attrs.code}")
    IO.puts("Execution Result: #{prediction.attrs.execution_result}")
    IO.puts("Final Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Testing Self-Correcting Chain of Thought ===")

# Self-Correcting CoT: Generate answer with confidence, then self-correct if needed
self_correcting = Dspy.SelfCorrectingCoT.new(ComplexMathQA, 
  max_corrections: 2, 
  correction_threshold: 0.8
)

case Dspy.Module.forward(self_correcting, %{
  problem: "A rectangle has a perimeter of 24 cm and an area of 32 cm². What are its dimensions?"
}) do
  {:ok, prediction} -> 
    IO.puts("Self-Correcting Reasoning: #{prediction.attrs.reasoning}")
    IO.puts("Confidence: #{prediction.attrs.confidence}")
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Testing Tree of Thoughts ===")

# Tree of Thoughts: Explore multiple reasoning paths in a tree structure
tree_of_thoughts = Dspy.TreeOfThoughts.new(ComplexMathQA, 
  num_thoughts: 3, 
  max_depth: 2,
  evaluation_strategy: :value_based
)

case Dspy.Module.forward(tree_of_thoughts, %{
  problem: "Find the maximum value of f(x) = -x² + 4x + 5 and determine where it occurs."
}) do
  {:ok, prediction} -> 
    IO.puts("Tree of Thoughts Answer: #{prediction.attrs.answer}")
    if Map.has_key?(prediction.attrs, :thought_path) do
      IO.puts("Best Reasoning Path: #{prediction.attrs.thought_path}")
    end
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Comparing Basic vs Advanced Reasoning ===")

# Compare basic Chain of Thought with advanced techniques
basic_cot = Dspy.ChainOfThought.new(ComplexMathQA)

test_problem = "A jar contains 20 red marbles, 15 blue marbles, and 10 green marbles. If you draw 3 marbles without replacement, what's the probability that all 3 are the same color?"

IO.puts("Test Problem: #{test_problem}")

IO.puts("\nBasic Chain of Thought:")
case Dspy.Module.forward(basic_cot, %{problem: test_problem}) do
  {:ok, prediction} -> 
    IO.puts("Reasoning: #{prediction.attrs.reasoning}")
    IO.puts("Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\nSelf-Consistency (5 samples):")
advanced_self_consistency = Dspy.SelfConsistency.new(ComplexMathQA, num_samples: 5)
case Dspy.Module.forward(advanced_self_consistency, %{problem: test_problem}) do
  {:ok, prediction} -> 
    IO.puts("Most Consistent Answer: #{prediction.attrs.answer}")
  {:error, reason} -> 
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Advanced Reasoning Demo Complete ===")
IO.puts("Available advanced reasoning modules:")
IO.puts("- Dspy.SelfConsistency: Multiple sampling for consistency")
IO.puts("- Dspy.MultiStep: Sequential step-by-step reasoning") 
IO.puts("- Dspy.Reflection: Self-reflection and revision")
IO.puts("- Dspy.ProgramOfThoughts: Reasoning + executable code")
IO.puts("- Dspy.SelfCorrectingCoT: Chain of thought with self-correction")
IO.puts("- Dspy.TreeOfThoughts: Tree exploration of reasoning paths")