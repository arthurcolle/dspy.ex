# Novel System Generation and Learning Example
# 
# This example demonstrates how the AI system can dynamically think of novel 
# reasoning systems and store all attempts as training data for continuous learning.

# First, let's define a signature for a complex reasoning problem
defmodule ComplexReasoningTask do
  use Dspy.Signature
  
  input_field :problem_description, :string, "Complex problem requiring novel reasoning approaches"
  input_field :domain, :string, "Problem domain (e.g., scientific, mathematical, creative)"
  input_field :constraints, :string, "Any constraints or requirements"
  
  output_field :solution, :string, "The reasoned solution to the problem"
  output_field :reasoning_method, :string, "Description of the reasoning method used"
  output_field :confidence, :number, "Confidence in the solution (0-1)"
  output_field :novel_insights, :string, "Any novel insights discovered during reasoning"
end

# Configure the language model
Dspy.configure(lm: %Dspy.LM.OpenAI{model: "gpt-4"})

# Start the training data storage system
{:ok, _storage_pid} = Dspy.TrainingDataStorage.start_link([
  storage_backend: :memory,
  max_storage_size: 100_000_000, # 100MB
  compression_enabled: true
])

IO.puts("=== Novel System Generation and Learning Framework ===")
IO.puts("")

# Create the experimental framework
framework = Dspy.ExperimentalFramework.new(
  ComplexReasoningTask,
  examples: [],
  experiment_settings: %{
    batch_size: 3,           # Generate 3 novel systems per iteration
    max_iterations: 5,       # Run 5 iterations of experiments
    success_threshold: 0.7,  # Require 70% confidence for success
    novelty_requirement: 0.6, # Require 60% novelty score
    time_budget_ms: 120_000, # 2 minute time budget
    parallel_execution: true
  },
  learning_rate: 0.1,
  exploration_probability: 0.4,  # 40% chance of exploration variations
  meta_learning_enabled: true,
  continuous_mode: false
)

# Define test problems of varying complexity
test_problems = [
  %{
    problem_description: "Design a sustainable city transportation system that handles 10 million daily trips while reducing carbon emissions by 80%",
    domain: "urban_planning",
    constraints: "Budget of $50 billion, 15-year implementation timeline, must integrate with existing infrastructure"
  },
  
  %{
    problem_description: "Develop a novel algorithm for protein folding prediction that outperforms current methods",
    domain: "computational_biology", 
    constraints: "Must be computationally efficient, work with limited data, and provide uncertainty estimates"
  },
  
  %{
    problem_description: "Create a fair resource allocation system for a Mars colony with 1000 inhabitants",
    domain: "space_colonization",
    constraints: "Limited resources, high stakes decisions, diverse population needs, isolation factors"
  },
  
  %{
    problem_description: "Design an AI system that can learn and adapt to completely new game rules in real-time",
    domain: "artificial_intelligence",
    constraints: "No prior training on the specific game, must learn from minimal examples, real-time performance"
  }
]

IO.puts("Running experimental cycles on #{length(test_problems)} complex problems...")
IO.puts("")

# Run experiments on each test problem
results = 
  test_problems
  |> Enum.with_index(1)
  |> Enum.map(fn {problem, index} ->
    IO.puts("=== Experiment #{index}: #{problem.domain} ===")
    IO.puts("Problem: #{String.slice(problem.problem_description, 0, 80)}...")
    IO.puts("")
    
    # Run the experimental framework
    case Dspy.Module.forward(framework, problem) do
      {:ok, prediction} ->
        attrs = prediction.attrs
        
        IO.puts("✓ Experiment completed successfully!")
        IO.puts("  Novel system used: #{Map.get(attrs, :novel_system_used, "Unknown")}")
        IO.puts("  Novelty score: #{Float.round(Map.get(attrs, :novelty_score, 0), 2)}")
        IO.puts("  Confidence: #{Float.round(Map.get(attrs, :confidence, 0), 2)}")
        IO.puts("  Experiments run: #{Map.get(attrs, :total_experiments_run, 0)}")
        IO.puts("  Solution approach: #{String.slice(Map.get(attrs, :reasoning_method, ""), 0, 100)}...")
        
        if Map.has_key?(attrs, :experimental_insights) do
          insights = attrs.experimental_insights
          IO.puts("  Learning insights:")
          IO.puts("    - Successful patterns: #{Map.get(insights, :successful_patterns, %{}) |> Map.get(:count, 0)}")
          IO.puts("    - Novel discoveries: #{Map.get(insights, :novel_discoveries, %{}) |> Map.get(:highly_novel_count, 0)}")
        end
        
        IO.puts("")
        
        %{
          problem_index: index,
          domain: problem.domain,
          success: true,
          result: attrs
        }
      
      {:error, reason} ->
        IO.puts("✗ Experiment failed: #{inspect(reason)}")
        IO.puts("")
        
        %{
          problem_index: index,
          domain: problem.domain,
          success: false,
          error: reason
        }
    end
  end)

IO.puts("=== Overall Experimental Results ===")
IO.puts("")

successful_experiments = Enum.count(results, & &1.success)
total_experiments = length(results)

IO.puts("Success rate: #{successful_experiments}/#{total_experiments} (#{Float.round(successful_experiments/total_experiments * 100, 1)}%)")

