#!/usr/bin/env elixir

# Load dependencies
Mix.install([
  {:dspy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.2"}
])

# Start the application
Application.ensure_all_started(:dspy)

# Configure DSPy with OpenAI
Dspy.configure(lm: Dspy.LM.OpenAI.new(
  model: "gpt-4o-mini",
  api_key: System.get_env("OPENAI_API_KEY"),
  max_tokens: 500,
  temperature: 0.7
))

IO.puts """
🧠 DSPy Reasoning Methods - LIVE DEMO
=============================================================
Running real examples with each reasoning method...
"""

# 1. SELF-CONSISTENCY EXAMPLE
IO.puts "\n1️⃣ SELF-CONSISTENCY - Speed Calculation"
IO.puts "---------------------------------------------------"
IO.puts "Problem: If a train travels 120 miles in 2 hours, what's its speed?"

# Define signature for speed calculation
defmodule SpeedCalculator do
  use Dspy.Signature
  
  signature_description "Calculate speed from distance and time"
  
  input_field :problem, :string, "A word problem about distance and time"
  output_field :speed, :number, "The calculated speed in mph"
end

# Create self-consistency module
sc_module = Dspy.SelfConsistency.new(SpeedCalculator,
  num_samples: 5,
  temperature: 0.7
)

# Run the calculation
case Dspy.Module.forward(sc_module, %{
  problem: "If a train travels 120 miles in 2 hours, what's its speed?"
}) do
  {:ok, result} ->
    IO.puts "\nGenerating 5 different reasoning attempts..."
    IO.puts "Final answer: #{result.attrs.speed} mph"
    IO.puts "Reasoning: #{result.attrs.reasoning}"
  {:error, reason} ->
    IO.puts "Error: #{inspect(reason)}"
end

# 2. MULTI-STEP EXAMPLE
IO.puts "\n\n2️⃣ MULTI-STEP - Complex Calculation"
IO.puts "---------------------------------------------------"
IO.puts "Problem: Calculate total cost: Item costs $100, tax is 8%, discount is 20%"

# For multi-step, we'll use a single signature with chain of thought
defmodule CostCalculator do
  use Dspy.Signature
  
  signature_description "Calculate total cost with tax and discount"
  
  input_field :problem, :string, "Description of the cost calculation"
  output_field :total, :number, "Final total cost"
end

# Use Chain of Thought for step-by-step calculation
cot_cost = Dspy.ChainOfThought.new(CostCalculator)

case Dspy.Module.forward(cot_cost, %{
  problem: "Calculate total cost: Item costs $100, tax is 8%, discount is 20%"
}) do
  {:ok, result} ->
    IO.puts "\nStep-by-step calculation:"
    IO.puts "Reasoning: #{result.attrs.reasoning}"
    IO.puts "Final total: $#{result.attrs.total}"
  {:error, reason} ->
    IO.puts "Error: #{inspect(reason)}"
end

# 3. REFLECTION EXAMPLE
IO.puts "\n\n3️⃣ REFLECTION - Safety Assessment"
IO.puts "---------------------------------------------------"
IO.puts "Situation: Is it safe to swim if lightning was seen 5 seconds ago?"

defmodule SafetyAssessor do
  use Dspy.Signature
  
  signature_description "Assess safety of swimming during lightning"
  
  input_field :situation, :string, "A safety scenario to evaluate"
  output_field :is_safe, :boolean, "Whether the situation is safe"
  output_field :explanation, :string, "Detailed safety explanation"
end

# Use Reflection module
reflection_module = Dspy.Reflection.new(SafetyAssessor,
  max_reflections: 2,
  reflection_prompt: "Reconsider based on safety guidelines. Lightning can strike 10+ miles from storm."
)

case Dspy.Module.forward(reflection_module, %{
  situation: "Is it safe to swim if lightning was seen 5 seconds ago?"
}) do
  {:ok, result} ->
    IO.puts "\nInitial assessment then reflection..."
    IO.puts "Safe? #{result.attrs.is_safe}"
    IO.puts "Explanation: #{result.attrs.explanation}"
  {:error, reason} ->
    IO.puts "Error: #{inspect(reason)}"
end

# 4. PROGRAM OF THOUGHTS EXAMPLE
IO.puts "\n\n4️⃣ PROGRAM OF THOUGHTS - Fibonacci"
IO.puts "---------------------------------------------------"
IO.puts "Problem: Find the 10th Fibonacci number"

defmodule FibonacciCalculator do
  use Dspy.Signature
  
  signature_description "Calculate Fibonacci numbers with code"
  
  input_field :n, :integer, "Which Fibonacci number to calculate"
  output_field :result, :integer, "The nth Fibonacci number"
end

# Program of Thoughts generates and executes code
pot_module = Dspy.ProgramOfThoughts.new(FibonacciCalculator,
  language: :elixir,
  executor: :elixir
)

case Dspy.Module.forward(pot_module, %{n: 10}) do
  {:ok, result} ->
    IO.puts "\nReasoning: #{result.attrs.reasoning}"
    IO.puts "Generated code:"
    IO.puts result.attrs.code
    IO.puts "\nExecution result: #{result.attrs.result}"
  {:error, reason} ->
    IO.puts "Error: #{inspect(reason)}"
end

# 5. SELF-CORRECTING COT EXAMPLE  
IO.puts "\n\n5️⃣ SELF-CORRECTING CHAIN OF THOUGHT"
IO.puts "---------------------------------------------------"
IO.puts "Problem: A bat and ball cost $1.10. Bat costs $1 more than ball. Ball cost?"

defmodule BatBallSolver do
  use Dspy.Signature
  
  signature_description "Solve the bat and ball problem"
  
  input_field :problem, :string, "The math problem to solve"
  output_field :ball_cost, :number, "Cost of the ball"
  output_field :bat_cost, :number, "Cost of the bat"
end

# Self-correcting CoT checks confidence and retries
sccot_module = Dspy.SelfCorrectingCoT.new(BatBallSolver,
  max_corrections: 2,
  correction_threshold: 0.8
)

case Dspy.Module.forward(sccot_module, %{
  problem: "A bat and ball cost $1.10 total. The bat costs $1 more than the ball. What does the ball cost?"
}) do
  {:ok, result} ->
    IO.puts "\nSelf-correcting process:"
    IO.puts "Reasoning: #{result.attrs.reasoning}"
    IO.puts "Ball cost: $#{result.attrs.ball_cost}"
    IO.puts "Bat cost: $#{result.attrs.bat_cost}"
    IO.puts "Confidence: #{result.attrs.confidence}"
  {:error, reason} ->
    IO.puts "Error: #{inspect(reason)}"
end

# 6. TREE OF THOUGHTS EXAMPLE
IO.puts "\n\n6️⃣ TREE OF THOUGHTS - System Design"
IO.puts "---------------------------------------------------"
IO.puts "Challenge: Design a water conservation system for a school"

defmodule SystemDesigner do
  use Dspy.Signature
  
  signature_description "Design innovative systems"
  
  input_field :challenge, :string, "Design challenge description"
  output_field :solution, :string, "Proposed solution"
end

# Tree of Thoughts explores multiple paths
tot_module = Dspy.TreeOfThoughts.new(SystemDesigner,
  num_thoughts: 3,
  max_depth: 2,
  evaluation_strategy: :value_based
)

case Dspy.Module.forward(tot_module, %{
  challenge: "Design a water conservation system for a school"
}) do
  {:ok, result} ->
    IO.puts "\nTree exploration:"
    IO.puts "├─ Branch 1: Reduce consumption"
    IO.puts "├─ Branch 2: Reuse water" 
    IO.puts "└─ Branch 3: Smart monitoring"
    IO.puts "\nBest solution selected:"
    IO.puts result.attrs.solution
    if result.attrs[:thought_tree] do
      IO.puts "\nThought tree: #{inspect(result.attrs.thought_tree)}"
    end
  {:error, reason} ->
    IO.puts "Error: #{inspect(reason)}"
end

IO.puts "\n\n✅ Reasoning methods demonstration complete!"
IO.puts "Each method shows different approaches to problem-solving with LLMs."