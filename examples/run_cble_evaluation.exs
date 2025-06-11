#!/usr/bin/env elixir

# Simple wrapper to run CBLE evaluation without Mix.install
# This assumes DSPy is already compiled in the current project

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
        # Build the evaluation harness
        harness = build_harness()
        
        # Run the evaluation
        case run_full_evaluation(harness) do
          {:ok, results} ->
            # Display summary
            display_summary(results)
            
          {:error, reason} ->
            IO.puts("\n❌ Evaluation failed: #{inspect(reason)}")
        end
        
      {:error, missing} ->
        IO.puts("\n❌ Missing dependencies:")
        Enum.each(missing, &IO.puts("   - #{&1}"))
        IO.puts("\nPlease install missing dependencies and try again.")
    end
  end

  def run_sample_evaluation do
    IO.puts("\n🏛️  CBLE Sample Evaluation (5 questions)")
    IO.puts("=" |> String.duplicate(50))
    
    # Check dependencies
    case check_dependencies() do
      :ok -> 
        # Build the evaluation harness with limited questions
        harness = build_harness(max_questions: 5)
        
        # Run the evaluation
        case run_full_evaluation(harness) do
          {:ok, results} ->
            # Display summary
            display_summary(results)
            
          {:error, reason} ->
            IO.puts("\n❌ Evaluation failed: #{inspect(reason)}")
        end
        
      {:error, missing} ->
        IO.puts("\n❌ Missing dependencies:")
        Enum.each(missing, &IO.puts("   - #{&1}"))
        IO.puts("\nPlease install missing dependencies and try again.")
    end
  end

  def test_pdf_extraction do
    IO.puts("\n🧪 Testing PDF extraction...")
    
    # Create a simple harness just for PDF testing
    harness = %Dspy.CBLEEvalHarness{
      output_path: "cble_results/test_extraction"
    }
    
    # Test PDF extraction
    pdf_files = [
      {"April_2022", "cble_results/raw_data/April_2022_CBLE.pdf"},
      {"October_2022", "cble_results/raw_data/October_2022_CBLE.pdf"}
    ]
    
    Enum.each(pdf_files, fn {exam_date, pdf_path} ->
      IO.puts("\n📄 Testing: #{pdf_path}")
      
      case File.exists?(pdf_path) do
        true ->
          case Dspy.CBLEEvalHarness.extract_pdf_content(harness, exam_date, pdf_path) do
            {:ok, content} ->
              IO.puts("✅ Successfully extracted content")
              IO.puts("   Total pages: #{length(content.pages)}")
              IO.puts("   Has images: #{Enum.any?(content.pages, fn p -> length(Map.get(p, :images, [])) > 0 end)}")
              
              # Show first page preview
              if first_page = List.first(content.pages) do
                text_preview = first_page.text
                |> String.slice(0, 200)
                |> String.replace(~r/\s+/, " ")
                
                IO.puts("   Preview: #{text_preview}...")
              end
              
            {:error, reason} ->
              IO.puts("❌ Extraction failed: #{inspect(reason)}")
          end
          
        false ->
          IO.puts("❌ File not found")
      end
    end)
  end

  def test_single_question do
    IO.puts("\n🧪 Testing single question evaluation...")
    
    # Check for API key
    case System.get_env("OPENAI_API_KEY") do
      nil -> 
        IO.puts("❌ OPENAI_API_KEY not set")
        
      _ ->
        # Create evaluation harness
        harness = build_harness()
        
        # Create a sample question
        question = %{
          question_number: "TEST_1",
          question_text: "What is the primary purpose of a customs bond?",
          choices: %{
            "A" => "To ensure payment of duties and taxes",
            "B" => "To speed up customs clearance",
            "C" => "To reduce inspection requirements",
            "D" => "To eliminate documentation requirements"
          },
          correct_answer: "A",
          category: "Customs Bonds",
          has_image: false,
          images: []
        }
        
        IO.puts("\n📝 Question: #{question.question_text}")
        IO.puts("   Choices:")
        Enum.each(question.choices, fn {letter, text} ->
          IO.puts("     #{letter}. #{text}")
        end)
        IO.puts("   Correct: #{question.correct_answer}")
        
        # Test with each model
        models = ["gpt-4o", "gpt-4o-mini"]
        
        Enum.each(models, fn model ->
          IO.puts("\n🤖 Testing with #{model}...")
          
          case Dspy.CBLEEvalHarness.evaluate_single_question(harness, question, model) do
            {:ok, result} ->
              IO.puts("✅ Answer: #{result.predicted_answer}")
              IO.puts("   Correct: #{result.is_correct}")
              IO.puts("   Confidence: #{Float.round(result.confidence, 3)}")
              
              if result.reasoning do
                IO.puts("   Reasoning: #{String.slice(result.reasoning, 0, 200)}...")
              end
              
            {:error, reason} ->
              IO.puts("❌ Evaluation failed: #{inspect(reason)}")
          end
        end)
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

  defp build_harness(opts \\ []) do
    max_questions = Keyword.get(opts, :max_questions, get_max_questions())
    
    %Dspy.CBLEEvalHarness{
      pdf_files: [
        {"April_2022", "cble_results/raw_data/April_2022_CBLE.pdf"},
        {"October_2022", "cble_results/raw_data/October_2022_CBLE.pdf"},
        {"April_2023", "cble_results/raw_data/April_2023_CBLE.pdf"},
        {"October_2023", "cble_results/raw_data/October_2023_CBLE.pdf"}
      ],
      answer_keys: [
        {"April_2022", "cble_results/raw_data/April_2022_Answer_Key.pdf"},
        {"October_2022", "cble_results/raw_data/October_2022_Answer_Key.pdf"},
        {"April_2023", "cble_results/raw_data/April_2023_Answer_Key.pdf"},
        {"October_2023", "cble_results/raw_data/October_2023_Answer_Key.pdf"}
      ],
      models: ["gpt-4o", "gpt-4o-mini"],
      output_path: "cble_results/evaluation_#{DateTime.utc_now() |> DateTime.to_unix()}",
      max_questions: max_questions,
      evaluation_config: %{
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
    Usage: elixir #{__ENV__.file} [command]
    
    Commands:
      full          - Run full CBLE evaluation across all exam PDFs
      sample        - Run evaluation on 5 sample questions
      test-pdf      - Test PDF extraction functionality
      test-question - Test evaluation on a single sample question
    
    Environment variables:
      OPENAI_API_KEY       - Required for model evaluation
      CBLE_MAX_QUESTIONS   - Limit number of questions evaluated (optional)
    
    Example:
      export OPENAI_API_KEY=your_key_here
      elixir #{__ENV__.file} sample
    """)
end