if successful_experiments > 0 do
  successful_results = Enum.filter(results, & &1.success)
  
  avg_novelty = 
    successful_results
    |> Enum.map(fn r -> Map.get(r.result, :novelty_score, 0) end)
    |> Enum.sum()
    |> Kernel./(successful_experiments)
  
  avg_confidence = 
    successful_results
    |> Enum.map(fn r -> Map.get(r.result, :confidence, 0) end)
    |> Enum.sum()
    |> Kernel./(successful_experiments)
  
  IO.puts("Average novelty score: #{Float.round(avg_novelty, 2)}")
  IO.puts("Average confidence: #{Float.round(avg_confidence, 2)}")
  
  novel_systems_used = 
    successful_results
    |> Enum.map(fn r -> Map.get(r.result, :novel_system_used, "Unknown") end)
    |> Enum.frequencies()
  
  IO.puts("")
  IO.puts("Novel systems discovered and used:")
  Enum.each(novel_systems_used, fn {system, count} ->
    IO.puts("  - #{system}: #{count} time(s)")
  end)
end

IO.puts("")
IO.puts("=== Training Data Analysis ===")

# Analyze the training data that was collected
case Dspy.TrainingDataStorage.get_statistics() do
  stats ->
    IO.puts("Training data collected:")
    IO.puts("  - Total experiments: #{stats.total_experiments}")
    IO.puts("  - Successful experiments: #{stats.successful_experiments}")
    IO.puts("  - Novel patterns discovered: #{stats.novel_patterns_discovered}")
    IO.puts("  - Average novelty score: #{Float.round(stats.average_novelty_score, 2)}")
    IO.puts("  - Storage size: #{Float.round(stats.storage_size_mb, 2)} MB")
end

# Get pattern analysis
case Dspy.TrainingDataStorage.get_pattern_analysis(:successful) do
  analysis ->
    IO.puts("")
    IO.puts("Successful patterns analysis:")
    IO.puts("  - Total successful patterns: #{analysis.total_patterns}")
    
    if length(analysis.top_performing) > 0 do
      IO.puts("  - Top performing patterns:")
      analysis.top_performing
      |> Enum.take(3)
      |> Enum.with_index(1)
      |> Enum.each(fn {pattern, index} ->
        components = Enum.join(pattern.components, ", ")
        IO.puts("    #{index}. #{components} (success rate: #{Float.round(pattern.success_rate, 2)})")
      end)
    end
    
    if map_size(analysis.component_frequency) > 0 do
      IO.puts("  - Most frequent components:")
      analysis.component_frequency
      |> Enum.sort_by(fn {_comp, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.each(fn {component, count} ->
        IO.puts("    - #{component}: #{count} uses")
      end)
    end
end

IO.puts("")
IO.puts("=== Framework Learning and Adaptation ===")

# Show how the framework learned and adapted
if successful_experiments > 0 do
  last_successful = 
    results
    |> Enum.filter(& &1.success)
    |> List.last()
  
  if Map.has_key?(last_successful.result, :framework_improvements) do
    improvements = last_successful.result.framework_improvements
    
    IO.puts("Framework improvements during experiments:")
    IO.puts("  - Exploration probability change: #{Float.round(improvements.exploration_probability_change, 3)}")
    IO.puts("  - Success threshold change: #{Float.round(improvements.success_threshold_change, 3)}")
    IO.puts("  - Parameters learned: #{improvements.parameters_learned}")
  end
end

# Generate recommendations for future problems
IO.puts("")
IO.puts("=== Recommendations for Future Problems ===")

sample_characteristics = %{
  complexity_level: "high",
  domain_type: "scientific",
  uncertainty_level: 0.8,
  multi_step_nature: true,
  creative_aspects: ["innovation", "synthesis"]
}

case Dspy.TrainingDataStorage.get_recommendations(sample_characteristics) do
  recommendations ->
    IO.puts("Based on training data, for high-complexity scientific problems:")
    
    if length(recommendations.recommended_strategies) > 0 do
      IO.puts("  Recommended strategies:")
      Enum.each(recommendations.recommended_strategies, fn strategy ->
        IO.puts("    - #{strategy}")
      end)
    end
    
    if length(recommendations.recommended_components) > 0 do
      IO.puts("  Recommended components:")
      Enum.each(recommendations.recommended_components, fn component ->
        IO.puts("    - #{component}")
      end)
    end
    
    IO.puts("  Estimated success probability: #{Float.round(recommendations.estimated_success_probability, 2)}")
    
    if length(recommendations.risk_factors) > 0 do
      IO.puts("  Risk factors to consider:")
      Enum.each(recommendations.risk_factors, fn risk ->
        IO.puts("    - #{risk}")
      end)
    end
end

IO.puts("")
IO.puts("=== Export Training Data ===")

# Export training data for external analysis
case Dspy.TrainingDataStorage.export_training_data(:json, %{success: true}) do
  exported_data ->
    filename = "successful_experiments_#{DateTime.utc_now() |> DateTime.to_unix()}.json"
    File.write!(filename, exported_data)
    IO.puts("✓ Exported successful experiments to #{filename}")
end

IO.puts("")
IO.puts("=== Continuous Learning Demonstration Complete ===")
IO.puts("")
IO.puts("The AI system has successfully:")
IO.puts("1. Generated novel reasoning systems dynamically")
IO.puts("2. Tested them on complex problems")
IO.puts("3. Stored all attempts as training data")
IO.puts("4. Learned from successes and failures")
IO.puts("5. Improved its generation strategies")
IO.puts("6. Built recommendations for future problems")
IO.puts("")
IO.puts("This creates a continuously improving AI system that gets better")
IO.puts("at generating novel approaches over time!")