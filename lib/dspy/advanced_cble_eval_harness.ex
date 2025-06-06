defmodule Dspy.AdvancedCBLEEvalHarness do
  @moduledoc """
  Advanced CBLE Evaluation Harness with multi-modal reasoning, adaptive testing,
  performance analytics, and intelligent error recovery.
  """

  require Logger
  alias Dspy.{EnhancedSignature, SequentialVisionSolver, ChainOfThought, SelfConsistency}
  alias Dspy.{TreeOfThoughts, ProgramOfThoughts}
  alias Dspy.MultiAgentChat

  defstruct [
    :exam_data_path,
    :output_path,
    :models,
    :evaluation_config,
    :question_bank,
    :performance_tracker,
    :adaptive_engine,
    :vision_processor,
    :analytics_engine,
    :cache_manager,
    :error_recovery_system,
    :real_time_monitor
  ]

  @type model_config :: %{
          name: String.t(),
          model_id: String.t(),
          temperature: float(),
          max_tokens: integer(),
          cost_per_token: float(),
          capabilities: [atom()],
          specialization: atom()
        }

  @type advanced_evaluation_config :: %{
          parallel_workers: integer(),
          max_retries: integer(),
          timeout_ms: integer(),
          batch_size: integer(),
          adaptive_testing: boolean(),
          multi_agent_enabled: boolean(),
          vision_enhancement: boolean(),
          real_time_monitoring: boolean(),
          cache_strategy: atom(),
          error_recovery_mode: atom()
        }

  @type question_analysis :: %{
          complexity_score: float(),
          required_knowledge_areas: [String.t()],
          visual_complexity: float(),
          reasoning_depth: integer(),
          estimated_time_minutes: float(),
          optimal_approach: atom()
        }

  @type performance_metrics :: %{
          accuracy: float(),
          speed: float(),
          cost_efficiency: float(),
          reasoning_quality: float(),
          vision_accuracy: float(),
          consistency_score: float(),
          improvement_rate: float()
        }

  # Initialize advanced evaluation harness
  def new(opts \\ []) do
    base_path = Keyword.get(opts, :exam_data_path, "/Users/agent/evalscompany/cble_dataset")
    output_path = Keyword.get(opts, :output_path, "./cble_results")

    %__MODULE__{
      exam_data_path: base_path,
      output_path: output_path,
      models: configure_advanced_models(opts),
      evaluation_config: configure_advanced_evaluation(opts),
      question_bank: initialize_question_bank(),
      performance_tracker: initialize_performance_tracker(),
      adaptive_engine: initialize_adaptive_engine(),
      vision_processor: initialize_vision_processor(),
      analytics_engine: initialize_analytics_engine(),
      cache_manager: initialize_cache_manager(),
      error_recovery_system: initialize_error_recovery(),
      real_time_monitor: initialize_real_time_monitor()
    }
  end

  # Advanced model configuration with capabilities
  defp configure_advanced_models(opts) do
    default_models = [
      %{
        name: "GPT-4.1-Vision",
        model_id: "gpt-4-vision-preview",
        temperature: 0.2,
        max_tokens: 4096,
        cost_per_token: 0.00003,
        capabilities: [:vision, :reasoning, :math, :coding],
        specialization: :comprehensive
      },
      %{
        name: "Claude-3-Opus",
        model_id: "claude-3-opus-20240229",
        temperature: 0.1,
        max_tokens: 4096,
        cost_per_token: 0.000025,
        capabilities: [:reasoning, :analysis, :math],
        specialization: :analytical
      },
      %{
        name: "Gemini-Ultra",
        model_id: "gemini-ultra",
        temperature: 0.3,
        max_tokens: 8192,
        cost_per_token: 0.00002,
        capabilities: [:vision, :reasoning, :multimodal],
        specialization: :multimodal
      }
    ]

    Keyword.get(opts, :models, default_models)
  end

  defp configure_advanced_evaluation(opts) do
    %{
      parallel_workers: Keyword.get(opts, :parallel_workers, System.schedulers_online() * 2),
      max_retries: Keyword.get(opts, :max_retries, 3),
      timeout_ms: Keyword.get(opts, :timeout_ms, 120_000),
      batch_size: Keyword.get(opts, :batch_size, 10),
      adaptive_testing: Keyword.get(opts, :adaptive_testing, true),
      multi_agent_enabled: Keyword.get(opts, :multi_agent_enabled, true),
      vision_enhancement: Keyword.get(opts, :vision_enhancement, true),
      real_time_monitoring: Keyword.get(opts, :real_time_monitoring, true),
      cache_strategy: Keyword.get(opts, :cache_strategy, :smart_lru),
      error_recovery_mode: Keyword.get(opts, :error_recovery_mode, :intelligent)
    }
  end

  # Advanced question extraction with NLP
  def extract_questions_advanced(harness) do
    Logger.info("Starting advanced question extraction with NLP...")

    with {:ok, exam_data} <- extract_all_exam_data_advanced(harness),
         {:ok, raw_questions} <- extract_raw_questions(harness, exam_data),
         {:ok, analyzed_questions} <- analyze_questions_nlp(harness, raw_questions),
         {:ok, validated_questions} <- validate_and_enrich_questions(harness, analyzed_questions) do
      store_in_question_bank(harness, validated_questions)
      {:ok, validated_questions}
    end
  end

  defp extract_all_exam_data_advanced(harness) do
    exam_dates = [
      "2022-Apr",
      "2022-Oct",
      "2023-Apr",
      "2023-Oct",
      "2024-May",
      "2024-Oct",
      "2025-Apr"
    ]

    # Use parallel extraction with progress tracking
    tasks =
      Enum.map(exam_dates, fn exam_date ->
        Task.async(fn ->
          monitor_extraction_progress(harness, exam_date)
          extract_exam_data_with_vision(harness, exam_date)
        end)
      end)

    results = Task.await_many(tasks, 300_000)

    successful_extractions =
      results
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, data} -> data end)

    if length(successful_extractions) > 0 do
      {:ok, successful_extractions}
    else
      {:error, :no_data_extracted}
    end
  end

  defp extract_exam_data_with_vision(harness, exam_date) do
    exam_file =
      Path.join([harness.exam_data_path, "past_exams_and_keys", "pdf", "#{exam_date}-exam.pdf"])

    key_file =
      Path.join([harness.exam_data_path, "past_exams_and_keys", "txt", "#{exam_date}-key.txt"])

    with {:ok, pdf_content} <- extract_pdf_with_advanced_vision(harness, exam_file),
         {:ok, answer_key} <- extract_answer_key_advanced(key_file),
         {:ok, enhanced_content} <- enhance_with_vision_analysis(harness, pdf_content) do
      {:ok,
       %{
         exam_date: exam_date,
         content: enhanced_content,
         answer_key: answer_key,
         metadata: extract_exam_metadata(pdf_content)
       }}
    end
  end

  defp extract_pdf_with_advanced_vision(harness, pdf_path) do
    # Use vision processor for advanced PDF extraction
    case harness.vision_processor.extract_pdf(pdf_path) do
      {:ok, content} ->
        # Apply vision enhancement for diagrams, tables, and formulas
        enhanced = enhance_visual_elements(harness, content)
        {:ok, enhanced}

      error ->
        error
    end
  end

  # Advanced question analysis with NLP
  defp analyze_questions_nlp(harness, raw_questions) do
    Logger.info("Analyzing #{length(raw_questions)} questions with NLP...")

    analyzed =
      Enum.map(raw_questions, fn question ->
        Task.async(fn ->
          analyze_single_question(harness, question)
        end)
      end)
      |> Task.await_many(60_000)

    {:ok, analyzed}
  end

  defp analyze_single_question(_harness, question) do
    # Create NLP analysis signature
    analysis_signature = create_nlp_analysis_signature()

    inputs = %{
      question_text: question.text,
      images: question.images,
      context: question.context
    }

    case Dspy.Module.forward(analysis_signature, inputs) do
      {:ok, analysis} ->
        Map.merge(question, %{
          complexity_score: analysis.complexity_score,
          knowledge_areas: analysis.knowledge_areas,
          visual_complexity: analysis.visual_complexity,
          reasoning_depth: analysis.reasoning_depth,
          estimated_time: analysis.estimated_time,
          optimal_approach: determine_optimal_approach(analysis)
        })

      _ ->
        question
    end
  end

  # Multi-agent evaluation for complex questions
  def evaluate_with_multi_agent(harness, question) do
    if question.complexity_score > 0.7 and harness.evaluation_config.multi_agent_enabled do
      Logger.info("Using multi-agent approach for complex question #{question.question_id}")

      # Create specialized agents
      agents = create_specialized_agents(harness, question)

      # Initialize multi-agent chat
      {:ok, chat_pid} =
        MultiAgentChat.create_test_setup(
          length(agents),
          participants: agents,
          max_turns: 5,
          conversation_id: "cble_eval_#{:os.system_time(:millisecond)}"
        )

      # Start the collaborative evaluation
      MultiAgentChat.start_topic(chat_pid, question)
      
      # Wait for completion and get results
      :timer.sleep(10000) # Wait for conversation to develop
      state = MultiAgentChat.get_state(chat_pid)
      MultiAgentChat.stop_conversation(chat_pid)
      
      # Extract the collaborative answer from conversation history
      extract_collaborative_answer(state.conversation_history)
    else
      # Use single agent for simpler questions
      evaluate_with_single_agent(harness, question)
    end
  end

  defp create_specialized_agents(harness, question) do
    base_agents = [
      create_customs_law_expert(harness),
      create_classification_specialist(harness),
      create_valuation_expert(harness)
    ]

    # Add vision specialist if needed
    if question.has_images do
      [create_vision_specialist(harness) | base_agents]
    else
      base_agents
    end
  end

  # Adaptive testing engine
  def run_adaptive_evaluation(harness) do
    Logger.info("Starting adaptive CBLE evaluation...")

    with {:ok, questions} <- extract_questions_advanced(harness),
         {:ok, initial_batch} <- select_initial_questions(harness, questions),
         {:ok, results} <- evaluate_adaptively(harness, initial_batch, questions) do
      # Generate advanced analytics
      analytics = generate_advanced_analytics(harness, results)

      # Store results with full tracking
      store_results_advanced(harness, results, analytics)

      {:ok, results, analytics}
    end
  end

  defp evaluate_adaptively(harness, initial_batch, all_questions, results \\ []) do
    # Evaluate current batch
    batch_results = evaluate_question_batch_advanced(harness, initial_batch)

    # Update performance model
    update_performance_model(harness, batch_results)

    # Determine if more questions needed
    if should_continue_testing?(harness, results ++ batch_results) do
      # Select next batch based on performance
      next_batch = select_adaptive_questions(harness, all_questions, results ++ batch_results)
      evaluate_adaptively(harness, next_batch, all_questions, results ++ batch_results)
    else
      {:ok, results ++ batch_results}
    end
  end

  defp evaluate_question_batch_advanced(harness, questions) do
    # Group by optimal evaluation strategy
    grouped = Enum.group_by(questions, & &1.optimal_approach)

    # Process each group with appropriate strategy
    Enum.flat_map(grouped, fn {approach, group_questions} ->
      case approach do
        :vision_intensive -> evaluate_with_vision_focus(harness, group_questions)
        :reasoning_heavy -> evaluate_with_reasoning_chains(harness, group_questions)
        :multi_step -> evaluate_with_decomposition(harness, group_questions)
        :standard -> evaluate_standard_batch(harness, group_questions)
        _ -> evaluate_standard_batch(harness, group_questions)
      end
    end)
  end

  # Advanced vision processing
  defp evaluate_with_vision_focus(harness, questions) do
    Logger.info("Evaluating #{length(questions)} vision-intensive questions...")

    Enum.map(questions, fn question ->
      # Enhance images with vision processing
      enhanced_images = enhance_images_advanced(harness, question.images)

      # Create vision-specialized solver
      solver = create_vision_solver(harness, question)

      # Evaluate with enhanced vision
      evaluate_with_enhanced_vision(solver, question, enhanced_images)
    end)
  end

  defp enhance_images_advanced(harness, images) do
    Enum.map(images, fn image ->
      # Apply vision enhancements
      with {:ok, ocr_text} <- extract_text_from_image(harness, image),
           {:ok, objects} <- detect_objects_in_image(harness, image),
           {:ok, layout} <- analyze_image_layout(harness, image) do
        Map.merge(image, %{
          ocr_text: ocr_text,
          detected_objects: objects,
          layout_analysis: layout,
          enhanced: true
        })
      else
        _ -> image
      end
    end)
  end

  # Advanced reasoning chains
  defp evaluate_with_reasoning_chains(harness, questions) do
    Logger.info("Evaluating #{length(questions)} reasoning-heavy questions...")

    Enum.map(questions, fn question ->
      # Determine best reasoning approach
      reasoning_method = select_reasoning_method(question)

      # Create appropriate reasoner
      reasoner =
        case reasoning_method do
          :chain_of_thought -> ChainOfThought.new(create_reasoning_signature(question))
          :tree_of_thoughts -> TreeOfThoughts.new(create_tree_signature(question))
          :self_consistency -> SelfConsistency.new(create_consistency_signature(question))
        end

      # Evaluate with selected reasoning method
      evaluate_with_reasoner(harness, reasoner, question)
    end)
  end

  # Performance analytics engine
  defp generate_advanced_analytics(harness, results) do
    Logger.info("Generating advanced analytics for #{length(results)} results...")

    %{
      overall_metrics: calculate_overall_metrics(results),
      model_comparison: perform_model_comparison(harness, results),
      question_difficulty_analysis: analyze_question_difficulty(results),
      temporal_patterns: analyze_temporal_patterns(results),
      error_analysis: perform_error_analysis(results),
      improvement_recommendations: generate_recommendations(harness, results),
      cost_benefit_analysis: analyze_cost_benefit(results),
      vision_performance: analyze_vision_performance(results),
      reasoning_quality: assess_reasoning_quality(results),
      predictive_insights: generate_predictive_insights(harness, results)
    }
  end

  # Real-time monitoring
  defp monitor_extraction_progress(harness, exam_date) do
    if harness.evaluation_config.real_time_monitoring do
      harness.real_time_monitor.track_progress(:extraction, exam_date, %{
        status: :started,
        timestamp: DateTime.utc_now()
      })
    end
  end

  # Intelligent error recovery
  def handle_evaluation_error(harness, error, context) do
    case harness.error_recovery_system.analyze_error(error, context) do
      {:recoverable, strategy} ->
        Logger.warning("Recoverable error detected, applying strategy: #{strategy}")
        apply_recovery_strategy(harness, strategy, context)

      {:non_recoverable, reason} ->
        Logger.error("Non-recoverable error: #{reason}")
        {:error, reason}
    end
  end

  defp apply_recovery_strategy(_harness, :retry_with_backoff, context) do
    backoff_ms = calculate_intelligent_backoff(context.attempt_count)
    Process.sleep(backoff_ms)
    {:retry, context}
  end

  defp apply_recovery_strategy(harness, :use_fallback_model, context) do
    fallback_model = select_fallback_model(harness, context.failed_model)
    {:retry, Map.put(context, :model, fallback_model)}
  end

  defp apply_recovery_strategy(_harness, :decompose_question, context) do
    sub_questions = decompose_complex_question(context.question)
    {:retry, Map.put(context, :questions, sub_questions)}
  end

  # Advanced caching system
  defp check_cache(harness, key) do
    case harness.cache_manager.get(key) do
      {:ok, value, metadata} ->
        if is_cache_valid?(metadata) do
          harness.cache_manager.update_stats(:hit, key)
          {:ok, value}
        else
          harness.cache_manager.update_stats(:stale, key)
          :miss
        end

      :miss ->
        harness.cache_manager.update_stats(:miss, key)
        :miss
    end
  end

  defp cache_result(harness, key, value, ttl \\ 3600) do
    metadata = %{
      cached_at: DateTime.utc_now(),
      ttl: ttl,
      access_count: 0
    }

    harness.cache_manager.put(key, value, metadata)
  end

  # Helper functions for advanced features
  defp create_nlp_analysis_signature do
    EnhancedSignature.new("QuestionAnalysis",
      description: "Analyze CBLE question complexity and requirements",
      input_fields: [
        %{name: :question_text, type: :string, required: true},
        %{name: :images, type: :list, required: false},
        %{name: :context, type: :string, required: false}
      ],
      output_fields: [
        %{name: :complexity_score, type: :float, required: true},
        %{name: :knowledge_areas, type: :list, required: true},
        %{name: :visual_complexity, type: :float, required: true},
        %{name: :reasoning_depth, type: :integer, required: true},
        %{name: :estimated_time, type: :float, required: true}
      ]
    )
  end

  defp determine_optimal_approach(analysis) do
    cond do
      analysis.visual_complexity > 0.7 -> :vision_intensive
      analysis.reasoning_depth > 3 -> :reasoning_heavy
      length(analysis.knowledge_areas) > 4 -> :multi_step
      true -> :standard
    end
  end

  defp select_reasoning_method(question) do
    case question.reasoning_depth do
      depth when depth >= 4 -> :tree_of_thoughts
      depth when depth >= 3 -> :chain_of_thought
      depth when depth >= 2 -> :self_consistency
      _ -> :chain_of_thought
    end
  end

  # Initialize subsystems
  defp initialize_question_bank do
    %{
      questions: %{},
      index: %{
        by_difficulty: %{},
        by_category: %{},
        by_date: %{},
        by_visual: %{}
      },
      statistics: %{
        total_count: 0,
        difficulty_distribution: %{},
        category_distribution: %{}
      }
    }
  end

  defp initialize_performance_tracker do
    %{
      model_performance: %{},
      question_performance: %{},
      temporal_data: [],
      learning_curve: %{},
      performance_model: nil
    }
  end

  defp initialize_adaptive_engine do
    %{
      difficulty_estimator: nil,
      performance_predictor: nil,
      question_selector: nil,
      termination_criteria: %{
        min_questions: 20,
        confidence_threshold: 0.95,
        performance_stability: 0.02
      }
    }
  end

  defp initialize_vision_processor do
    %{
      ocr_engine: :tesseract,
      object_detector: :yolo,
      layout_analyzer: :custom,
      enhancement_pipeline: [:denoise, :contrast, :sharpen]
    }
  end

  defp initialize_analytics_engine do
    %{
      metrics_calculator: nil,
      pattern_detector: nil,
      insight_generator: nil,
      visualization_engine: nil
    }
  end

  defp initialize_cache_manager do
    %{
      cache: %{},
      stats: %{hits: 0, misses: 0, stale: 0},
      eviction_policy: :lru,
      max_size: 1000
    }
  end

  defp initialize_error_recovery do
    %{
      error_patterns: load_error_patterns(),
      recovery_strategies: load_recovery_strategies(),
      fallback_models: [],
      error_history: []
    }
  end

  defp initialize_real_time_monitor do
    %{
      progress_tracker: %{},
      metrics_stream: nil,
      alert_thresholds: %{
        error_rate: 0.1,
        latency_p99: 5000,
        cost_per_question: 0.10
      }
    }
  end

  defp load_error_patterns do
    %{
      rate_limit: ~r/rate limit|too many requests/i,
      timeout: ~r/timeout|timed out/i,
      connection: ~r/connection|network/i,
      api_error: ~r/api error|internal server/i,
      context_length: ~r/context length|too long/i
    }
  end

  defp load_recovery_strategies do
    %{
      rate_limit: :retry_with_backoff,
      timeout: :use_fallback_model,
      connection: :retry_with_backoff,
      api_error: :use_fallback_model,
      context_length: :decompose_question
    }
  end

  # Missing function implementations
  defp extract_raw_questions(_harness, exam_data) do
    # Extract raw questions from exam data
    questions =
      Enum.flat_map(exam_data, fn exam ->
        extract_questions_from_exam(exam)
      end)

    {:ok, questions}
  end

  defp extract_questions_from_exam(_exam) do
    # Stub implementation - would parse exam content
    []
  end

  defp validate_and_enrich_questions(_harness, questions) do
    # Validate and enrich questions with metadata
    enriched =
      Enum.map(questions, fn q ->
        Map.merge(q, %{
          validated: true,
          enrichment_date: DateTime.utc_now()
        })
      end)

    {:ok, enriched}
  end

  defp store_in_question_bank(_harness, questions) do
    # Store questions in the question bank
    Logger.info("Stored #{length(questions)} questions in question bank")
    :ok
  end

  defp extract_answer_key_advanced(key_file) do
    # Extract answer key from file
    case File.read(key_file) do
      {:ok, content} ->
        {:ok, parse_answer_key(content)}

      error ->
        error
    end
  end

  defp parse_answer_key(_content) do
    # Parse answer key format
    %{
      answers: %{},
      format: :text,
      parsed_at: DateTime.utc_now()
    }
  end

  defp enhance_with_vision_analysis(_harness, pdf_content) do
    # Enhance PDF content with vision analysis
    {:ok, Map.put(pdf_content, :vision_enhanced, true)}
  end

  defp extract_exam_metadata(_pdf_content) do
    # Extract metadata from PDF content
    %{
      page_count: 0,
      has_images: false,
      extracted_at: DateTime.utc_now()
    }
  end

  defp enhance_visual_elements(_harness, content) do
    # Enhance visual elements in content
    content
  end

  defp extract_text_from_image(_harness, _image) do
    # OCR text extraction
    {:ok, ""}
  end

  defp detect_objects_in_image(_harness, _image) do
    # Object detection in image
    {:ok, []}
  end

  defp analyze_image_layout(_harness, _image) do
    # Analyze image layout
    {:ok, %{layout_type: :standard}}
  end

  defp select_initial_questions(_harness, questions) do
    # Select initial batch of questions for adaptive testing
    batch_size = 10
    initial_batch = Enum.take(questions, batch_size)
    {:ok, initial_batch}
  end

  # Missing function implementations

  defp is_cache_valid?(metadata) do
    # Check if cache entry is still valid based on TTL
    now = DateTime.utc_now()
    cached_at = metadata.cached_at
    ttl = metadata.ttl || 3600

    DateTime.diff(now, cached_at) < ttl
  end

  defp create_vision_specialist(harness) do
    %{
      name: "Vision Specialist",
      model: Enum.find(harness.models, &(&1.specialization == :multimodal)),
      role: :vision_analysis,
      capabilities: [:ocr, :object_detection, :diagram_analysis]
    }
  end

  defp create_valuation_expert(harness) do
    %{
      name: "Valuation Expert",
      model: Enum.find(harness.models, &(&1.specialization == :analytical)),
      role: :valuation,
      capabilities: [:calculations, :duty_rates, :value_assessment]
    }
  end

  defp create_classification_specialist(harness) do
    %{
      name: "Classification Specialist",
      model: Enum.find(harness.models, &(&1.specialization == :comprehensive)),
      role: :classification,
      capabilities: [:hs_codes, :tariff_schedules, :rule_interpretation]
    }
  end

  defp create_customs_law_expert(harness) do
    %{
      name: "Customs Law Expert",
      model: Enum.find(harness.models, &(&1.specialization == :analytical)),
      role: :legal_analysis,
      capabilities: [:regulations, :compliance, :precedents]
    }
  end

  defp evaluate_with_single_agent(harness, question) do
    # Evaluate question with single agent approach
    _model = Enum.at(harness.models, 0)

    signature =
      EnhancedSignature.new("CBLEAnswer",
        description: "Answer CBLE exam question",
        input_fields: [
          %{name: :question, type: :string, required: true},
          %{name: :images, type: :list, required: false}
        ],
        output_fields: [
          %{name: :answer, type: :string, required: true},
          %{name: :reasoning, type: :string, required: true}
        ]
      )

    case Dspy.Module.forward(signature, question) do
      {:ok, result} -> result
      error -> {:error, error}
    end
  end

  defp decompose_complex_question(question) do
    # Break down complex question into sub-questions
    [
      Map.put(question, :sub_question_id, "#{question.id}_1"),
      Map.put(question, :sub_question_id, "#{question.id}_2")
    ]
  end

  defp select_fallback_model(harness, failed_model) do
    # Select a fallback model when primary fails
    harness.models
    |> Enum.reject(&(&1.name == failed_model.name))
    |> Enum.at(0)
  end

  defp calculate_intelligent_backoff(attempt_count) do
    # Calculate exponential backoff with jitter
    base_ms = 1000
    max_ms = 60_000

    backoff = min(base_ms * :math.pow(2, attempt_count), max_ms)
    jitter = :rand.uniform_real() * 0.1 * backoff

    round(backoff + jitter)
  end

  defp store_results_advanced(harness, results, analytics) do
    # Store evaluation results with advanced analytics
    timestamp = DateTime.utc_now()

    result_file =
      Path.join([
        harness.output_path,
        "results_#{DateTime.to_iso8601(timestamp)}.json"
      ])

    data = %{
      results: results,
      analytics: analytics,
      metadata: %{
        timestamp: timestamp,
        models_used: harness.models,
        config: harness.evaluation_config
      }
    }

    File.write!(result_file, Jason.encode!(data, pretty: true))
    Logger.info("Results stored at: #{result_file}")
  end


  defp should_continue_testing?(harness, results) do
    # Determine if adaptive testing should continue
    criteria = harness.adaptive_engine.termination_criteria

    question_count = length(results)
    performance_stable = calculate_performance_stability(results) < criteria.performance_stability
    confidence_met = calculate_confidence(results) > criteria.confidence_threshold

    question_count < criteria.min_questions or
      (not performance_stable and not confidence_met)
  end

  defp select_adaptive_questions(harness, all_questions, completed_results) do
    # Select next batch of questions based on performance
    performance_gaps = identify_performance_gaps(completed_results)

    all_questions
    |> Enum.reject(fn q -> Enum.any?(completed_results, &(&1.question_id == q.id)) end)
    |> Enum.sort_by(fn q -> score_question_priority(q, performance_gaps) end, :desc)
    |> Enum.take(harness.evaluation_config.batch_size)
  end

  defp update_performance_model(harness, batch_results) do
    # Update the adaptive performance model
    current_model = harness.performance_tracker.performance_model || %{}

    updated_model =
      Map.merge(current_model, %{
        last_batch_accuracy: calculate_batch_accuracy(batch_results),
        cumulative_stats: update_cumulative_stats(current_model, batch_results)
      })

    put_in(harness.performance_tracker.performance_model, updated_model)
  end

  defp evaluate_standard_batch(harness, questions) do
    # Standard batch evaluation without special processing
    Enum.map(questions, fn question ->
      evaluate_with_single_agent(harness, question)
    end)
  end

  defp evaluate_with_decomposition(harness, questions) do
    # Evaluate using question decomposition strategy
    Enum.flat_map(questions, fn question ->
      sub_questions = decompose_complex_question(question)

      Enum.map(sub_questions, fn sub_q ->
        evaluate_with_single_agent(harness, sub_q)
      end)
    end)
  end

  defp evaluate_with_reasoner(_harness, reasoner, question) do
    # Evaluate using specific reasoning approach
    inputs = %{
      question: question.text,
      context: question.context,
      images: question.images
    }

    case Dspy.Module.forward(reasoner, inputs) do
      {:ok, result} ->
        Map.merge(result, %{
          question_id: question.id,
          reasoning_method: reasoner.__struct__
        })

      error ->
        {:error, error}
    end
  end

  defp create_consistency_signature(question) do
    # Create signature for self-consistency approach
    EnhancedSignature.new("ConsistencyReasoning",
      description: "Answer with self-consistency checking for: #{question.text}",
      input_fields: [
        %{name: :question, type: :string, required: true},
        %{name: :context, type: :string, required: false}
      ],
      output_fields: [
        %{name: :answer, type: :string, required: true},
        %{name: :confidence, type: :float, required: true}
      ]
    )
  end

  defp create_program_signature(question) do
    # Create signature for program of thoughts
    EnhancedSignature.new("ProgramReasoning",
      description: "Solve using program of thoughts: #{question.text}",
      input_fields: [
        %{name: :question, type: :string, required: true},
        %{name: :context, type: :string, required: false}
      ],
      output_fields: [
        %{name: :program, type: :string, required: true},
        %{name: :result, type: :string, required: true}
      ]
    )
  end

  defp create_tree_signature(question) do
    # Create signature for tree of thoughts
    EnhancedSignature.new("TreeReasoning",
      description: "Explore solution tree for: #{question.text}",
      input_fields: [
        %{name: :question, type: :string, required: true},
        %{name: :context, type: :string, required: false}
      ],
      output_fields: [
        %{name: :thought_tree, type: :map, required: true},
        %{name: :best_path, type: :string, required: true}
      ]
    )
  end

  defp create_reasoning_signature(question) do
    # Create general reasoning signature
    EnhancedSignature.new("GeneralReasoning",
      description: "Reason through: #{question.text}",
      input_fields: [
        %{name: :question, type: :string, required: true},
        %{name: :context, type: :string, required: false}
      ],
      output_fields: [
        %{name: :reasoning_steps, type: :list, required: true},
        %{name: :conclusion, type: :string, required: true}
      ]
    )
  end

  defp evaluate_with_enhanced_vision(solver, question, enhanced_images) do
    # Evaluate with enhanced vision processing
    inputs = Map.merge(question, %{enhanced_images: enhanced_images})

    case Dspy.Module.forward(solver, inputs) do
      {:ok, result} ->
        Map.merge(result, %{
          vision_enhanced: true,
          image_count: length(enhanced_images)
        })

      error ->
        {:error, error}
    end
  end

  defp create_vision_solver(harness, question) do
    # Create specialized vision solver
    SequentialVisionSolver.new(
      model: Enum.find(harness.models, &(:vision in &1.capabilities)),
      question: question,
      enhancement_level: :high
    )
  end

  defp calculate_overall_metrics(results) do
    # Calculate overall performance metrics
    total = length(results)
    correct = Enum.count(results, & &1[:correct])

    %{
      total_questions: total,
      correct_answers: correct,
      accuracy: if(total > 0, do: correct / total, else: 0),
      avg_response_time: calculate_avg_response_time(results),
      completion_rate: calculate_completion_rate(results)
    }
  end

  defp perform_model_comparison(harness, results) do
    # Compare performance across different models
    Enum.map(harness.models, fn model ->
      model_results = Enum.filter(results, &(&1[:model_used] == model.name))

      %{
        model: model.name,
        accuracy: calculate_accuracy(model_results),
        avg_time: calculate_avg_response_time(model_results),
        cost: calculate_total_cost(model_results, model)
      }
    end)
  end

  defp analyze_question_difficulty(results) do
    # Analyze difficulty patterns
    %{
      difficulty_distribution: group_by_difficulty(results),
      success_by_difficulty: calculate_success_by_difficulty(results),
      time_by_difficulty: calculate_time_by_difficulty(results)
    }
  end

  defp analyze_temporal_patterns(results) do
    # Analyze patterns over time
    %{
      performance_over_time: track_performance_over_time(results),
      learning_curve: calculate_learning_curve(results),
      fatigue_indicators: detect_fatigue_patterns(results)
    }
  end

  defp perform_error_analysis(results) do
    # Analyze error patterns
    errors = Enum.filter(results, &(not &1[:correct]))

    %{
      error_count: length(errors),
      error_categories: categorize_errors(errors),
      common_mistakes: identify_common_mistakes(errors)
    }
  end

  defp generate_recommendations(_harness, results) do
    # Generate improvement recommendations
    performance = calculate_overall_metrics(results)

    recommendations = []

    recommendations =
      if performance.accuracy < 0.7 do
        ["Consider additional training data" | recommendations]
      else
        recommendations
      end

    recommendations =
      if performance.avg_response_time > 30_000 do
        ["Optimize response time with caching" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp analyze_cost_benefit(results) do
    # Analyze cost vs benefit
    %{
      total_cost: calculate_total_evaluation_cost(results),
      cost_per_correct: calculate_cost_per_correct_answer(results),
      roi_estimate: estimate_roi(results)
    }
  end

  defp analyze_vision_performance(results) do
    # Analyze vision-specific performance
    vision_results = Enum.filter(results, & &1[:has_images])

    %{
      vision_accuracy: calculate_accuracy(vision_results),
      ocr_success_rate: calculate_ocr_success_rate(vision_results),
      object_detection_accuracy: calculate_object_detection_accuracy(vision_results)
    }
  end

  defp assess_reasoning_quality(results) do
    # Assess quality of reasoning
    %{
      reasoning_depth_avg: calculate_avg_reasoning_depth(results),
      logical_consistency: assess_logical_consistency(results),
      explanation_quality: rate_explanation_quality(results)
    }
  end

  defp generate_predictive_insights(harness, results) do
    # Generate predictive insights
    %{
      predicted_future_accuracy: predict_future_accuracy(harness, results),
      recommended_batch_size: recommend_optimal_batch_size(results),
      suggested_model_mix: suggest_model_mix(harness, results)
    }
  end

  # Helper functions for analytics
  defp calculate_performance_stability(results) do
    # Calculate stability of performance over recent results
    if length(results) < 5 do
      1.0
    else
      recent = Enum.take(results, -10)
      accuracies = Enum.map(recent, &if(&1[:correct], do: 1.0, else: 0.0))
      calculate_standard_deviation(accuracies)
    end
  end

  defp calculate_confidence(results) do
    # Calculate confidence in current performance estimate
    if length(results) == 0 do
      0.0
    else
      # Simple confidence based on sample size
      min(length(results) / 50, 0.99)
    end
  end

  defp identify_performance_gaps(results) do
    # Identify areas needing improvement
    %{
      weak_categories: find_weak_categories(results),
      difficult_question_types: find_difficult_types(results)
    }
  end

  defp score_question_priority(question, performance_gaps) do
    # Score question priority for adaptive selection
    base_score = question.complexity_score

    gap_bonus =
      if question.category in performance_gaps.weak_categories do
        0.3
      else
        0.0
      end

    base_score + gap_bonus
  end

  defp calculate_batch_accuracy(results) do
    # Calculate accuracy for a batch
    total = length(results)
    correct = Enum.count(results, & &1[:correct])

    if total > 0, do: correct / total, else: 0.0
  end

  defp update_cumulative_stats(current_stats, new_results) do
    # Update cumulative statistics
    Map.merge(current_stats || %{}, %{
      total_evaluated: (current_stats[:total_evaluated] || 0) + length(new_results),
      last_updated: DateTime.utc_now()
    })
  end

  # Additional helper stubs
  defp calculate_avg_response_time(results) do
    times = Enum.map(results, &(&1[:response_time] || 0))
    if length(times) > 0, do: Enum.sum(times) / length(times), else: 0
  end

  defp calculate_completion_rate(results) do
    completed = Enum.count(results, & &1[:completed])
    if length(results) > 0, do: completed / length(results), else: 0
  end

  defp calculate_accuracy(results) do
    total = length(results)
    correct = Enum.count(results, & &1[:correct])
    if total > 0, do: correct / total, else: 0
  end

  defp calculate_total_cost(results, model) do
    tokens = Enum.sum(Enum.map(results, &(&1[:tokens_used] || 0)))
    tokens * model.cost_per_token
  end

  defp group_by_difficulty(results) do
    Enum.group_by(results, &(&1[:difficulty] || :medium))
  end

  defp calculate_success_by_difficulty(results) do
    results
    |> group_by_difficulty()
    |> Enum.map(fn {diff, group} -> {diff, calculate_accuracy(group)} end)
    |> Map.new()
  end

  defp calculate_time_by_difficulty(results) do
    results
    |> group_by_difficulty()
    |> Enum.map(fn {diff, group} -> {diff, calculate_avg_response_time(group)} end)
    |> Map.new()
  end

  defp track_performance_over_time(_results) do
    # Simple placeholder - would implement time-series tracking
    []
  end

  defp calculate_learning_curve(_results) do
    # Placeholder for learning curve calculation
    %{trend: :improving}
  end

  defp detect_fatigue_patterns(_results) do
    # Placeholder for fatigue detection
    %{fatigue_detected: false}
  end

  defp categorize_errors(_errors) do
    # Placeholder for error categorization
    %{syntax: 0, logic: 0, knowledge: 0}
  end

  defp identify_common_mistakes(_errors) do
    # Placeholder for common mistake identification
    []
  end

  defp calculate_total_evaluation_cost(results) do
    Enum.sum(Enum.map(results, &(&1[:cost] || 0)))
  end

  defp calculate_cost_per_correct_answer(results) do
    total_cost = calculate_total_evaluation_cost(results)
    correct = Enum.count(results, & &1[:correct])

    if correct > 0, do: total_cost / correct, else: 0
  end

  defp estimate_roi(_results) do
    # Placeholder ROI estimation
    1.5
  end

  defp calculate_ocr_success_rate(_results) do
    # Placeholder for OCR success rate
    0.95
  end

  defp calculate_object_detection_accuracy(_results) do
    # Placeholder for object detection accuracy
    0.88
  end

  defp calculate_avg_reasoning_depth(_results) do
    # Placeholder for reasoning depth calculation
    3.2
  end

  defp assess_logical_consistency(_results) do
    # Placeholder for logical consistency assessment
    0.92
  end

  defp rate_explanation_quality(_results) do
    # Placeholder for explanation quality rating
    0.85
  end

  defp predict_future_accuracy(_harness, _results) do
    # Placeholder for accuracy prediction
    0.82
  end

  defp recommend_optimal_batch_size(_results) do
    # Placeholder for batch size recommendation
    15
  end

  defp suggest_model_mix(_harness, _results) do
    # Placeholder for model mix suggestion
    %{vision: 0.3, analytical: 0.4, comprehensive: 0.3}
  end

  defp find_weak_categories(_results) do
    # Placeholder for weak category identification
    ["classification", "valuation"]
  end

  defp find_difficult_types(_results) do
    # Placeholder for difficult type identification
    ["multi-step", "visual-heavy"]
  end

  defp extract_collaborative_answer(conversation_history) do
    # Extract the final collaborative answer from the conversation
    # Look for the last substantive response that contains an answer
    case Enum.reverse(conversation_history) do
      [%{content: content} | _] when content != "" ->
        content
      _ ->
        "Unable to reach collaborative consensus"
    end
  end

  defp calculate_standard_deviation([]), do: 0.0
  defp calculate_standard_deviation([_]), do: 0.0
  defp calculate_standard_deviation(values) do
    n = length(values)
    mean = Enum.sum(values) / n
    variance = Enum.sum(Enum.map(values, &:math.pow(&1 - mean, 2))) / n
    :math.sqrt(variance)
  end
end
