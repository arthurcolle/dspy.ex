Mix.install([
  {:dspy, path: "."}
])

defmodule ComparativeReasoningExperiment do
  @moduledoc """
  Experiment comparing reasoning capabilities across different models and methods.
  Tests how various LLMs handle the same reasoning tasks with different approaches.
  """

  alias Dspy.{LM, Module, Signature, ChainOfThought, Predict, Settings}

  defmodule ReasoningTask do
    use Dspy.Signature

    field :problem, :input,
      desc: "A complex reasoning problem requiring analysis"

    field :constraints, :input,
      desc: "Any constraints or special requirements"

    field :analysis, :output,
      desc: "Step-by-step analysis of the problem"

    field :solution, :output,
      desc: "The final solution with justification"

    field :confidence, :output,
      desc: "Confidence level (1-10) with explanation"
  end

  defmodule ComparativeAnalysis do
    use Dspy.Signature

    field :task, :input,
      desc: "The reasoning task that was performed"

    field :results, :input,
      desc: "Results from different models/methods"

    field :comparison, :output,
      desc: "Comparative analysis of approaches"

    field :winner, :output,
      desc: "Best approach with justification"

    field :insights, :output,
      desc: "Key insights from the comparison"
  end

  def run_experiment do
    IO.puts("\n🔬 Comparative Reasoning Experiment")
    IO.puts("=" <> String.duplicate("=", 50))

    # Test problems
    problems = [
      %{
        problem: """
        A farmer needs to cross a river with a fox, a chicken, and a bag of grain.
        The boat can only carry the farmer and one item at a time.
        If left alone, the fox will eat the chicken, and the chicken will eat the grain.
        How can the farmer get everything across safely?
        """,
        constraints: "Must prevent any item from being eaten"
      },
      %{
        problem: """
        You have 12 identical-looking balls, but one is slightly heavier or lighter.
        Using a balance scale only 3 times, how can you identify the odd ball
        and determine whether it's heavier or lighter?
        """,
        constraints: "Exactly 3 weighings allowed"
      },
      %{
        problem: """
        In a tournament, every player plays every other player exactly once.
        If there were 45 games total, how many players were in the tournament?
        Explain the mathematical relationship.
        """,
        constraints: "Must show the formula derivation"
      }
    ]

    # Models to test
    models = [
      {"gpt-4", "gpt-4"},
      {"gpt-4-turbo", "gpt-4-turbo-preview"},
      {"gpt-3.5", "gpt-3.5-turbo"}
    ]

    # Methods to test
    methods = [
      {"Chain of Thought", &use_chain_of_thought/2},
      {"Direct Predict", &use_direct_predict/2},
      {"Self-Consistency", &use_self_consistency/2}
    ]

    Enum.each(problems, fn problem ->
      IO.puts("\n📝 Problem: #{String.slice(problem.problem, 0..100)}...")
      IO.puts("📋 Constraints: #{problem.constraints}")
      IO.puts("\n")

      results = []

      # Test each model with each method
      for {model_name, model_id} <- models,
          {method_name, method_fn} <- methods do
        
        IO.puts("🤖 Testing #{model_name} with #{method_name}...")
        
        # Configure model
        configure_model(model_id)
        
        # Run method
        result = method_fn.(problem, model_name)
        
        results = results ++ [%{
          model: model_name,
          method: method_name,
          result: result
        }]
        
        # Display result
        display_result(model_name, method_name, result)
      end

      # Comparative analysis
      IO.puts("\n📊 Comparative Analysis")
      IO.puts("-" <> String.duplicate("-", 40))
      
      analyze_results(problem, results)
    end)

    IO.puts("\n✅ Experiment complete!")
  end

  defp configure_model(model_id) do
    lm = LM.init(%{
      model: model_id,
      temperature: 0.7,
      max_tokens: 1000
    })
    
    Settings.configure(%{lm: lm})
  end

  defp use_chain_of_thought(problem, _model_name) do
    module = Module.new(%{
      predict_reasoning: ChainOfThought.new(%{
        signature: ReasoningTask
      })
    })

    case Module.forward(module, %{
      predict_reasoning: %{
        problem: problem.problem,
        constraints: problem.constraints
      }
    }) do
      {:ok, result} ->
        result.predict_reasoning
      {:error, error} ->
        %{error: error}
    end
  end

  defp use_direct_predict(problem, _model_name) do
    module = Module.new(%{
      predict_reasoning: Predict.new(%{
        signature: ReasoningTask
      })
    })

    case Module.forward(module, %{
      predict_reasoning: %{
        problem: problem.problem,
        constraints: problem.constraints
      }
    }) do
      {:ok, result} ->
        result.predict_reasoning
      {:error, error} ->
        %{error: error}
    end
  end

  defp use_self_consistency(problem, _model_name) do
    # Run multiple times and aggregate
    results = Enum.map(1..3, fn _ ->
      module = Module.new(%{
        predict_reasoning: ChainOfThought.new(%{
          signature: ReasoningTask
        })
      })

      case Module.forward(module, %{
        predict_reasoning: %{
          problem: problem.problem,
          constraints: problem.constraints
        }
      }) do
        {:ok, result} -> result.predict_reasoning
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))

    # Aggregate results
    if length(results) > 0 do
      %{
        analysis: aggregate_field(results, :analysis),
        solution: aggregate_field(results, :solution),
        confidence: average_confidence(results)
      }
    else
      %{error: "All attempts failed"}
    end
  end

  defp aggregate_field(results, field) do
    results
    |> Enum.map(&Map.get(&1, field, ""))
    |> Enum.join("\n\n---\n\n")
  end

  defp average_confidence(results) do
    confidences = results
    |> Enum.map(fn r ->
      case Integer.parse(Map.get(r, :confidence, "5")) do
        {num, _} -> num
        _ -> 5
      end
    end)
    
    avg = Enum.sum(confidences) / length(confidences)
    "#{Float.round(avg, 1)}/10 (averaged from #{length(confidences)} runs)"
  end

  defp display_result(model, method, result) do
    if Map.has_key?(result, :error) do
      IO.puts("   ❌ Error: #{result.error}")
    else
      IO.puts("   ✅ Solution: #{String.slice(result[:solution] || "", 0..100)}...")
      IO.puts("   📊 Confidence: #{result[:confidence] || "N/A"}")
    end
  end

  defp analyze_results(problem, results) do
    # Configure GPT-4 for analysis
    configure_model("gpt-4")
    
    module = Module.new(%{
      analyze: ChainOfThought.new(%{
        signature: ComparativeAnalysis
      })
    })

    results_text = Enum.map(results, fn r ->
      """
      Model: #{r.model}, Method: #{r.method}
      Result: #{inspect(r.result, pretty: true, limit: :infinity)}
      """
    end) |> Enum.join("\n---\n")

    case Module.forward(module, %{
      analyze: %{
        task: problem.problem,
        results: results_text
      }
    }) do
      {:ok, analysis} ->
        IO.puts("🏆 Winner: #{analysis.analyze.winner}")
        IO.puts("💡 Insights: #{analysis.analyze.insights}")
        IO.puts("\n📝 Full Comparison:")
        IO.puts(analysis.analyze.comparison)
      {:error, error} ->
        IO.puts("❌ Analysis failed: #{error}")
    end
  end
end

# Run the experiment
ComparativeReasoningExperiment.run_experiment()