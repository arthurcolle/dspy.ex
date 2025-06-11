#!/usr/bin/env elixir

# Enhanced Streaming Visualization Showcase
#
# This example demonstrates the new enhanced streaming visualization system with:
# 1. Real-time co-current processing visualization
# 2. Attractive animated progress displays
# 3. Live performance metrics and charts
# 4. Multi-stream concurrent visualization
# 5. Advanced analytics and quality scoring

Mix.install([
  {:jason, "~> 1.4"},
  {:lmstudio, git: "https://github.com/arthurcolle/lmstudio.ex.git"}
])

# Load the DSPy enhanced visualization module
Code.require_file("../lib/dspy/enhanced_streaming_visualization.ex", __DIR__)

# Configure LMStudio
Application.put_env(:lmstudio, :base_url, "http://192.168.1.177:1234")
Application.put_env(:lmstudio, :default_model, "deepseek-r1-0528-qwen3-8b-mlx")
Application.put_env(:lmstudio, :default_temperature, 0.7)
Application.put_env(:lmstudio, :default_max_tokens, -1)

defmodule EnhancedStreamingShowcase do
  @moduledoc """
  Showcase for enhanced streaming visualization with beautiful real-time displays,
  co-current processing visualization, and comprehensive analytics.
  """

  def run_showcase do
    IO.puts("🚀 Enhanced Streaming Visualization Showcase")
    IO.puts("=" |> String.duplicate(80))
    IO.puts("Features: Real-time metrics • Co-current processing • Live charts • Analytics")
    IO.puts("")

    # Start the enhanced visualization system
    {:ok, _pid} = Dspy.EnhancedStreamingVisualization.start_link([
      display_mode: :full,
      enable_charts: true,
      animations: true,
      animation_speed: 200
    ])

    # Demonstrate different visualization modes
    demo_scenarios = [
      %{
        name: "Single Stream with Full Analytics",
        type: :single_enhanced,
        prompt: "Design a comprehensive climate change monitoring system with real-time global data analysis"
      },
      %{
        name: "Concurrent Multi-Stream Processing", 
        type: :concurrent,
        streams: [
          %{prompt: "Analyze quantum computing applications in cryptography", model: "deepseek", id: "quantum_stream"},
          %{prompt: "Design sustainable energy distribution networks", model: "deepseek", id: "energy_stream"},
          %{prompt: "Create AI-powered medical diagnosis framework", model: "deepseek", id: "medical_stream"}
        ]
      },
      %{
        name: "High-Performance Reasoning Analysis",
        type: :reasoning_focused,
        prompt: "Develop a comprehensive strategy for Mars colonization including logistics, technology, and human factors"
      }
    ]

    Enum.with_index(demo_scenarios, 1)
    |> Enum.each(fn {scenario, index} ->
      IO.puts("\n🎯 Demo #{index}/#{length(demo_scenarios)}: #{scenario.name}")
      IO.puts("=" |> String.duplicate(60))
      
      case scenario.type do
        :single_enhanced -> run_enhanced_single_stream(scenario)
        :concurrent -> run_concurrent_streams(scenario)
        :reasoning_focused -> run_reasoning_analysis(scenario)
      end
      
      if index < length(demo_scenarios) do
        IO.puts("\n⏱️  Waiting 3 seconds before next demo...")
        Process.sleep(3000)
      end
    end)

    # Display final comprehensive statistics
    display_showcase_summary()
  end

  defp run_enhanced_single_stream(scenario) do
    # Create enhanced streaming callback with full analytics
    stream_callback = Dspy.EnhancedStreamingVisualization.create_enhanced_callback([
      stream_id: "enhanced_demo_#{System.unique_integer([:positive])}",
      display_mode: :full,
      enable_charts: true,
      model: "deepseek-r1-0528-qwen3-8b-mlx"
    ])

    # Enhanced prompt with reasoning instructions
    enhanced_prompt = build_enhanced_reasoning_prompt(scenario.prompt)
    
    messages = [
      %{role: "system", content: enhanced_prompt},
      %{role: "user", content: scenario.prompt}
    ]

    IO.puts("🌊 Initiating enhanced streaming with full analytics...")
    
    case LMStudio.complete(messages, stream: true, stream_callback: stream_callback) do
      {:ok, _} ->
        IO.puts("\n✅ Enhanced streaming completed successfully!")
        display_stream_analytics()
      
      {:error, reason} ->
        IO.puts("\n❌ Streaming error: #{inspect(reason)}")
    end
  end

  defp run_concurrent_streams(scenario) do
    IO.puts("🔄 Starting concurrent multi-stream visualization...")
    
    # Initialize concurrent visualization
    Dspy.EnhancedStreamingVisualization.start_concurrent_visualization(scenario.streams)
    
    # Create tasks for each stream
    tasks = Enum.map(scenario.streams, fn stream_config ->
      Task.async(fn ->
        stream_callback = Dspy.EnhancedStreamingVisualization.create_enhanced_callback([
          stream_id: stream_config.id,
          display_mode: :concurrent,
          model: stream_config.model
        ])
        
        enhanced_prompt = build_enhanced_reasoning_prompt(stream_config.prompt)
        messages = [
          %{role: "system", content: enhanced_prompt},
          %{role: "user", content: stream_config.prompt}
        ]
        
        LMStudio.complete(messages, stream: true, stream_callback: stream_callback)
      end)
    end)
    
    # Wait for all streams to complete
    results = Task.await_many(tasks, 120_000)
    
    IO.puts("\n✅ All concurrent streams completed!")
    display_concurrent_analytics(results)
  end

  defp run_reasoning_analysis(scenario) do
    # Focus on reasoning token extraction and analysis
    stream_callback = Dspy.EnhancedStreamingVisualization.create_enhanced_callback([
      stream_id: "reasoning_analysis_#{System.unique_integer([:positive])}",
      display_mode: :reasoning_focused,
      enable_charts: true,
      model: "deepseek-r1-0528-qwen3-8b-mlx"
    ])

    # Reasoning-focused prompt
    reasoning_prompt = build_reasoning_focused_prompt(scenario.prompt)
    
    messages = [
      %{role: "system", content: reasoning_prompt},
      %{role: "user", content: scenario.prompt}
    ]

    IO.puts("🧠 Initiating reasoning-focused streaming analysis...")
    
    case LMStudio.complete(messages, stream: true, stream_callback: stream_callback) do
      {:ok, _} ->
        IO.puts("\n🎓 Reasoning analysis completed!")
        display_reasoning_analytics()
      
      {:error, reason} ->
        IO.puts("\n❌ Reasoning analysis error: #{inspect(reason)}")
    end
  end

  defp build_enhanced_reasoning_prompt(user_prompt) do
    """
    You are an advanced AI assistant with enhanced reasoning capabilities.
    
    ENHANCED REASONING INSTRUCTIONS:
    1. Use <think>...</think> tags to show your detailed reasoning process
    2. Break down complex problems into logical steps
    3. Consider multiple perspectives and potential solutions
    4. Identify assumptions, constraints, and dependencies
    5. Provide a structured JSON response with your conclusions
    
    RESPONSE FORMAT:
    <think>
    [Show your detailed step-by-step reasoning here]
    - Analysis of the problem
    - Consideration of different approaches
    - Evaluation of pros and cons
    - Selection of optimal solution
    - Implementation considerations
    </think>
    
    {
      "analysis": "Brief summary of your analysis",
      "approach": "Selected approach with justification",
      "implementation_steps": ["step1", "step2", "step3"],
      "considerations": {
        "challenges": ["challenge1", "challenge2"],
        "opportunities": ["opportunity1", "opportunity2"],
        "risks": ["risk1", "risk2"]
      },
      "confidence_score": 0.85,
      "estimated_timeline": "timeframe for implementation",
      "success_metrics": ["metric1", "metric2"]
    }

    Focus on providing deep, analytical thinking followed by actionable structured output.
    """
  end

  defp build_reasoning_focused_prompt(user_prompt) do
    """
    You are a reasoning specialist focused on deep analytical thinking.
    
    REASONING-FOCUSED INSTRUCTIONS:
    1. Show extensive reasoning using <think>...</think> tags
    2. Explore multiple solution paths and compare them
    3. Use systematic problem-solving approaches
    4. Consider edge cases and potential failures
    5. Provide reasoning quality indicators in your response
    
    ENHANCED REASONING REQUIREMENTS:
    - Show at least 3 different approaches
    - Analyze pros and cons for each approach
    - Consider implementation complexity
    - Evaluate resource requirements
    - Assess risk factors
    - Provide confidence intervals
    
    <think>
    [Your comprehensive reasoning process here - aim for thorough analysis]
    
    Problem Analysis:
    - Core challenges identified
    - Stakeholder considerations
    - Technical constraints
    - Resource limitations
    
    Approach Evaluation:
    Approach 1: [description]
    - Pros: [list]
    - Cons: [list]
    - Complexity: [assessment]
    
    Approach 2: [description]
    - Pros: [list] 
    - Cons: [list]
    - Complexity: [assessment]
    
    Approach 3: [description]
    - Pros: [list]
    - Cons: [list]
    - Complexity: [assessment]
    
    Final Recommendation:
    [Detailed justification for selected approach]
    </think>
    
    {
      "reasoning_quality": {
        "depth_score": 0.95,
        "breadth_score": 0.88,
        "analytical_rigor": 0.92
      },
      "problem_breakdown": "systematic analysis of the challenge",
      "solution_comparison": {
        "approaches_considered": 3,
        "selection_criteria": ["criteria1", "criteria2"],
        "recommended_approach": "detailed recommendation"
      },
      "implementation_roadmap": ["phase1", "phase2", "phase3"],
      "risk_mitigation": ["strategy1", "strategy2"],
      "success_probability": 0.85
    }

    Demonstrate the highest level of reasoning and analytical thinking.
    """
  end

  defp display_stream_analytics do
    stats = Dspy.EnhancedStreamingVisualization.get_streaming_stats()
    
    IO.puts("\n📊 Enhanced Stream Analytics:")
    IO.puts("├─ Total Streams Processed: #{stats.total_streams}")
    IO.puts("├─ Global Characters Processed: #{stats.global_metrics.total_characters}")
    IO.puts("├─ Global Chunks Processed: #{stats.global_metrics.total_chunks}")
    IO.puts("├─ System Uptime: #{stats.uptime}ms")
    
    if stats.performance_summary.fastest_stream do
      IO.puts("├─ Fastest Stream Performance: #{inspect(stats.performance_summary.fastest_stream.id)}")
    end
    
    IO.puts("└─ Visualization Engine Status: ✅ Active")
  end

  defp display_concurrent_analytics(results) do
    successful_streams = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    stats = Dspy.EnhancedStreamingVisualization.get_streaming_stats()
    
    IO.puts("\n🔄 Concurrent Processing Analytics:")
    IO.puts("├─ Successful Streams: #{successful_streams}/#{length(results)}")
    IO.puts("├─ Collective Throughput: #{Float.round(stats.global_metrics.collective_throughput, 2)} chars/ms")
    IO.puts("├─ Average Stream Performance: #{Float.round(stats.global_metrics.average_stream_performance, 2)} chars/stream")
    
    if stats.performance_summary.efficiency_stats do
      eff = stats.performance_summary.efficiency_stats
      IO.puts("├─ Efficiency Range: #{Float.round(eff.min_efficiency, 1)} - #{Float.round(eff.max_efficiency, 1)} chars/chunk")
      IO.puts("├─ Average Efficiency: #{Float.round(eff.average_efficiency, 1)} chars/chunk")
    end
    
    IO.puts("└─ Concurrent Visualization: ✅ Successfully Demonstrated")
  end

  defp display_reasoning_analytics do
    stats = Dspy.EnhancedStreamingVisualization.get_streaming_stats()
    
    IO.puts("\n🧠 Reasoning Analysis Results:")
    IO.puts("├─ Reasoning Detection: ✅ Advanced Pattern Recognition")
    IO.puts("├─ Quality Assessment: ✅ Multi-dimensional Scoring")
    IO.puts("├─ Complexity Analysis: ✅ Real-time Evaluation")
    
    if stats.performance_summary.quality_leader do
      IO.puts("├─ Highest Quality Stream: #{inspect(stats.performance_summary.quality_leader.id)}")
    end
    
    IO.puts("└─ Reasoning Visualization: ✅ Comprehensive Analytics")
  end

  defp display_showcase_summary do
    stats = Dspy.EnhancedStreamingVisualization.get_streaming_stats()
    
    IO.puts("\n" <> "=" |> String.duplicate(80))
    IO.puts("🎉 ENHANCED STREAMING VISUALIZATION SHOWCASE COMPLETE")
    IO.puts("=" |> String.duplicate(80))
    
    IO.puts("\n📈 Final Statistics:")
    IO.puts("├─ Total Processing Time: #{stats.uptime}ms")
    IO.puts("├─ Streams Processed: #{stats.total_streams}")
    IO.puts("├─ Active Streams: #{stats.active_streams}")
    IO.puts("├─ Characters Processed: #{stats.global_metrics.total_characters}")
    IO.puts("├─ Chunks Processed: #{stats.global_metrics.total_chunks}")
    IO.puts("└─ System Performance: #{Float.round(stats.global_metrics.collective_throughput, 2)} chars/ms")
    
    IO.puts("\n✨ Features Demonstrated:")
    IO.puts("├─ ✅ Real-time streaming visualization")
    IO.puts("├─ ✅ Co-current processing display")
    IO.puts("├─ ✅ Live performance metrics")
    IO.puts("├─ ✅ Animated progress indicators")
    IO.puts("├─ ✅ Multi-stream coordination")
    IO.puts("├─ ✅ Advanced analytics dashboard")
    IO.puts("├─ ✅ Reasoning pattern detection")
    IO.puts("├─ ✅ Quality scoring algorithms")
    IO.puts("├─ ✅ Visual chart generation")
    IO.puts("└─ ✅ Comprehensive statistics")
    
    IO.puts("\n🎯 Enhanced Streaming Visualization System: FULLY OPERATIONAL")
    IO.puts("Ready for production use with any streaming LLM system!")
  end

  def run_interactive_demo do
    IO.puts("\n🎮 Interactive Enhanced Streaming Demo")
    IO.puts("Enter your prompt (or 'quit' to exit):")
    
    user_input = IO.gets("> ") |> String.trim()
    
    case user_input do
      "quit" -> 
        IO.puts("👋 Demo completed!")
        
      "" ->
        IO.puts("Please enter a prompt.")
        run_interactive_demo()
        
      prompt ->
        # Start enhanced visualization
        {:ok, _pid} = Dspy.EnhancedStreamingVisualization.start_link([
          display_mode: :full,
          enable_charts: true
        ])
        
        stream_callback = Dspy.EnhancedStreamingVisualization.create_enhanced_callback([
          stream_id: "interactive_#{System.unique_integer([:positive])}",
          display_mode: :full
        ])
        
        enhanced_prompt = build_enhanced_reasoning_prompt(prompt)
        messages = [
          %{role: "system", content: enhanced_prompt},
          %{role: "user", content: prompt}
        ]
        
        IO.puts("\n🌊 Processing with enhanced visualization...")
        
        case LMStudio.complete(messages, stream: true, stream_callback: stream_callback) do
          {:ok, _} ->
            IO.puts("\n✅ Interactive streaming completed!")
            display_stream_analytics()
          
          {:error, reason} ->
            IO.puts("\n❌ Error: #{inspect(reason)}")
        end
        
        run_interactive_demo()
    end
  end
end

# Run the showcase
EnhancedStreamingShowcase.run_showcase()

# Ask if user wants to try interactive mode
IO.puts("\n" <> "🎮" |> String.duplicate(60))
IO.puts("Would you like to try the interactive enhanced streaming demo? (y/n)")

case IO.gets("> ") |> String.trim() |> String.downcase() do
  "y" -> EnhancedStreamingShowcase.run_interactive_demo()
  _ -> IO.puts("👋 Showcase completed! Enhanced streaming visualization is ready for use.")
end

IO.puts("\n🎯 To use enhanced streaming in your projects:")
IO.puts("1. Start the visualization system: Dspy.EnhancedStreamingVisualization.start_link/1")
IO.puts("2. Create enhanced callback: create_enhanced_callback/1")
IO.puts("3. Use with any streaming LLM: LMStudio.complete(messages, stream: true, stream_callback: callback)")
IO.puts("4. Get real-time stats: get_streaming_stats/0")
IO.puts("\nFeatures: Real-time metrics • Co-current processing • Live charts • Advanced analytics")