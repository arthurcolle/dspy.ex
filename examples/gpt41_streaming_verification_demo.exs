#!/usr/bin/env elixir

# GPT-4.1 Streaming with Token Aggregation and Chain of Thought Verification Demo
# This example demonstrates the complete implementation of streaming, aggregation, and verification

Mix.install([
  {:dspy, path: Path.expand("..")}
])

defmodule GPT41StreamingDemo do
  @moduledoc """
  Comprehensive demonstration of GPT-4.1 streaming capabilities with:
  - Real-time streaming
  - Token aggregation
  - Chain of thought verification
  - Enhanced visualization
  """

  def run_complete_demo do
    IO.puts("🚀 Starting GPT-4.1 Streaming with Verification Demo")
    IO.puts("=" <> String.duplicate("=", 60))
    
    # Start the enhanced streaming visualization server
    {:ok, _pid} = Dspy.EnhancedStreamingVisualization.start_link()
    
    # Demo all three GPT-4.1 models
    models = ["gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"]
    
    Enum.each(models, fn model ->
      IO.puts("\n📊 Testing model: #{model}")
      run_model_demo(model)
      Process.sleep(2000)  # Brief pause between models
    end)
    
    # Show final statistics
    show_final_statistics()
  end
  
  defp run_model_demo(model) do
    case configure_model(model) do
      {:ok, client} ->
        # Test different types of reasoning tasks
        test_mathematical_reasoning(client, model)
        test_logical_reasoning(client, model)
        test_creative_problem_solving(client, model)
      
      {:error, reason} ->
        IO.puts("❌ Failed to configure #{model}: #{inspect(reason)}")
    end
  end
  
  defp configure_model("gpt-4.1"), do: Dspy.Config.GPT41.configure_flagship()
  defp configure_model("gpt-4.1-mini"), do: Dspy.Config.GPT41.configure_mini()
  defp configure_model("gpt-4.1-nano"), do: Dspy.Config.GPT41.configure_nano()
  
  defp test_mathematical_reasoning(client, model) do
    IO.puts("\n🧮 Testing Mathematical Reasoning with #{model}")
    
    prompt = """
    <think>
    I need to solve this step by step:
    What is 17 * 23 + 45 / 5 - 12?
    
    First, I'll follow order of operations (PEMDAS):
    1. Multiplication and Division first (left to right)
    2. Then Addition and Subtraction (left to right)
    </think>
    
    Solve this mathematical expression step by step: 17 * 23 + 45 / 5 - 12
    
    Show your reasoning process clearly.
    """
    
    request = %{
      messages: [
        %{role: "user", content: prompt}
      ],
      temperature: 0.1,
      max_tokens: 1000
    }
    
    case Dspy.LM.OpenAI.generate_with_verification(client, request, 
      streaming: true, 
      aggregation: true, 
      verification: true
    ) do
      {:ok, result} ->
        display_verification_results(result, "Mathematical Reasoning")
      
      {:error, reason} ->
        IO.puts("❌ Error in mathematical reasoning: #{inspect(reason)}")
    end
  end
  
  defp test_logical_reasoning(client, model) do
    IO.puts("\n🤔 Testing Logical Reasoning with #{model}")
    
    prompt = """
    <think>
    This is a logical reasoning problem. Let me analyze it carefully:
    
    Given the premises:
    1. All birds can fly
    2. Penguins are birds
    3. Penguins cannot fly
    
    There seems to be a logical inconsistency here. Let me work through this...
    </think>
    
    Analyze this logical paradox:
    - All birds can fly
    - Penguins are birds  
    - Penguins cannot fly
    
    Identify the logical inconsistency and propose a resolution.
    """
    
    request = %{
      messages: [
        %{role: "user", content: prompt}
      ],
      temperature: 0.3,
      max_tokens: 1200
    }
    
    case Dspy.LM.OpenAI.generate_with_verification(client, request,
      streaming: true,
      aggregation: true, 
      verification: true
    ) do
      {:ok, result} ->
        display_verification_results(result, "Logical Reasoning")
      
      {:error, reason} ->
        IO.puts("❌ Error in logical reasoning: #{inspect(reason)}")
    end
  end
  
  defp test_creative_problem_solving(client, model) do
    IO.puts("\n🎨 Testing Creative Problem Solving with #{model}")
    
    prompt = """
    <think>
    This is an interesting creative challenge. I need to think outside the box here.
    
    The goal is to design a solution that's both practical and innovative.
    Let me consider multiple approaches and evaluate their feasibility.
    </think>
    
    Design an innovative solution for reducing food waste in restaurants.
    Consider technological, operational, and community-based approaches.
    
    Provide a detailed implementation plan with reasoning for each component.
    """
    
    request = %{
      messages: [
        %{role: "user", content: prompt}
      ],
      temperature: 0.7,
      max_tokens: 1500
    }
    
    case Dspy.LM.OpenAI.generate_with_verification(client, request,
      streaming: true,
      aggregation: true,
      verification: true
    ) do
      {:ok, result} ->
        display_verification_results(result, "Creative Problem Solving")
      
      {:error, reason} ->
        IO.puts("❌ Error in creative problem solving: #{inspect(reason)}")
    end
  end
  
  defp display_verification_results(result, test_type) do
    IO.puts("\n📋 Verification Results for #{test_type}")
    IO.puts("─" <> String.duplicate("─", 50))
    
    # Display aggregated content length
    IO.puts("📝 Total Content Length: #{String.length(result.complete_text)} characters")
    IO.puts("🔢 Total Tokens Processed: #{length(result.aggregated_tokens)}")
    
    # Display verification steps
    if length(result.verification_steps) > 0 do
      IO.puts("\n🔍 Real-time Verification Steps:")
      Enum.with_index(result.verification_steps, 1)
      |> Enum.each(fn {step, index} ->
        IO.puts("  #{index}. Quality: #{Float.round(step.step_quality, 2)} | " <>
                "Consistency: #{Float.round(step.logical_consistency.overall_consistency, 2)}")
      end)
    end
    
    # Display final verification
    if result.final_verification do
      verification = result.final_verification
      IO.puts("\n📊 Final Verification Analysis:")
      IO.puts("  • Reasoning Steps Found: #{verification.reasoning_steps_found}")
      IO.puts("  • Logical Flow Score: #{Float.round(verification.logical_flow_score, 2)}/1.0")
      IO.puts("  • Completeness Score: #{Float.round(verification.completeness_score, 2)}/1.0")
      IO.puts("  • Coherence Score: #{Float.round(verification.coherence_score, 2)}/1.0")
      
      # Calculate overall quality score
      overall_score = (verification.logical_flow_score + 
                      verification.completeness_score + 
                      verification.coherence_score) / 3.0
      
      quality_rating = case overall_score do
        score when score >= 0.8 -> "🟢 Excellent"
        score when score >= 0.6 -> "🟡 Good"
        score when score >= 0.4 -> "🟠 Fair"
        _ -> "🔴 Needs Improvement"
      end
      
      IO.puts("  • Overall Quality: #{Float.round(overall_score, 2)}/1.0 #{quality_rating}")
    end
    
    # Display sample of aggregated content
    IO.puts("\n📄 Content Preview (first 200 characters):")
    preview = result.complete_text |> String.slice(0, 200)
    IO.puts("  \"#{preview}#{if String.length(result.complete_text) > 200, do: "...", else: ""}\"")
  end
  
  defp show_final_statistics do
    case Dspy.EnhancedStreamingVisualization.get_streaming_stats() do
      stats ->
        IO.puts("\n🎯 Final Demo Statistics")
        IO.puts("=" <> String.duplicate("=", 40))
        IO.puts("📊 Total Streams Processed: #{stats.total_streams}")
        IO.puts("⚡ Active Streams: #{stats.active_streams}")
        IO.puts("⏱️  Total Demo Runtime: #{stats.uptime}ms")
        
        if stats.global_metrics do
          metrics = stats.global_metrics
          IO.puts("📈 Global Metrics:")
          IO.puts("  • Total Characters: #{metrics.total_characters}")
          IO.puts("  • Total Chunks: #{metrics.total_chunks}")
          IO.puts("  • Avg Performance: #{Float.round(metrics.average_stream_performance, 1)} chars/stream")
          IO.puts("  • Collective Throughput: #{Float.round(metrics.collective_throughput, 2)} chars/ms")
        end
        
        if stats.performance_summary do
          summary = stats.performance_summary
          IO.puts("\n🏆 Performance Leaders:")
          
          if summary.fastest_stream do
            IO.puts("  • Fastest Stream: #{summary.fastest_stream.id}")
          end
          
          if summary.most_productive_stream do
            IO.puts("  • Most Productive: #{summary.most_productive_stream.id}")
          end
          
          if summary.quality_leader do
            IO.puts("  • Highest Quality: #{summary.quality_leader.id}")
          end
        end
    end
  end
  
  def run_concurrent_demo do
    IO.puts("\n🔄 Running Concurrent Streaming Demo")
    IO.puts("=" <> String.duplicate("=", 50))
    
    # Start enhanced streaming visualization
    {:ok, _pid} = Dspy.EnhancedStreamingVisualization.start_link()
    
    # Configure multiple models concurrently
    configs = [
      %{id: "flagship", model: "gpt-4.1", mode: "complex_reasoning"},
      %{id: "mini", model: "gpt-4.1-mini", mode: "balanced_processing"},
      %{id: "nano", model: "gpt-4.1-nano", mode: "fast_inference"}
    ]
    
    # Start concurrent visualization
    Dspy.EnhancedStreamingVisualization.start_concurrent_visualization(configs)
    
    # Run concurrent tasks
    tasks = Enum.map(configs, fn config ->
      Task.async(fn ->
        case configure_model(config.model) do
          {:ok, client} ->
            prompt = """
            <think>
            I'm processing this as part of a concurrent demonstration.
            Let me provide a thoughtful response about #{config.mode}.
            </think>
            
            Explain the benefits of #{config.mode} in AI systems.
            Consider performance, accuracy, and practical applications.
            """
            
            request = %{
              messages: [%{role: "user", content: prompt}],
              temperature: 0.5,
              max_tokens: 800
            }
            
            Dspy.LM.OpenAI.generate_with_verification(client, request,
              streaming: true,
              aggregation: true,
              verification: true
            )
          
          {:error, reason} ->
            {:error, reason}
        end
      end)
    end)
    
    # Wait for all tasks to complete
    results = Task.await_all(tasks, 60_000)
    
    # Display concurrent results
    Enum.zip(configs, results)
    |> Enum.each(fn {config, result} ->
      case result do
        {:ok, data} ->
          IO.puts("\n✅ #{config.model} (#{config.id}) completed successfully")
          display_verification_results(data, config.mode)
        
        {:error, reason} ->
          IO.puts("\n❌ #{config.model} (#{config.id}) failed: #{inspect(reason)}")
      end
    end)
    
    # Show final concurrent statistics
    show_final_statistics()
  end
end

# Parse command line arguments
case System.argv() do
  ["concurrent"] ->
    GPT41StreamingDemo.run_concurrent_demo()
  
  _ ->
    GPT41StreamingDemo.run_complete_demo()
end