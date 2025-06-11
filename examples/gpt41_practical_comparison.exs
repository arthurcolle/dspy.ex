#!/usr/bin/env elixir

# GPT-4.1 Practical Comparison
# ============================
# Real-world comparison of GPT-4.1 models for different use cases

Code.prepend_path("_build/dev/lib/dspy/ebin")

alias Dspy.{Config.GPT41, ChainOfThought, Signature, Module}

unless System.get_env("OPENAI_API_KEY") do
  IO.puts("❌ Please set OPENAI_API_KEY environment variable")
  System.halt(1)
end

# Define practical use cases
defmodule CodeReview do
  use Dspy.Signature
  
  signature_description "Review code and suggest improvements"
  
  input_field :code, :string, "Code snippet to review"
  input_field :language, :string, "Programming language"
  output_field :issues, :string, "Identified issues"
  output_field :suggestions, :string, "Improvement suggestions"
end

defmodule DataAnalysis do
  use Dspy.Signature
  
  signature_description "Analyze data and provide insights"
  
  input_field :data_description, :string, "Description of the data"
  input_field :question, :string, "Analysis question"
  output_field :insight, :string, "Key insight from the data"
  output_field :recommendation, :string, "Recommended action"
end

defmodule EmailDraft do
  use Dspy.Signature
  
  signature_description "Draft a professional email"
  
  input_field :context, :string, "Email context and purpose"
  input_field :tone, :string, "Desired tone (formal/casual)"
  output_field :subject, :string, "Email subject line"
  output_field :body, :string, "Email body content"
end

# Test cases for each use case
test_cases = [
  %{
    name: "🔍 Code Review (Complex Task - Best for Flagship)",
    signature: CodeReview,
    input: %{
      code: """
      def calculate_total(items) do
        total = 0
        for item <- items do
          total = total + item.price * item.quantity
        end
        total
      end
      """,
      language: "Elixir"
    }
  },
  %{
    name: "📊 Data Analysis (Medium Complexity - Good for Mini)",
    signature: DataAnalysis,
    input: %{
      data_description: "Monthly sales data showing 20% decline in Q3 after new competitor entered market",
      question: "What strategies could reverse the sales decline?"
    }
  },
  %{
    name: "✉️ Email Draft (Simple Task - Perfect for Nano)",
    signature: EmailDraft,
    input: %{
      context: "Following up with client about project deadline extension request",
      tone: "formal"
    }
  }
]

# Model configurations
models = [
  %{name: "gpt-4.1", config: &GPT41.configure_flagship/0, best_for: "Complex reasoning"},
  %{name: "gpt-4.1-mini", config: &GPT41.configure_mini/0, best_for: "General tasks"},
  %{name: "gpt-4.1-nano", config: &GPT41.configure_nano/0, best_for: "Simple tasks"}
]

IO.puts """
🎯 GPT-4.1 Practical Use Case Comparison
========================================
Testing real-world scenarios with each model variant...
"""

# Run each test case
for test <- test_cases do
  IO.puts "\n\n#{test.name}"
  IO.puts String.duplicate("=", 70)
  
  results = for model <- models do
    IO.write "\n#{model.name} (#{model.best_for})... "
    
    start_time = System.monotonic_time(:millisecond)
    
    result = 
      case model.config.() do
        {:ok, _} ->
          module = ChainOfThought.new(test.signature)
          
          case Module.forward(module, test.input) do
            {:ok, prediction} ->
              end_time = System.monotonic_time(:millisecond)
              duration = end_time - start_time
              
              IO.puts "✅ #{duration}ms"
              
              %{
                model: model.name,
                success: true,
                duration: duration,
                result: prediction.attrs
              }
            
            {:error, reason} ->
              IO.puts "❌ Error"
              %{
                model: model.name,
                success: false,
                error: inspect(reason)
              }
          end
        
        {:error, reason} ->
          IO.puts "❌ Config failed"
          %{
            model: model.name,
            success: false,
            error: "Config: #{inspect(reason)}"
          }
      end
    
    result
  end
  
  # Show successful results
  IO.puts "\n📋 Results:"
  for result <- results, result.success do
    IO.puts "\n#{result.model}:"
    
    case test.signature do
      CodeReview ->
        IO.puts "Issues: #{String.slice(result.result.issues, 0, 100)}..."
        IO.puts "Suggestions: #{String.slice(result.result.suggestions, 0, 100)}..."
      
      DataAnalysis ->
        IO.puts "Insight: #{result.result.insight}"
        IO.puts "Recommendation: #{String.slice(result.result.recommendation, 0, 100)}..."
      
      EmailDraft ->
        IO.puts "Subject: #{result.result.subject}"
        IO.puts "Body: #{String.slice(result.result.body, 0, 100)}..."
    end
    
    IO.puts "⏱️  Time: #{result.duration}ms"
  end
end

# Summary
IO.puts "\n\n📈 Performance Summary"
IO.puts String.duplicate("=", 70)
IO.puts """
Model Selection Guidelines:
• gpt-4.1 (flagship): Complex reasoning, code analysis, critical decisions
• gpt-4.1-mini: General purpose, balanced tasks, most workflows  
• gpt-4.1-nano: Simple tasks, high volume, cost-sensitive operations

The examples above demonstrate how each model performs on tasks of varying complexity.
Choose based on your specific needs for accuracy, speed, and cost.
"""