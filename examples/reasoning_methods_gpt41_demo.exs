#!/usr/bin/env elixir

# Add the lib directory to the path
Code.prepend_path("_build/dev/lib/dspy/ebin")

alias Dspy.{Signature, LM, Prediction, DynamicSchemaGenerator, Config.GPT41}

# Ensure OPENAI_API_KEY is set
unless System.get_env("OPENAI_API_KEY") do
  IO.puts("❌ Error: OPENAI_API_KEY environment variable not set")
  System.halt(1)
end

IO.puts """
🧠 DSPy Reasoning Methods with GPT-4.1 Models
=============================================================
Comparing reasoning capabilities across GPT-4.1 variants...
"""

# Test configurations
models = [
  {"gpt-4.1", &GPT41.configure_flagship/0},
  {"gpt-4.1-mini", &GPT41.configure_mini/0},
  {"gpt-4.1-nano", &GPT41.configure_nano/0}
]

# Define test signatures
defmodule SpeedCalculation do
  use Dspy.Signature
  
  signature_description "Calculate speed from distance and time"
  
  input_field :problem, :string, "A speed calculation problem"
  output_field :speed, :number, "The calculated speed"
  output_field :unit, :string, "The unit of speed (e.g., mph, km/h)"
end

defmodule CostCalculator do
  use Dspy.Signature
  
  signature_description "Calculate total cost with tax and discount"
  
  input_field :item_cost, :number, "Base cost of the item"
  input_field :tax_rate, :number, "Tax rate as a percentage"
  input_field :discount_rate, :number, "Discount rate as a percentage"
  output_field :final_cost, :number, "Final total cost after tax and discount"
  output_field :breakdown, :string, "Step-by-step calculation breakdown"
end

defmodule SafetyAssessor do
  use Dspy.Signature
  
  signature_description "Assess safety of activities during weather conditions"
  
  input_field :situation, :string, "A safety scenario to evaluate"
  output_field :is_safe, :boolean, "Whether the situation is safe"
  output_field :reasoning, :string, "Safety reasoning and recommendations"
end

# Run tests with each model
for {model_name, config_fn} <- models do
  IO.puts "\n\n🤖 Testing with #{model_name}"
  IO.puts "=" <> String.duplicate("=", 60)
  
  case config_fn.() do
    {:ok, _config} ->
      # Test 1: Self-Consistency - Speed Calculation
      IO.puts "\n1️⃣ SELF-CONSISTENCY - Speed Calculation"
      IO.puts "-" <> String.duplicate("-", 40)
      
      alias Dspy.SelfConsistency
      sc_module = SelfConsistency.new(SpeedCalculation, num_samples: 3)
      
      case Dspy.Module.forward(sc_module, %{
        problem: "A train travels 120 miles in 2 hours. What's its speed?"
      }) do
        {:ok, result} ->
          IO.puts "Speed: #{result.attrs.speed} #{result.attrs.unit}"
          IO.puts "Consensus from 3 reasoning attempts"
        
        {:error, reason} ->
          IO.puts "Error: #{inspect(reason)}"
      end
      
      # Test 2: Chain of Thought - Cost Calculation
      IO.puts "\n2️⃣ CHAIN OF THOUGHT - Cost Calculation"
      IO.puts "-" <> String.duplicate("-", 40)
      
      alias Dspy.ChainOfThought
      cot_module = ChainOfThought.new(CostCalculator)
      
      case Dspy.Module.forward(cot_module, %{
        item_cost: 100,
        tax_rate: 8,
        discount_rate: 20
      }) do
        {:ok, result} ->
          IO.puts "Final cost: $#{result.attrs.final_cost}"
          IO.puts "Breakdown: #{result.attrs.breakdown}"
        
        {:error, reason} ->
          IO.puts "Error: #{inspect(reason)}"
      end
      
      # Test 3: Reflection - Safety Assessment
      IO.puts "\n3️⃣ REFLECTION - Safety Assessment"
      IO.puts "-" <> String.duplicate("-", 40)
      
      alias Dspy.Reflection
      reflection_module = Reflection.new(SafetyAssessor)
      
      case Dspy.Module.forward(reflection_module, %{
        situation: "Swimming when lightning was seen 5 seconds ago"
      }) do
        {:ok, result} ->
          IO.puts "Safe? #{result.attrs.is_safe}"
          IO.puts "Reasoning: #{result.attrs.reasoning}"
        
        {:error, reason} ->
          IO.puts "Error: #{inspect(reason)}"
      end
    
    {:error, reason} ->
      IO.puts "Failed to configure #{model_name}: #{inspect(reason)}"
  end
end

IO.puts "\n\n✨ Demo complete! GPT-4.1 models successfully demonstrated reasoning capabilities."