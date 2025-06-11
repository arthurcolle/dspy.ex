#!/usr/bin/env elixir

# GPT-4.1 Model Comparison Example
# ================================
# This example demonstrates using all three GPT-4.1 variants
# (flagship, mini, nano) for the same reasoning tasks to compare
# their performance, speed, and cost-effectiveness.

# Ensure OPENAI_API_KEY is set in your environment
unless System.get_env("OPENAI_API_KEY") do
  IO.puts("❌ Error: OPENAI_API_KEY environment variable not set")
  IO.puts("Please set it: export OPENAI_API_KEY='your-key-here'")
  System.halt(1)
end

# Add the lib directory to the path
Code.prepend_path("_build/dev/lib/dspy/ebin")

alias Dspy.{Signature, ChainOfThought, Module, Settings, Config.GPT41}

# Define test signatures
defmodule MathProblem do
  use Dspy.Signature
  
  signature_description "Solve a mathematical problem"
  
  input_field :problem, :string, "A math problem to solve"
  output_field :answer, :number, "The numerical answer"
  output_field :explanation, :string, "Brief explanation of the solution"
end

defmodule LogicPuzzle do
  use Dspy.Signature
  
  signature_description "Solve a logic puzzle"
  
  input_field :puzzle, :string, "A logic puzzle to solve"
  output_field :solution, :string, "The solution to the puzzle"
  output_field :steps, :string, "Key reasoning steps"
end

defmodule CreativeTask do
  use Dspy.Signature
  
  signature_description "Generate creative content"
  
  input_field :task, :string, "A creative task description"
  output_field :result, :string, "The creative output"
  output_field :explanation, :string, "Explanation of creative choices"
end

# Test problems
test_problems = [
  %{
    type: :math,
    input: %{problem: "If a train travels at 60 mph for 2.5 hours, then 80 mph for 1.5 hours, what's the total distance?"},
    module: ChainOfThought.new(MathProblem)
  },
  %{
    type: :logic,
    input: %{puzzle: "Three boxes labeled 'Apples', 'Oranges', and 'Mixed'. All labels are wrong. You can pick one fruit from one box. How do you correctly label all boxes?"},
    module: ChainOfThought.new(LogicPuzzle)
  },
  %{
    type: :creative,
    input: %{task: "Create a haiku about artificial intelligence that captures both its promise and limitations"},
    module: ChainOfThought.new(CreativeTask)
  }
]

# Function to run a test with a specific model
defp run_test_with_model(model_name, config_fn, test) do
  start_time = System.monotonic_time(:millisecond)
  
  # Configure the model
  case config_fn.() do
    {:ok, config} ->
      # Run the test
      result = Module.forward(test.module, test.input)
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      case result do
        {:ok, prediction} ->
          %{
            model: model_name,
            type: test.type,
            success: true,
            duration_ms: duration,
            result: prediction.attrs
          }
        
        {:error, reason} ->
          %{
            model: model_name,
            type: test.type,
            success: false,
            duration_ms: duration,
            error: inspect(reason)
          }
      end
    
    {:error, reason} ->
      %{
        model: model_name,
        type: test.type,
        success: false,
        duration_ms: 0,
        error: "Configuration failed: #{inspect(reason)}"
      }
  end
end

# Print header
IO.puts """
🔬 GPT-4.1 Model Comparison
====================================
Running identical reasoning tasks on all three GPT-4.1 variants...
"""

# Print model info
GPT41.print_comparison()

# Run tests for each model
models = [
  {"gpt-4.1 (flagship)", &GPT41.configure_flagship/0},
  {"gpt-4.1-mini", &GPT41.configure_mini/0},
  {"gpt-4.1-nano", &GPT41.configure_nano/0}
]

all_results = 
  for {model_name, config_fn} <- models do
    IO.puts "\n🤖 Testing #{model_name}..."
    IO.puts String.duplicate("-", 50)
    
    results = 
      for test <- test_problems do
        IO.write "  Running #{test.type} test... "
        result = run_test_with_model(model_name, config_fn, test)
        
        if result.success do
          IO.puts "✅ (#{result.duration_ms}ms)"
        else
          IO.puts "❌ Error: #{result.error}"
        end
        
        result
      end
    
    {model_name, results}
  end

# Display detailed results
IO.puts "\n\n📊 Detailed Results"
IO.puts "=" <> String.duplicate("=", 70)

for {model_name, results} <- all_results do
  IO.puts "\n#{model_name}:"
  
  for result <- results do
    case result.type do
      :math when result.success ->
        IO.puts """
        
        📐 Math Problem:
        Answer: #{result.result[:answer]}
        Explanation: #{result.result[:explanation]}
        Time: #{result.duration_ms}ms
        """
      
      :logic when result.success ->
        IO.puts """
        
        🧩 Logic Puzzle:
        Solution: #{result.result[:solution]}
        Steps: #{result.result[:steps]}
        Time: #{result.duration_ms}ms
        """
      
      :creative when result.success ->
        IO.puts """
        
        🎨 Creative Task:
        Result: #{result.result[:result]}
        Explanation: #{result.result[:explanation]}
        Time: #{result.duration_ms}ms
        """
      
      _ ->
        if not result.success do
          IO.puts "\n❌ #{result.type} failed: #{result.error}"
        end
    end
  end
end

# Performance comparison
IO.puts "\n\n⚡ Performance Summary"
IO.puts "=" <> String.duplicate("=", 70)

for {model_name, results} <- all_results do
  successful = Enum.filter(results, & &1.success)
  avg_time = 
    if length(successful) > 0 do
      total = Enum.sum(Enum.map(successful, & &1.duration_ms))
      Float.round(total / length(successful), 2)
    else
      0
    end
  
  success_rate = Float.round(length(successful) / length(results) * 100, 1)
  
  IO.puts "#{model_name}: #{success_rate}% success rate, avg #{avg_time}ms per task"
end

IO.puts "\n✨ Comparison complete!"