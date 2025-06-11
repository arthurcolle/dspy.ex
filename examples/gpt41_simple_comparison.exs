#!/usr/bin/env elixir

# Simple GPT-4.1 Models Comparison
# ================================
# Quick demonstration of using all three GPT-4.1 variants

# Add the lib directory to the path
Code.prepend_path("_build/dev/lib/dspy/ebin")

# Start the application
Application.ensure_all_started(:dspy)

alias Dspy.{Config.GPT41, Predict, Signature}

# Ensure API key is set
unless System.get_env("OPENAI_API_KEY") do
  IO.puts("❌ Error: OPENAI_API_KEY environment variable not set")
  System.halt(1)
end

# Define a simple question-answering signature
defmodule SimpleQA do
  use Dspy.Signature
  
  signature_description "Answer a question concisely"
  
  input_field :question, :string, "A question to answer"
  output_field :answer, :string, "The answer to the question"
end

# Test question
test_question = "What are the main advantages of using Elixir for building concurrent applications?"

IO.puts """
🔬 GPT-4.1 Models Simple Comparison
====================================
Question: #{test_question}
"""

# Test each model
models = [
  {"gpt-4.1 (flagship)", &GPT41.configure_flagship/0},
  {"gpt-4.1-mini", &GPT41.configure_mini/0},
  {"gpt-4.1-nano", &GPT41.configure_nano/0}
]

for {model_name, config_fn} <- models do
  IO.puts "\n" <> String.duplicate("-", 60)
  IO.puts "🤖 #{model_name}"
  IO.puts String.duplicate("-", 60)
  
  start_time = System.monotonic_time(:millisecond)
  
  case config_fn.() do
    {:ok, _config} ->
      # Create a simple predict module
      predict = Predict.new(SimpleQA)
      
      # Run the prediction
      case Dspy.Module.forward(predict, %{question: test_question}) do
        {:ok, result} ->
          end_time = System.monotonic_time(:millisecond)
          duration = end_time - start_time
          
          IO.puts "Answer: #{result.attrs.answer}"
          IO.puts "\n⏱️  Response time: #{duration}ms"
        
        {:error, reason} ->
          IO.puts "❌ Error: #{inspect(reason)}"
      end
    
    {:error, reason} ->
      IO.puts "❌ Configuration failed: #{inspect(reason)}"
  end
end

# Advanced example with structured reasoning
IO.puts "\n\n🧠 Advanced: Structured Reasoning Comparison"
IO.puts "=" <> String.duplicate("=", 60)

defmodule ReasoningTask do
  use Dspy.Signature
  
  signature_description "Solve a problem with step-by-step reasoning"
  
  input_field :problem, :string, "A problem to solve"
  output_field :solution, :string, "The solution"
  output_field :steps, :string, "Key reasoning steps taken"
end

problem = "If you have 3 apples and buy 2 more bags with 5 apples each, how many apples total?"

IO.puts "\nProblem: #{problem}"

for {model_name, config_fn} <- models do
  IO.puts "\n🤖 #{model_name}:"
  
  case config_fn.() do
    {:ok, _config} ->
      cot = Dspy.ChainOfThought.new(ReasoningTask)
      
      case Dspy.Module.forward(cot, %{problem: problem}) do
        {:ok, result} ->
          IO.puts "Solution: #{result.attrs.solution}"
          IO.puts "Steps: #{result.attrs.steps}"
        
        {:error, reason} ->
          IO.puts "Error: #{inspect(reason)}"
      end
    
    {:error, _} ->
      IO.puts "Configuration failed"
  end
end

IO.puts "\n✨ Comparison complete!"