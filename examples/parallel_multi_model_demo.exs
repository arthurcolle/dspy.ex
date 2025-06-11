#!/usr/bin/env elixir

# Parallel Multi-Model Agent Demonstration
# This example shows how to leverage multiple AI models simultaneously
# for enhanced problem-solving through distributed reasoning and consensus.

Mix.install([
  {:dspy, path: Path.expand("..")},
  {:jason, "~> 1.4"}
])

defmodule ParallelMultiModelDemo do
  @moduledoc """
  Comprehensive demonstration of the Parallel Multi-Model Agent system.
  
  This demo showcases:
  1. Setting up multiple AI models with different capabilities
  2. Executing tasks in parallel across models
  3. Different consensus strategies for combining results
  4. Performance monitoring and optimization
  5. Real-world use cases and scenarios
  """

  require Logger

  def run_comprehensive_demo do
    IO.puts("\n🚀 Parallel Multi-Model Agent Demonstration")
    IO.puts("=" |> String.duplicate(60))
    
    # Start the agent with multiple models
    agent_config = setup_multi_model_agent()
    
    # Run various demonstration scenarios
    scenarios = [
      :model_portfolio_overview,
      :cost_analysis_demo,
      :model_recommendations_demo,
      :flagship_models_showcase,
      :reasoning_models_showcase,
      :specialized_models_showcase,
      :cost_optimization_demo,
      :consensus_comparison,
      :performance_optimization
    ]
    
    Enum.each(scenarios, fn scenario ->
      IO.puts("\n📋 Running scenario: #{scenario}")
      IO.puts("-" |> String.duplicate(40))
      execute_scenario(scenario, agent_config.agent_id)
      Process.sleep(1000) # Brief pause between scenarios
    end)
    
    # Show final performance metrics
    show_performance_summary(agent_config.agent_id)
    
    IO.puts("\n✅ Demonstration completed successfully!")
  end

  defp setup_multi_model_agent do
    IO.puts("🔧 Setting up Parallel Multi-Model Agent...")
    
    # Configure a representative selection of models showcasing the full range
    model_configs = [
      # Flagship Model
      %{
        id: :gpt45_preview,
        client: create_mock_client("gpt-4.5-preview"),
        capabilities: [:advanced_reasoning, :research, :complex_analysis],
        performance_score: 0.98,
        cost_per_token: 0.075,
        max_context: 200000,
        specializations: [:frontier_research, :complex_reasoning],
        category: :flagship,
        use_cases: [:research, :complex_problem_solving]
      },
      
      # Latest GPT-4.1 Series
      %{
        id: :gpt41,
        client: create_mock_client("gpt-4.1"),
        capabilities: [:reasoning, :coding, :analysis, :creative],
        performance_score: 0.96,
        cost_per_token: 0.002,
        max_context: 200000,
        specializations: [:latest_capabilities, :general_excellence],
        category: :latest,
        use_cases: [:general_purpose, :coding, :analysis]
      },
      %{
        id: :gpt41_mini,
        client: create_mock_client("gpt-4.1-mini"),
        capabilities: [:reasoning, :coding, :analysis, :fast_response],
        performance_score: 0.90,
        cost_per_token: 0.0004,
        max_context: 128000,
        specializations: [:cost_efficient, :balanced_performance],
        category: :efficient,
        use_cases: [:general_purpose, :cost_sensitive]
      },
      
      # Reasoning Models
      %{
        id: :o1_pro,
        client: create_mock_client("o1-pro"),
        capabilities: [:advanced_reasoning, :expert_analysis, :research],
        performance_score: 0.99,
        cost_per_token: 0.15,
        max_context: 200000,
        specializations: [:expert_reasoning, :research_grade],
        category: :premium,
        use_cases: [:expert_analysis, :research, :complex_projects]
      },
      %{
        id: :o1,
        client: create_mock_client("o1"),
        capabilities: [:deep_reasoning, :problem_solving, :mathematics],
        performance_score: 0.97,
        cost_per_token: 0.015,
        max_context: 200000,
        specializations: [:deep_reasoning, :mathematical_thinking],
        category: :reasoning,
        use_cases: [:complex_reasoning, :mathematics, :science]
      },
      %{
        id: :o4_mini,
        client: create_mock_client("o4-mini"),
        capabilities: [:reasoning, :cost_efficient, :fast_response],
        performance_score: 0.85,
        cost_per_token: 0.0011,
        max_context: 128000,
        specializations: [:efficient_reasoning, :cost_optimization],
        category: :efficient,
        use_cases: [:reasoning_tasks, :cost_sensitive]
      },
      
      # Multimodal Models
      %{
        id: :gpt4o,
        client: create_mock_client("gpt-4o"),
        capabilities: [:reasoning, :coding, :analysis, :creative, :multimodal],
        performance_score: 0.95,
        cost_per_token: 0.0025,
        max_context: 128000,
        specializations: [:multimodal, :general_excellence],
        category: :multimodal,
        use_cases: [:general_purpose, :multimodal_tasks]
      },
      %{
        id: :gpt4o_mini,
        client: create_mock_client("gpt-4o-mini"),
        capabilities: [:reasoning, :coding, :analysis, :fast_response, :multimodal],
        performance_score: 0.88,
        cost_per_token: 0.00015,
        max_context: 128000,
        specializations: [:cost_efficient_multimodal, :fast_response],
        category: :efficient_multimodal,
        use_cases: [:general_purpose, :cost_sensitive, :multimodal_tasks]
      },
      
      # Specialized Models
      %{
        id: :gpt4o_search,
        client: create_mock_client("gpt-4o-search-preview"),
        capabilities: [:web_search, :real_time_info, :research, :analysis],
        performance_score: 0.93,
        cost_per_token: 0.0025,
        max_context: 128000,
        specializations: [:web_search, :real_time_information],
        category: :search,
        use_cases: [:research, :current_events, :fact_checking]
      },
      %{
        id: :codex_mini,
        client: create_mock_client("codex-mini-latest"),
        capabilities: [:code_generation, :programming, :technical_analysis],
        performance_score: 0.89,
        cost_per_token: 0.0015,
        max_context: 128000,
        specializations: [:code_generation, :programming],
        category: :coding,
        use_cases: [:code_generation, :programming_assistance]
      },
      %{
        id: :gpt4o_audio,
        client: create_mock_client("gpt-4o-audio-preview"),
        capabilities: [:audio_processing, :multimodal, :reasoning],
        performance_score: 0.92,
        cost_per_token: 0.0025,
        max_context: 128000,
        specializations: [:audio_capabilities, :multimodal_audio],
        category: :audio,
        use_cases: [:audio_processing, :voice_applications]
      },
      
      # Budget Options
      %{
        id: :gpt35_turbo,
        client: create_mock_client("gpt-3.5-turbo"),
        capabilities: [:general, :fast_response, :cost_efficient],
        performance_score: 0.75,
        cost_per_token: 0.0005,
        max_context: 16000,
        specializations: [:ultra_cost_efficient, :speed],
        category: :budget,
        use_cases: [:simple_tasks, :high_volume, :cost_optimization]
      }
    ]
    
    agent_opts = [
      models: model_configs,
      coordination_strategy: :weighted_voting,
      agent_id: "demo_agent_#{:rand.uniform(1000)}"
    ]
    
    {:ok, _pid} = Dspy.ParallelMultiModelAgent.start_link(agent_opts)
    
    IO.puts("✅ Agent initialized with #{length(model_configs)} models")
    %{agent_id: agent_opts[:agent_id], models: model_configs}
  end

  defp execute_scenario(:model_portfolio_overview, agent_id) do
    IO.puts("📊 Model Portfolio Overview")
    
    case Dspy.ParallelMultiModelAgent.get_agent_status(agent_id) do
      status when is_map(status) ->
        IO.puts("   Available Models: #{length(status.models)}")
        IO.puts("   Model Categories:")
        
        # Group models by category for display
        model_categories = %{
          flagship: ["gpt-4.5-preview"],
          latest: ["gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"],
          reasoning: ["o1", "o1-pro", "o3", "o4-mini", "o3-mini", "o1-mini"],
          multimodal: ["gpt-4o", "gpt-4o-mini"],
          audio: ["gpt-4o-audio-preview", "gpt-4o-mini-audio-preview"],
          search: ["gpt-4o-search-preview", "gpt-4o-mini-search-preview"],
          coding: ["codex-mini-latest"],
          automation: ["computer-use-preview"],
          budget: ["gpt-3.5-turbo", "gpt-3.5-turbo-instruct"],
          legacy: ["gpt-4", "gpt-4-turbo", "chatgpt-4o-latest"]
        }
        
        Enum.each(model_categories, fn {category, models} ->
          IO.puts("      #{category}: #{length(models)} models")
        end)
        
        IO.puts("   Coordination Strategy: #{status.coordination_strategy}")
      
      error ->
        IO.puts("   ❌ Could not retrieve status: #{inspect(error)}")
    end
  end

  defp execute_scenario(:cost_analysis_demo, agent_id) do
    IO.puts("💰 Cost Analysis Demonstration")
    
    sample_task = %{
      type: :research,
      prompt: "Analyze the economic impact of renewable energy adoption in developing countries",
      priority: :high,
      context: %{domain: "economics", complexity: "high"}
    }
    
    case Dspy.ParallelMultiModelAgent.analyze_costs(agent_id, sample_task) do
      {:ok, analysis} ->
        IO.puts("   Task: #{sample_task.type} (#{sample_task.priority} priority)")
        IO.puts("   Estimated tokens: #{analysis.task_analysis.estimated_tokens}")
        IO.puts("")
        IO.puts("   Cost Comparison by Strategy:")
        
        Enum.each(analysis.cost_comparisons, fn comparison ->
          IO.puts("      #{comparison.strategy}: $#{Float.round(comparison.estimated_cost, 4)} (#{Enum.join(comparison.models, ", ")})")
        end)
        
        recommendations = analysis.recommendations
        IO.puts("")
        IO.puts("   Recommendations:")
        IO.puts("      Most cost-effective: #{recommendations.most_cost_effective}")
        IO.puts("      Potential savings: #{recommendations.potential_savings.percentage}%")
        
      error ->
        IO.puts("   ❌ Cost analysis failed: #{inspect(error)}")
    end
  end

  defp execute_scenario(:model_recommendations_demo, _agent_id) do
    IO.puts("🎯 Model Recommendations Demo")
    
    # Test different requirement scenarios
    scenarios = [
      %{budget: :low, performance: :medium, task_types: [:general], volume: :medium},
      %{budget: :high, performance: :high, task_types: [:research, :analysis], volume: :low},
      %{budget: :medium, performance: :medium, task_types: [:code_generation], volume: :high}
    ]
    
    Enum.each(scenarios, fn requirements ->
      IO.puts("   Scenario: Budget=#{requirements.budget}, Performance=#{requirements.performance}")
      IO.puts("   Tasks: #{Enum.join(requirements.task_types, ", ")}, Volume=#{requirements.volume}")
      
      recommendations = Dspy.ParallelMultiModelAgent.get_model_recommendations(requirements)
      
      primary = recommendations.primary_recommendations |> Enum.take(3)
      IO.puts("   Primary recommendations: #{Enum.map_join(primary, ", ", & &1.id)}")
      
      if length(recommendations.alternative_options) > 0 do
        alternatives = recommendations.alternative_options |> Enum.take(2)
        IO.puts("   Alternatives: #{Enum.map_join(alternatives, ", ", & &1.id)}")
      end
      
      IO.puts("")
    end)
  end

  defp execute_scenario(:flagship_models_showcase, agent_id) do
    IO.puts("🚀 Flagship Models Showcase")
    
    task = %{
      type: :expert_analysis,
      prompt: """
      Provide a comprehensive analysis of the potential for quantum computing 
      to revolutionize drug discovery, including technical challenges, 
      timeline expectations, and economic implications.
      """,
      priority: :critical,
      context: %{domain: "quantum_computing", expertise_required: "high"}
    }
    
    # This would use the highest-tier models like GPT-4.5-preview and O1-Pro
    result = execute_task_with_timing(agent_id, task)
    display_consensus_result(result, "Flagship Models Analysis")
  end

  defp execute_scenario(:reasoning_models_showcase, agent_id) do
    IO.puts("🧠 Reasoning Models Showcase")
    
    task = %{
      type: :complex_reasoning,
      prompt: """
      Solve this multi-step problem:
      
      A city of 500,000 people wants to achieve carbon neutrality by 2030.
      Current emissions: 2.5 million tons CO2/year
      Available budget: $1 billion over 7 years
      Key constraints: Must maintain economic growth, public approval >60%
      
      Design an optimal implementation strategy with specific timelines,
      costs, and measurable milestones. Show your reasoning process.
      """,
      priority: :high,
      context: %{complexity: "multi_step", reasoning_required: true}
    }
    
    result = execute_task_with_timing(agent_id, task)
    display_consensus_result(result, "Advanced Reasoning")
  end

  defp execute_scenario(:specialized_models_showcase, agent_id) do
    IO.puts("🔧 Specialized Models Showcase")
    
    # Test different specialized capabilities
    specialized_tasks = [
      %{
        type: :web_search,
        prompt: "What are the latest developments in AI safety research as of 2024?",
        priority: :medium,
        context: %{requires_current_info: true}
      },
      %{
        type: :code_generation,
        prompt: "Create a Rust implementation of a concurrent hash map with lock-free reads",
        priority: :high,
        context: %{language: "rust", performance_critical: true}
      },
      %{
        type: :audio_processing,
        prompt: "Design a system for real-time audio transcription with speaker identification",
        priority: :medium,
        context: %{modality: "audio", real_time: true}
      }
    ]
    
    Enum.each(specialized_tasks, fn task ->
      IO.puts("   Testing #{task.type} capabilities...")
      result = execute_task_with_timing(agent_id, task)
      
      if Map.has_key?(result, :error) do
        IO.puts("      ❌ Failed: #{inspect(result.error)}")
      else
        IO.puts("      ✅ Success: #{length(result.contributing_models)} models, #{result.execution_time}ms")
        IO.puts("      Models used: #{Enum.join(result.contributing_models, ", ")}")
      end
    end)
  end

  defp execute_scenario(:cost_optimization_demo, agent_id) do
    IO.puts("💡 Cost Optimization Demo")
    
    base_task = %{
      type: :simple_tasks,
      prompt: "Summarize the key benefits of renewable energy in 3 bullet points",
      priority: :low,
      context: %{length: "short", complexity: "low"}
    }
    
    # Test different optimization strategies
    strategies = [:cost_optimized, :speed_optimized, :balanced]
    
    Enum.each(strategies, fn strategy ->
      IO.puts("   Testing #{strategy} strategy...")
      Dspy.ParallelMultiModelAgent.set_consensus_strategy(agent_id, :weighted_voting)
      
      # Modify task type to trigger the strategy
      optimized_task = %{base_task | type: strategy}
      result = execute_task_with_timing(agent_id, optimized_task)
      
      if Map.has_key?(result, :error) do
        IO.puts("      ❌ Failed")
      else
        IO.puts("      Models: #{Enum.join(result.contributing_models, ", ")}")
        IO.puts("      Time: #{result.execution_time}ms, Tokens: #{result.token_usage}")
      end
    end)
    
    # Reset to default
    Dspy.ParallelMultiModelAgent.set_consensus_strategy(agent_id, :weighted_voting)
  end

  defp execute_scenario(:complex_reasoning_task, agent_id) do
    IO.puts("🧠 Complex Reasoning Challenge")
    
    task = %{
      type: :complex_reasoning,
      prompt: """
      You are tasked with solving a complex multi-step reasoning problem:
      
      A city wants to reduce carbon emissions by 50% over 10 years while maintaining economic growth.
      The city has 1 million residents, current emissions of 10 million tons CO2/year, and a $2 billion budget.
      
      Design a comprehensive strategy that addresses:
      1. Transportation infrastructure changes
      2. Energy transition timeline
      3. Economic impact mitigation
      4. Citizen engagement programs
      5. Measurable milestones and success metrics
      
      Provide specific, actionable recommendations with cost estimates and timelines.
      """,
      priority: :high,
      context: %{
        domain: "environmental_policy",
        complexity: "high",
        stakeholders: ["government", "citizens", "businesses"]
      }
    }
    
    result = execute_task_with_timing(agent_id, task)
    display_consensus_result(result, "Complex Reasoning")
  end

  defp execute_scenario(:code_generation_challenge, agent_id) do
    IO.puts("💻 Code Generation Challenge")
    
    task = %{
      type: :code_generation,
      prompt: """
      Create a distributed rate limiter system in Elixir that can:
      
      1. Handle 1M+ requests per second across multiple nodes
      2. Support different rate limiting strategies (token bucket, sliding window)
      3. Provide real-time monitoring and alerting
      4. Scale horizontally with consistent performance
      5. Handle node failures gracefully
      
      Include:
      - Complete GenServer implementation
      - Supervisor tree structure
      - Performance optimizations
      - Comprehensive tests
      - Documentation with usage examples
      """,
      priority: :high,
      context: %{
        language: "elixir",
        performance_requirements: "high",
        scalability: "distributed"
      }
    }
    
    result = execute_task_with_timing(agent_id, task)
    display_consensus_result(result, "Code Generation")
  end

  defp execute_scenario(:creative_problem_solving, agent_id) do
    IO.puts("🎨 Creative Problem Solving")
    
    task = %{
      type: :creative_writing,
      prompt: """
      Design an innovative solution for urban food deserts (areas with limited access to fresh, healthy food).
      
      Your solution should be:
      1. Technologically innovative but practical
      2. Economically sustainable
      3. Community-driven
      4. Scalable to different city sizes
      5. Environmentally conscious
      
      Think outside traditional approaches. Consider how emerging technologies
      (IoT, AI, automation, etc.) could be integrated creatively.
      """,
      priority: :medium,
      context: %{
        domain: "social_innovation",
        approach: "creative",
        constraints: ["budget", "regulations", "community_acceptance"]
      }
    }
    
    result = execute_task_with_timing(agent_id, task)
    display_consensus_result(result, "Creative Problem Solving")
  end

  defp execute_scenario(:safety_analysis_task, agent_id) do
    IO.puts("🛡️ Safety Analysis Task")
    
    task = %{
      type: :safety_analysis,
      prompt: """
      Analyze the safety implications of deploying autonomous delivery drones in dense urban areas.
      
      Consider:
      1. Technical safety risks and mitigation strategies
      2. Regulatory compliance requirements
      3. Public safety concerns and community impact
      4. Cybersecurity vulnerabilities
      5. Emergency response protocols
      6. Insurance and liability considerations
      
      Provide a comprehensive risk assessment with recommended safety measures.
      """,
      priority: :critical,
      context: %{
        domain: "autonomous_systems",
        focus: "safety_first",
        stakeholders: ["regulators", "public", "operators"]
      }
    }
    
    result = execute_task_with_timing(agent_id, task)
    display_consensus_result(result, "Safety Analysis")
  end

  defp execute_scenario(:consensus_comparison, agent_id) do
    IO.puts("🤝 Consensus Strategy Comparison")
    
    base_task = %{
      type: :analysis,
      prompt: """
      What are the most promising renewable energy technologies for the next decade,
      considering cost, scalability, and environmental impact?
      """,
      priority: :medium,
      context: %{domain: "energy_technology"}
    }
    
    strategies = [:weighted_voting, :majority_vote, :best_confidence, :ensemble_blend]
    
    Enum.each(strategies, fn strategy ->
      IO.puts("   Testing #{strategy} consensus...")
      Dspy.ParallelMultiModelAgent.set_consensus_strategy(agent_id, strategy)
      
      result = execute_task_with_timing(agent_id, base_task)
      
      IO.puts("   #{strategy}: Confidence #{Float.round(result.confidence, 3)}, " <>
              "Models: #{length(result.contributing_models)}")
    end)
    
    # Reset to default
    Dspy.ParallelMultiModelAgent.set_consensus_strategy(agent_id, :weighted_voting)
  end

  defp execute_scenario(:performance_optimization, agent_id) do
    IO.puts("⚡ Performance Optimization Test")
    
    # Execute multiple tasks to test performance under load
    tasks = [
      %{type: :fast_response, prompt: "Explain quantum computing in one paragraph", priority: :low},
      %{type: :cost_sensitive, prompt: "List 5 benefits of renewable energy", priority: :low},
      %{type: :general, prompt: "Compare Python and Rust for web development", priority: :medium}
    ]
    
    start_time = System.monotonic_time(:millisecond)
    
    # Execute tasks in parallel
    results = Task.async_stream(tasks, fn task ->
      execute_task_with_timing(agent_id, task)
    end, max_concurrency: 3, timeout: 30_000)
    |> Enum.map(fn {:ok, result} -> result end)
    
    total_time = System.monotonic_time(:millisecond) - start_time
    
    IO.puts("   Executed #{length(tasks)} tasks in #{total_time}ms")
    IO.puts("   Average response time: #{div(total_time, length(tasks))}ms")
    IO.puts("   Total tokens used: #{Enum.sum(Enum.map(results, & &1.token_usage))}")
  end

  defp execute_task_with_timing(agent_id, task) do
    start_time = System.monotonic_time(:millisecond)
    
    case Dspy.ParallelMultiModelAgent.execute_parallel_task(agent_id, task) do
      {:ok, result} ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        %{result | execution_time: execution_time}
      
      {:error, reason} ->
        IO.puts("❌ Task execution failed: #{inspect(reason)}")
        %{error: reason, execution_time: 0}
    end
  end

  defp display_consensus_result(result, task_name) do
    if Map.has_key?(result, :error) do
      IO.puts("   ❌ #{task_name} failed: #{inspect(result.error)}")
    else
      IO.puts("   ✅ #{task_name} completed:")
      IO.puts("      Confidence: #{Float.round(result.confidence, 3)}")
      IO.puts("      Models used: #{Enum.join(result.contributing_models, ", ")}")
      IO.puts("      Execution time: #{result.execution_time}ms")
      IO.puts("      Tokens used: #{result.token_usage}")
      
      # Show truncated response
      truncated_response = String.slice(result.final_answer, 0, 200)
      IO.puts("      Response preview: #{truncated_response}...")
    end
  end

  defp show_performance_summary(agent_id) do
    IO.puts("\n📊 Performance Summary")
    IO.puts("=" |> String.duplicate(30))
    
    case Dspy.ParallelMultiModelAgent.get_agent_status(agent_id) do
      status when is_map(status) ->
        metrics = status.performance_metrics
        
        IO.puts("Tasks completed: #{Map.get(metrics, :tasks_completed, 0)}")
        IO.puts("Total execution time: #{Map.get(metrics, :total_execution_time, 0)}ms")
        IO.puts("Average confidence: #{Float.round(Map.get(metrics, :average_confidence, 0.0), 3)}")
        IO.puts("Total tokens used: #{Map.get(metrics, :total_tokens, 0)}")
        
        task_types = Map.get(metrics, :task_types, %{})
        if map_size(task_types) > 0 do
          IO.puts("\nTask type distribution:")
          Enum.each(task_types, fn {type, count} ->
            IO.puts("  #{type}: #{count}")
          end)
        end
        
        IO.puts("\nActive models: #{Enum.join(status.models, ", ")}")
        IO.puts("Coordination strategy: #{status.coordination_strategy}")
      
      error ->
        IO.puts("❌ Could not retrieve performance metrics: #{inspect(error)}")
    end
  end

  # Mock client for demonstration (replace with real API clients)
  defp create_mock_client(model_name) do
    %{
      type: :mock,
      model: model_name,
      generate_response: fn prompt ->
        # Simulate different response styles based on model
        case model_name do
          "gpt-4o" ->
            "GPT-4o Analysis: " <> simulate_detailed_response(prompt)
          
          "gpt-4-turbo" ->
            "GPT-4 Turbo Response: " <> simulate_fast_response(prompt)
          
          "claude-3-sonnet" ->
            "Claude 3 Sonnet Insight: " <> simulate_thoughtful_response(prompt)
          
          "gpt-3.5-turbo" ->
            "GPT-3.5 Quick Answer: " <> simulate_concise_response(prompt)
          
          _ ->
            "Generic model response to: " <> String.slice(prompt, 0, 50)
        end
      end
    }
  end

  defp simulate_detailed_response(prompt) do
    """
    This is a comprehensive analysis of the given prompt. After careful consideration
    of multiple factors and potential implications, I recommend the following approach:
    
    1. Primary considerations include the scope and complexity of the problem
    2. Secondary factors involve stakeholder impact and resource requirements
    3. Implementation should follow a phased approach with clear milestones
    
    The reasoning behind this recommendation is based on established best practices
    and careful risk assessment. [Simulated detailed response for: #{String.slice(prompt, 0, 30)}...]
    """
  end

  defp simulate_fast_response(prompt) do
    """
    Quick analysis: The key points to address are efficiency, scalability, and practicality.
    Recommended approach: Start with MVP, gather feedback, iterate rapidly.
    Expected outcome: Positive impact with manageable risks.
    [Fast response for: #{String.slice(prompt, 0, 30)}...]
    """
  end

  defp simulate_thoughtful_response(prompt) do
    """
    Upon reflection, this challenge requires balancing multiple competing priorities.
    The most ethical and sustainable approach would consider long-term implications
    for all stakeholders while maintaining safety and transparency as core principles.
    [Thoughtful analysis for: #{String.slice(prompt, 0, 30)}...]
    """
  end

  defp simulate_concise_response(prompt) do
    """
    Direct answer: Focus on the most impactful solutions first.
    Key benefits: Cost-effective, quick to implement, measurable results.
    [Concise response for: #{String.slice(prompt, 0, 30)}...]
    """
  end
end

# Mock the generate function for demonstration
defmodule MockLM do
  def generate(client, request) do
    prompt = get_in(request, [:messages, Access.at(0), "content"]) || ""
    response_text = client.generate_response.(prompt)
    
    # Simulate API response structure
    {:ok, %{
      choices: [
        %{
          message: %{"content" => response_text}
        }
      ]
    }}
  end
end

# Patch the LM module for demo
defmodule Dspy.LM do
  defdelegate generate(client, request), to: MockLM
end

# Start the demo
IO.puts("Starting Parallel Multi-Model Agent Demonstration...")
Process.sleep(500)

try do
  ParallelMultiModelDemo.run_comprehensive_demo()
rescue
  error ->
    IO.puts("\n❌ Demo encountered an error: #{inspect(error)}")
    IO.puts("This is expected in a mock environment. In production, ensure:")
    IO.puts("1. Valid API keys are configured")
    IO.puts("2. Network connectivity is available")
    IO.puts("3. Rate limits are configured appropriately")
end