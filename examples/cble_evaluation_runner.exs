#!/usr/bin/env elixir

# CBLE Evaluation Runner
# Comprehensive evaluation of DSPy agents across GPT models on CBLE exam data

Mix.install([
  {:dspy, path: ".."},
  {:jason, "~> 1.4"}
])

defmodule CBLEEvaluationRunner do
  @moduledoc """
  Runner for CBLE (Customs Broker License Examination) evaluation.
  
  This script:
  1. Extracts content from CBLE PDF files (including images)
  2. Processes questions and maps to answer keys
  3. Evaluates DSPy agents across gpt-4.1, gpt-4.1-mini, and gpt-4.1-nano
  4. Generates comprehensive analysis and reports
  """

  require Logger

  def run do
    IO.puts("\n🏛️  CBLE Evaluation Harness")
    IO.puts("=" |> String.duplicate(50))
    
    # Check dependencies
    case check_dependencies() do
      :ok -> 
        IO.puts("✅ Dependencies check passed")
      {:error, missing} ->
        IO.puts("❌ Missing dependencies: #{Enum.join(missing, ", ")}")
        IO.puts("Please install: pip install PyMuPDF PyPDF2 Pillow")
        {:error, :missing_dependencies}
    end
    
    # Configuration
    config = setup_configuration()
    IO.puts("📋 Configuration:")
    IO.puts("   CBLE Dataset: #{config.exam_data_path}")
    IO.puts("   Output Path: #{config.output_path}")
    IO.puts("   Models: #{Enum.map(config.models, & &1.name) |> Enum.join(", ")}")
    IO.puts("   Exam Dates: #{Enum.join(config.exam_dates, ", ")}")
    
    # Create evaluation harness
    harness = Dspy.CBLEEvalHarness.new([
      exam_data_path: config.exam_data_path,
      output_path: config.output_path,
      models: config.models,
      exam_dates: config.exam_dates,
      categories: config.categories,
      max_questions: config.max_questions,
      evaluation_config: config.evaluation_config
    ])
    
    # Run evaluation
    case run_full_evaluation(harness) do
      {:ok, results} ->
        IO.puts("\n🎉 CBLE Evaluation completed successfully!")
        display_summary(results)
        {:ok, results}
      
      {:error, reason} ->
        IO.puts("\n❌ CBLE Evaluation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def run_sample_evaluation do
    IO.puts("\n🧪 CBLE Sample Evaluation (Limited)")
    IO.puts("=" |> String.duplicate(50))
    
    # Quick test with limited scope
    config = setup_configuration()
    
    harness = Dspy.CBLEEvalHarness.new([
      exam_data_path: config.exam_data_path,
      output_path: config.output_path,
      models: [List.first(config.models)],  # Only test one model
      exam_dates: [List.first(config.exam_dates)],  # Only test one exam
      max_questions: 5,  # Limit to 5 questions for quick test
      evaluation_config: %{
        enable_reasoning_analysis: true,
        enable_vision_analysis: true,
        parallel_evaluation: false,  # Sequential for easier debugging
        max_retries: 1
      }
    ])
    
    case run_full_evaluation(harness) do
      {:ok, results} ->
        IO.puts("\n✅ Sample evaluation completed!")
        display_summary(results)
        {:ok, results}
      
      {:error, reason} ->
        IO.puts("\n❌ Sample evaluation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def test_pdf_extraction do
    IO.puts("\n📄 Testing PDF Extraction")
    IO.puts("=" |> String.duplicate(50))
    
    config = setup_configuration()
    harness = Dspy.CBLEEvalHarness.new(exam_data_path: config.exam_data_path)
    
    # Test extraction on available PDF files
    exam_dates = ["2023-Oct", "2023-Apr", "2024-Apr"]
    
    Enum.each(exam_dates, fn exam_date ->
      IO.puts("\n📋 Testing extraction for #{exam_date}:")
      
      exam_file = Path.join([
        config.exam_data_path, 
        "past_exams_and_keys", 
        "pdf", 
        "#{exam_date}-exam.pdf"
      ])
      
      case File.exists?(exam_file) do
        true ->
          IO.puts("   Found: #{exam_file}")
          
          case Dspy.CBLEEvalHarness.extract_pdf_content(harness, exam_file) do
            {:ok, content} ->
              pages = content["pages"] || []
              total_images = Enum.sum(Enum.map(pages, fn p -> length(p["images"] || []) end))
              total_text = Enum.sum(Enum.map(pages, fn p -> String.length(p["text"] || "") end))
              
              IO.puts("   ✅ Extracted successfully")
              IO.puts("      Pages: #{length(pages)}")
              IO.puts("      Total Images: #{total_images}")
              IO.puts("      Total Text Length: #{total_text} chars")
              
              if total_images > 0 do
                IO.puts("      📸 Contains images - vision processing will be enabled")
              end
              
            {:error, reason} ->
              IO.puts("   ❌ Extraction failed: #{inspect(reason)}")
          end
          
        false ->
          IO.puts("   ⚠️  File not found: #{exam_file}")
      end
    end)
  end

  def test_single_question do
    IO.puts("\n❓ Testing Single Question Processing")
    IO.puts("=" |> String.duplicate(50))
    
    # Test with a sample question
    sample_question = %{
      question_id: "test_q1",
      question_text: """
      A shipment of electronic components arrives from China with a commercial invoice 
      showing a transaction value of $50,000. The importer provides additional information
      that $5,000 in engineering costs were incurred in the United States to develop
      the specifications for these components. 
      
      What is the correct customs value for duty assessment purposes?
      
      A. $50,000 - transaction value only
      B. $55,000 - transaction value plus assists
      C. $45,000 - transaction value minus assists  
      D. $50,000 - assists are not dutiable
      E. Insufficient information to determine value
      """,
      images: [],
      options: [
        "A. $50,000 - transaction value only",
        "B. $55,000 - transaction value plus assists", 
        "C. $45,000 - transaction value minus assists",
        "D. $50,000 - assists are not dutiable",
        "E. Insufficient information to determine value"
      ],
      correct_answer: "B",
      category: "Valuation",
      page_number: 1,
      difficulty: :medium,
      has_images: false,
      exam_date: "test"
    }
    
    config = setup_configuration()
    harness = Dspy.CBLEEvalHarness.new(models: [List.first(config.models)])
    
    IO.puts("📝 Testing question: #{String.slice(sample_question.question_text, 0, 100)}...")
    
    case Dspy.CBLEEvalHarness.evaluate_question(harness, sample_question) do
      {:ok, results} ->
        result = List.first(results)
        
        IO.puts("\n✅ Question evaluation completed!")
        IO.puts("   Model: #{result.model}")
        IO.puts("   Agent Answer: #{result.agent_answer}")
        IO.puts("   Correct Answer: #{result.correct_answer}")
        IO.puts("   Correct: #{result.is_correct}")
        IO.puts("   Confidence: #{result.confidence}")
        IO.puts("   Execution Time: #{result.execution_time}ms")
        IO.puts("   Cost: $#{result.cost}")
        
        if result.reasoning do
          IO.puts("\n🧠 Reasoning:")
          IO.puts("   #{String.slice(result.reasoning, 0, 200)}...")
        end
        
      {:error, reason} ->
        IO.puts("❌ Question evaluation failed: #{inspect(reason)}")
    end
  end

  defp check_dependencies do
    missing = []
    
    # Check Python and required packages
    missing = case System.cmd("python3", ["-c", "import PyPDF2, fitz, PIL"], stderr_to_stdout: true) do
      {_, 0} -> missing
      {error, _} -> 
        if String.contains?(error, "No module named") do
          ["Python PDF packages (PyPDF2, PyMuPDF, Pillow)" | missing]
        else
          missing
        end
    end
    
    # Check for OpenAI API key
    missing = case System.get_env("OPENAI_API_KEY") do
      nil -> ["OPENAI_API_KEY environment variable" | missing]
      "" -> ["OPENAI_API_KEY environment variable" | missing]
      _ -> missing
    end
    
    case missing do
      [] -> :ok
      _ -> {:error, missing}
    end
  end

  defp setup_configuration do
    %{
      exam_data_path: System.get_env("CBLE_DATASET_PATH") || "/Users/agent/evalscompany/cble_dataset",
      output_path: System.get_env("CBLE_OUTPUT_PATH") || "/Users/agent/dspy/cble_results",
      models: [
        %{
          name: "GPT-4.1",
          model_id: "gpt-4.1",
          temperature: 0.1,
          max_tokens: 2000,
          cost_per_token: 0.00003
        },
        %{
          name: "GPT-4.1-Mini",
          model_id: "gpt-4.1-mini",
          temperature: 0.1,
          max_tokens: 2000,
          cost_per_token: 0.00001
        },
        %{
          name: "GPT-4.1-Nano",
          model_id: "gpt-4.1-nano",
          temperature: 0.1,
          max_tokens: 1500,
          cost_per_token: 0.000005
        }
      ],
      exam_dates: ["2023-Oct", "2023-Apr", "2024-Apr"],
      categories: nil,  # nil = all categories
      max_questions: get_max_questions(),
      evaluation_config: %{
        enable_reasoning_analysis: true,
        enable_confidence_calibration: true,
        enable_category_analysis: true,
        enable_difficulty_analysis: true,
        enable_cost_analysis: true,
        enable_vision_analysis: true,
        save_intermediate_results: true,
        parallel_evaluation: true,
        max_retries: 2
      }
    }
  end

  defp get_max_questions do
    case System.get_env("CBLE_MAX_QUESTIONS") do
      nil -> nil  # No limit
      "" -> nil
      value -> 
        case Integer.parse(value) do
          {num, _} when num > 0 -> num
          _ -> nil
        end
    end
  end

  defp run_full_evaluation(harness) do
    start_time = System.monotonic_time(:millisecond)
    
    IO.puts("\n🚀 Starting CBLE evaluation...")
    
    # Run the evaluation
    case Dspy.CBLEEvalHarness.run_evaluation(harness) do
      {:ok, results} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        IO.puts("⏱️  Total evaluation time: #{Float.round(duration / 1000, 2)} seconds")
        {:ok, results}
      
      error -> error
    end
  end

  defp display_summary(results) do
    analysis = results.analysis
    
    IO.puts("\n📊 Evaluation Summary:")
    IO.puts("=" |> String.duplicate(30))
    
    # Overall performance
    overall = analysis.overall_performance
    IO.puts("📈 Overall Performance:")
    IO.puts("   Questions Evaluated: #{overall.total_questions}")
    IO.puts("   Success Rate: #{Float.round(overall.success_rate * 100, 1)}%")
    IO.puts("   Overall Accuracy: #{Float.round(overall.overall_accuracy * 100, 1)}%")
    IO.puts("   Average Confidence: #{Float.round(overall.average_confidence, 3)}")
    IO.puts("   Total Cost: $#{Float.round(overall.total_cost, 4)}")
    
    # Model comparison
    IO.puts("\n🤖 Model Performance:")
    Enum.each(analysis.model_comparison, fn {model, stats} ->
      IO.puts("   #{model}:")
      IO.puts("     Accuracy: #{Float.round(stats.accuracy * 100, 1)}%")
      IO.puts("     Success Rate: #{Float.round(stats.success_rate * 100, 1)}%")
      IO.puts("     Cost: $#{Float.round(stats.total_cost, 4)}")
      IO.puts("     Cost/Correct: $#{Float.round(stats.cost_per_correct_answer, 6)}")
    end)
    
    # Category performance
    if map_size(analysis.category_analysis) > 0 do
      IO.puts("\n📚 Category Performance:")
      analysis.category_analysis
      |> Enum.sort_by(fn {_, stats} -> stats.accuracy end, :desc)
      |> Enum.take(5)  # Top 5 categories
      |> Enum.each(fn {category, stats} ->
        IO.puts("   #{category}: #{Float.round(stats.accuracy * 100, 1)}% (#{stats.questions_count} questions)")
      end)
    end
    
    # Vision analysis
    vision = analysis.vision_analysis
    if vision.vision_questions_count > 0 do
      IO.puts("\n👁️  Vision Analysis:")
      IO.puts("   Vision Questions: #{vision.vision_questions_count}")
      IO.puts("   Vision Accuracy: #{Float.round(vision.vision_accuracy * 100, 1)}%")
      IO.puts("   Text-Only Accuracy: #{Float.round(vision.non_vision_accuracy * 100, 1)}%")
      
      diff = vision.vision_vs_text_performance.accuracy_difference
      if diff > 0 do
        IO.puts("   📈 Vision questions perform #{Float.round(diff * 100, 1)}% better")
      else
        IO.puts("   📉 Vision questions perform #{Float.round(abs(diff) * 100, 1)}% worse")
      end
    end
    
    # Cost efficiency
    IO.puts("\n💰 Cost Analysis:")
    IO.puts("   Most Cost Efficient: #{analysis.cost_analysis.most_cost_efficient_model}")
    IO.puts("   Cost per Question: $#{Float.round(analysis.cost_analysis.cost_per_question, 6)}")
    IO.puts("   Cost per Correct Answer: $#{Float.round(analysis.cost_analysis.cost_per_correct_answer, 6)}")
    
    IO.puts("\n📁 Results saved to: #{results.output_path}")
  end
end

# Command line interface
case System.argv() do
  ["full"] -> 
    CBLEEvaluationRunner.run()
  
  ["sample"] -> 
    CBLEEvaluationRunner.run_sample_evaluation()
  
  ["test-pdf"] -> 
    CBLEEvaluationRunner.test_pdf_extraction()
  
  ["test-question"] ->
    CBLEEvaluationRunner.test_single_question()
  
  _ ->
    IO.puts("""
    🏛️  CBLE Evaluation Runner
    
    Usage:
      elixir cble_evaluation_runner.exs [command]
    
    Commands:
      full           - Run complete CBLE evaluation across all models
      sample         - Run limited evaluation for testing (5 questions, 1 model)
      test-pdf       - Test PDF extraction capabilities
      test-question  - Test single question processing
    
    Environment Variables:
      OPENAI_API_KEY        - Required: OpenAI API key
      CBLE_DATASET_PATH     - Path to CBLE dataset (default: /Users/agent/evalscompany/cble_dataset)
      CBLE_OUTPUT_PATH      - Output directory (default: /Users/agent/dspy/cble_results)
      CBLE_MAX_QUESTIONS    - Limit number of questions (default: no limit)
    
    Examples:
      export OPENAI_API_KEY="your-key-here"
      export CBLE_MAX_QUESTIONS="50"
      elixir cble_evaluation_runner.exs sample
    """)
end