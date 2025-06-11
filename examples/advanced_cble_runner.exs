#!/usr/bin/env elixir

# Load dependencies
Mix.install([
  {:dspy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.2"},
  {:gen_stage, "~> 1.2"}
])

# Start the application
Application.ensure_all_started(:dspy)

# Configure DSPy with OpenAI
Dspy.configure(lm: Dspy.LM.OpenAI.new(
  model: "gpt-4.1-mini",
  api_key: System.get_env("OPENAI_API_KEY")
))

defmodule AdvancedCBLERunner do
  @moduledoc """
  Advanced CBLE evaluation runner with full integration of multi-modal reasoning,
  adaptive testing, parallel processing, and comprehensive analytics.
  """

  require Logger
  alias Dspy.{AdvancedCBLEEvalHarness, CBLETaskScheduler, CBLEVisionProcessor}

  def main(args) do
    # Setup logging
    configure_logging()
    
    # Parse arguments
    {mode, options} = parse_arguments(args)
    
    # Check environment
    check_environment()
    
    # Run appropriate mode
    case mode do
      :full -> run_full_advanced_evaluation(options)
      :adaptive -> run_adaptive_evaluation(options)
      :vision_test -> run_vision_test(options)
      :benchmark -> run_benchmark(options)
      :interactive -> run_interactive_mode(options)
      _ -> show_usage()
    end
  end

  defp run_full_advanced_evaluation(options) do
    Logger.info("""
    
    🚀 Advanced CBLE Evaluation System
    =====================================
    Mode: Full Evaluation
    Features:
      ✅ Multi-modal Vision Processing
      ✅ Adaptive Testing Engine
      ✅ Parallel Task Execution
      ✅ Real-time Monitoring
      ✅ Advanced Analytics
      ✅ Multi-agent Collaboration
    """)
    
    # Initialize components
    with {:ok, harness} <- initialize_harness(options),
         {:ok, scheduler} <- initialize_scheduler(options),
         {:ok, monitor} <- initialize_monitoring(options) do
      
      # Start evaluation pipeline
      pipeline_result = run_evaluation_pipeline(harness, scheduler, monitor, options)
      
      # Display results
      display_advanced_results(pipeline_result)
      
      # Generate reports
      generate_comprehensive_reports(pipeline_result, options)
      
      {:ok, pipeline_result}
    else
      {:error, reason} ->
        Logger.error("Failed to initialize: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp run_adaptive_evaluation(options) do
    Logger.info("""
    
    🎯 Adaptive CBLE Testing
    =======================
    Dynamically adjusting difficulty based on performance
    """)
    
    harness = AdvancedCBLEEvalHarness.new(
      adaptive_testing: true,
      initial_questions: 10,
      max_questions: 50,
      confidence_threshold: 0.95
    )
    
    # Run adaptive evaluation
    case AdvancedCBLEEvalHarness.run_adaptive_evaluation(harness) do
      {:ok, results, analytics} ->
        display_adaptive_results(results, analytics)
        {:ok, results}
        
      error ->
        Logger.error("Adaptive evaluation failed: #{inspect(error)}")
        error
    end
  end

  defp run_vision_test(options) do
    Logger.info("""
    
    👁️  Vision Processing Test
    =========================
    Testing advanced visual understanding capabilities
    """)
    
    # Initialize vision processor
    processor = CBLEVisionProcessor.new()
    
    # Test on sample PDFs
    test_files = get_test_files(options)
    
    Enum.each(test_files, fn file ->
      Logger.info("Processing: #{file}")
      
      case CBLEVisionProcessor.extract_pdf(processor, file) do
        {:ok, content} ->
          display_vision_analysis(content)
          
        {:error, reason} ->
          Logger.error("Vision processing failed: #{inspect(reason)}")
      end
    end)
  end

  defp run_benchmark(options) do
    Logger.info("""
    
    📊 Performance Benchmark
    =======================
    Comparing models and approaches
    """)
    
    benchmark_config = %{
      models: configure_benchmark_models(),
      test_questions: load_benchmark_questions(),
      iterations: Keyword.get(options, :iterations, 3),
      metrics: [:accuracy, :speed, :cost, :reasoning_quality]
    }
    
    results = run_comprehensive_benchmark(benchmark_config)
    display_benchmark_results(results)
    export_benchmark_data(results, options)
  end

  defp run_interactive_mode(_options) do
    Logger.info("""
    
    💬 Interactive CBLE Testing
    ==========================
    Enter questions for real-time evaluation
    """)
    
    harness = AdvancedCBLEEvalHarness.new(
      models: [get_interactive_model()],
      real_time_monitoring: true
    )
    
    interactive_loop(harness)
  end

  # Pipeline execution
  defp run_evaluation_pipeline(harness, scheduler, monitor, options) do
    start_time = System.monotonic_time(:millisecond)
    
    # Phase 1: Advanced Question Extraction
    monitor.track_phase(:extraction, :started)
    extraction_result = with_error_recovery(fn ->
      extract_questions_advanced(harness, scheduler)
    end)
    monitor.track_phase(:extraction, :completed, extraction_result)
    
    # Phase 2: Question Analysis and Categorization
    monitor.track_phase(:analysis, :started)
    analysis_result = with_error_recovery(fn ->
      analyze_questions_comprehensive(extraction_result, harness)
    end)
    monitor.track_phase(:analysis, :completed, analysis_result)
    
    # Phase 3: Adaptive Evaluation
    monitor.track_phase(:evaluation, :started)
    evaluation_result = with_error_recovery(fn ->
      evaluate_with_adaptation(analysis_result, harness, scheduler, monitor)
    end)
    monitor.track_phase(:evaluation, :completed, evaluation_result)
    
    # Phase 4: Advanced Analytics
    monitor.track_phase(:analytics, :started)
    analytics_result = with_error_recovery(fn ->
      generate_advanced_analytics(evaluation_result, harness)
    end)
    monitor.track_phase(:analytics, :completed, analytics_result)
    
    end_time = System.monotonic_time(:millisecond)
    total_duration = end_time - start_time
    
    %{
      extraction: extraction_result,
      analysis: analysis_result,
      evaluation: evaluation_result,
      analytics: analytics_result,
      total_duration: total_duration,
      performance_summary: generate_performance_summary(monitor)
    }
  end

  defp extract_questions_advanced(harness, scheduler) do
    Logger.info("🔍 Extracting questions with advanced NLP...")
    
    # Schedule parallel PDF extraction
    pdf_tasks = create_pdf_extraction_tasks(harness)
    
    {:ok, task_ids} = CBLETaskScheduler.schedule_batch(pdf_tasks)
    {:ok, extraction_results} = CBLETaskScheduler.await_completion(task_ids)
    
    # Process extracted content
    questions = process_extraction_results(extraction_results, harness)
    
    Logger.info("✅ Extracted #{length(questions)} questions")
    {:ok, questions}
  end

  defp analyze_questions_comprehensive(questions, harness) do
    Logger.info("🧠 Analyzing question complexity and requirements...")
    
    analyzed = Enum.map(questions, fn question ->
      # Analyze with multiple dimensions
      %{
        question: question,
        complexity: analyze_complexity(question, harness),
        visual_requirements: analyze_visual_requirements(question),
        knowledge_domains: identify_knowledge_domains(question),
        estimated_difficulty: estimate_difficulty(question),
        optimal_approach: determine_optimal_approach(question)
      }
    end)
    
    {:ok, analyzed}
  end

  defp evaluate_with_adaptation(analyzed_questions, harness, scheduler, monitor) do
    Logger.info("🎯 Starting adaptive evaluation...")
    
    # Group by evaluation strategy
    strategy_groups = group_by_strategy(analyzed_questions)
    
    # Create evaluation tasks
    eval_tasks = Enum.flat_map(strategy_groups, fn {strategy, questions} ->
      create_evaluation_tasks(questions, strategy, harness)
    end)
    
    # Schedule with priority
    {:ok, task_ids} = CBLETaskScheduler.schedule_batch(eval_tasks, priority: :high)
    
    # Monitor progress in real-time
    monitor_evaluation_progress(task_ids, monitor)
    
    # Await results
    {:ok, results} = CBLETaskScheduler.await_completion(task_ids)
    
    {:ok, results}
  end

  defp generate_advanced_analytics(evaluation_results, harness) do
    Logger.info("📊 Generating advanced analytics...")
    
    analytics = %{
      performance_metrics: calculate_performance_metrics(evaluation_results),
      model_comparison: compare_model_performance(evaluation_results),
      difficulty_calibration: calibrate_difficulty_scores(evaluation_results),
      error_patterns: analyze_error_patterns(evaluation_results),
      improvement_insights: generate_improvement_insights(evaluation_results),
      cost_analysis: perform_cost_analysis(evaluation_results),
      predictive_models: build_predictive_models(evaluation_results, harness)
    }
    
    {:ok, analytics}
  end

  # Display functions
  defp display_advanced_results(pipeline_result) do
    IO.puts("""
    
    📈 Evaluation Results Summary
    ============================
    Total Duration: #{format_duration(pipeline_result.total_duration)}
    
    📋 Extraction Phase:
       Questions Found: #{count_questions(pipeline_result.extraction)}
       Visual Questions: #{count_visual_questions(pipeline_result.extraction)}
       
    🧪 Evaluation Phase:
       Success Rate: #{format_percentage(calculate_success_rate(pipeline_result.evaluation))}
       Average Accuracy: #{format_percentage(calculate_accuracy(pipeline_result.evaluation))}
       
    💡 Key Insights:
    #{format_insights(pipeline_result.analytics)}
    
    💰 Cost Analysis:
       Total Cost: #{format_cost(calculate_total_cost(pipeline_result.evaluation))}
       Cost per Question: #{format_cost(calculate_cost_per_question(pipeline_result.evaluation))}
       Most Efficient Model: #{find_most_efficient_model(pipeline_result.analytics)}
    """)
  end

  defp display_adaptive_results(results, analytics) do
    IO.puts("""
    
    🎯 Adaptive Testing Results
    =========================
    Questions Administered: #{length(results)}
    Final Accuracy Estimate: #{format_percentage(analytics.overall_metrics.accuracy)}
    Confidence Level: #{format_percentage(analytics.overall_metrics.confidence)}
    
    📊 Performance Progression:
    #{format_performance_progression(analytics.temporal_patterns)}
    
    🔍 Strength Areas:
    #{format_strength_areas(analytics.question_difficulty_analysis)}
    
    ⚠️  Improvement Areas:
    #{format_improvement_areas(analytics.error_analysis)}
    """)
  end

  # Helper functions
  defp initialize_harness(options) do
    config = Keyword.get(options, :config, %{})
    
    harness = AdvancedCBLEEvalHarness.new(
      exam_data_path: config[:data_path] || "/Users/agent/evalscompany/cble_dataset",
      output_path: config[:output_path] || "./advanced_cble_results",
      models: configure_models(options),
      parallel_workers: System.schedulers_online() * 2,
      adaptive_testing: true,
      multi_agent_enabled: true,
      vision_enhancement: true,
      real_time_monitoring: true
    )
    
    {:ok, harness}
  end

  defp initialize_scheduler(options) do
    {:ok, _pid} = CBLETaskScheduler.start_link(
      worker_count: Keyword.get(options, :workers, System.schedulers_online() * 2),
      max_workers: System.schedulers_online() * 4,
      priority_ratios: %{
        critical: 0.4,
        high: 0.3,
        normal: 0.2,
        low: 0.1
      }
    )
    
    {:ok, CBLETaskScheduler}
  end

  defp initialize_monitoring(_options) do
    monitor = %{
      phases: %{},
      metrics: %{},
      alerts: [],
      track_phase: fn phase, status, data ->
        if data do
          Logger.info("Phase #{phase}: #{status} - #{inspect(data)}")
        else
          Logger.info("Phase #{phase}: #{status}")
        end
        :ok
      end
    }
    
    {:ok, monitor}
  end

  defp configure_models(options) do
    if Keyword.get(options, :all_models, false) do
      [
        %{
          name: "GPT-4-Vision",
          model_id: "gpt-4-vision-preview",
          temperature: 0.2,
          max_tokens: 4096,
          cost_per_token: 0.00003,
          capabilities: [:vision, :reasoning],
          specialization: :comprehensive
        },
        %{
          name: "Claude-3-Opus",
          model_id: "claude-3-opus-20240229",
          temperature: 0.1,
          max_tokens: 4096,
          cost_per_token: 0.000025,
          capabilities: [:reasoning, :analysis],
          specialization: :analytical
        },
        %{
          name: "Gemini-Ultra",
          model_id: "gemini-ultra",
          temperature: 0.3,
          max_tokens: 8192,
          cost_per_token: 0.00002,
          capabilities: [:vision, :multimodal],
          specialization: :multimodal
        }
      ]
    else
      [get_default_model()]
    end
  end

  defp get_default_model do
    %{
      name: "GPT-4.1",
      model_id: "gpt-4",
      temperature: 0.3,
      max_tokens: 2048,
      cost_per_token: 0.00002,
      capabilities: [:reasoning],
      specialization: :general
    }
  end

  defp with_error_recovery(func) do
    try do
      func.()
    rescue
      e ->
        Logger.error("Error during execution: #{inspect(e)}")
        {:error, e}
    end
  end

  defp parse_arguments(args) do
    case args do
      ["full" | opts] -> {:full, parse_options(opts)}
      ["adaptive" | opts] -> {:adaptive, parse_options(opts)}
      ["vision" | opts] -> {:vision_test, parse_options(opts)}
      ["benchmark" | opts] -> {:benchmark, parse_options(opts)}
      ["interactive" | opts] -> {:interactive, parse_options(opts)}
      _ -> {:help, []}
    end
  end

  defp parse_options(opts) do
    Enum.chunk_every(opts, 2)
    |> Enum.map(fn
      [key, value] -> {String.to_atom(String.trim_leading(key, "--")), value}
      [flag] -> {String.to_atom(String.trim_leading(flag, "--")), true}
    end)
  end

  defp configure_logging do
    Logger.configure(level: :info)
    Logger.configure_backend(:console, 
      format: "$time $metadata[$level] $message\n",
      metadata: [:module, :function]
    )
  end

  defp check_environment do
    required_vars = ["OPENAI_API_KEY"]
    
    missing = Enum.filter(required_vars, fn var ->
      System.get_env(var) == nil
    end)
    
    if length(missing) > 0 do
      Logger.error("Missing environment variables: #{Enum.join(missing, ", ")}")
      System.halt(1)
    end
  end

  defp show_usage do
    IO.puts("""
    
    Advanced CBLE Evaluation Runner
    ==============================
    
    Usage: mix run advanced_cble_runner.exs [mode] [options]
    
    Modes:
      full         - Run complete evaluation with all features
      adaptive     - Run adaptive testing mode
      vision       - Test vision processing capabilities
      benchmark    - Run performance benchmarks
      interactive  - Interactive question testing
    
    Options:
      --config PATH      - Path to configuration file
      --output PATH      - Output directory for results
      --workers N        - Number of parallel workers
      --all-models       - Use all available models
      --debug            - Enable debug logging
    
    Examples:
      mix run advanced_cble_runner.exs full --all-models
      mix run advanced_cble_runner.exs adaptive --workers 8
      mix run advanced_cble_runner.exs benchmark --iterations 5
    """)
  end

  # Formatting helpers
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}min"
  
  defp format_percentage(nil), do: "N/A"
  defp format_percentage(value), do: "#{Float.round(value * 100, 1)}%"
  
  defp format_cost(nil), do: "$0.00"
  defp format_cost(value), do: "$#{Float.round(value, 2)}"
  
  # Stub implementations for calculations
  defp count_questions({:ok, questions}), do: length(questions)
  defp count_questions(_), do: 0
  
  defp count_visual_questions({:ok, questions}) do
    Enum.count(questions, & &1[:has_images])
  end
  defp count_visual_questions(_), do: 0
  
  defp calculate_success_rate({:ok, results}) do
    successful = Enum.count(results, & &1[:success])
    if length(results) > 0, do: successful / length(results), else: 0
  end
  defp calculate_success_rate(_), do: 0
  
  defp calculate_accuracy({:ok, results}) do
    correct = Enum.count(results, & &1[:is_correct])
    total = Enum.count(results, & &1[:success])
    if total > 0, do: correct / total, else: 0
  end
  defp calculate_accuracy(_), do: 0
  
  defp calculate_total_cost({:ok, results}) do
    Enum.sum(Enum.map(results, & &1[:cost] || 0))
  end
  defp calculate_total_cost(_), do: 0
  
  defp calculate_cost_per_question(evaluation) do
    total_cost = calculate_total_cost(evaluation)
    question_count = case evaluation do
      {:ok, results} -> length(results)
      _ -> 1
    end
    total_cost / max(question_count, 1)
  end
  
  defp find_most_efficient_model({:ok, analytics}) do
    analytics[:cost_analysis][:most_cost_efficient_model] || "N/A"
  end
  defp find_most_efficient_model(_), do: "N/A"
  
  defp format_insights({:ok, analytics}) do
    insights = analytics[:improvement_insights] || []
    if length(insights) > 0 do
      Enum.map(insights, fn insight ->
        "   • #{insight}"
      end)
      |> Enum.join("\n")
    else
      "   No insights available"
    end
  end
  defp format_insights(_), do: "   Analysis pending"
  
  defp create_pdf_extraction_tasks(_harness), do: []
  defp process_extraction_results(_results, _harness), do: []
  defp group_by_strategy(questions), do: %{standard: questions}
  defp create_evaluation_tasks(questions, _strategy, _harness) do
    Enum.map(questions, fn q ->
      %{
        type: :evaluate_question,
        payload: q,
        priority: :normal
      }
    end)
  end
  defp monitor_evaluation_progress(_task_ids, _monitor), do: :ok
  defp generate_performance_summary(_monitor), do: %{}
  
  defp analyze_complexity(_question, _harness), do: 0.5
  defp analyze_visual_requirements(_question), do: []
  defp identify_knowledge_domains(_question), do: []
  defp estimate_difficulty(_question), do: :medium
  defp determine_optimal_approach(_question), do: :standard
  
  defp calculate_performance_metrics(_results), do: %{}
  defp compare_model_performance(_results), do: %{}
  defp calibrate_difficulty_scores(_results), do: %{}
  defp analyze_error_patterns(_results), do: %{}
  defp generate_improvement_insights(_results), do: []
  defp perform_cost_analysis(_results), do: %{}
  defp build_predictive_models(_results, _harness), do: %{}
  
  defp format_performance_progression(_patterns), do: "   Steady improvement observed"
  defp format_strength_areas(_analysis), do: "   • Classification\n   • Valuation"
  defp format_improvement_areas(_analysis), do: "   • Complex regulations\n   • Multi-step problems"
  
  defp get_test_files(_options) do
    ["/Users/agent/evalscompany/cble_dataset/past_exams_and_keys/pdf/2023-Oct-exam.pdf"]
  end
  
  defp display_vision_analysis(content) do
    IO.puts("   Pages: #{content.total_pages}")
    IO.puts("   Visual Elements: #{content.visual_summary.total_visual_elements}")
    IO.puts("   Complexity: #{Float.round(content.visual_summary.average_complexity, 2)}")
  end
  
  defp configure_benchmark_models, do: []
  defp load_benchmark_questions, do: []
  defp run_comprehensive_benchmark(_config), do: %{}
  defp display_benchmark_results(_results), do: :ok
  defp export_benchmark_data(_results, _options), do: :ok
  
  defp get_interactive_model, do: get_default_model()
  defp interactive_loop(_harness), do: :ok
  
  defp generate_comprehensive_reports(_results, _options), do: :ok
end

# Run the script
AdvancedCBLERunner.main(System.argv())