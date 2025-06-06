defmodule Dspy.SequentialVisionSolver do
  @moduledoc """
  Advanced sequential problem solver with vision abstraction and comprehensive evaluation.

  Integrates capabilities from evalscompany evaluation framework:
  - Multi-step reasoning with vision support
  - Advanced evaluation metrics (reasoning coherence, step-by-step assessment)
  - Multi-signal reward system for training
  - No truncation with intelligent content management
  - Customs broker evaluation (CBLE) patterns
  """

  use Dspy.Module

  defstruct [
    :signature,
    :examples,
    :max_retries,
    :vision_enabled,
    :evaluation_config,
    :sequential_steps,
    :reward_system,
    :content_chunking,
    :performance_metrics
  ]

  @type evaluation_config :: %{
          enable_step_scoring: boolean(),
          enable_reasoning_analysis: boolean(),
          enable_vision_assessment: boolean(),
          enable_efficiency_tracking: boolean(),
          enable_multi_signal_rewards: boolean()
        }

  @type performance_metrics :: %{
          reasoning_coherence: float(),
          conceptual_understanding: float(),
          solution_optimality: float(),
          symbolic_manipulation: float(),
          error_sensitivity: float(),
          domain_transfer: float(),
          reasoning_depth: float(),
          creativity: float(),
          vision_integration: float(),
          step_efficiency: float()
        }

  @type step_result :: %{
          step_id: integer(),
          inputs: map(),
          outputs: map(),
          vision_content: [map()],
          reasoning_trace: [String.t()],
          evaluation_scores: performance_metrics(),
          execution_time: float(),
          success: boolean(),
          error_details: map() | nil
        }

  @type solver_result :: %{
          final_outputs: map(),
          step_results: [step_result()],
          overall_metrics: performance_metrics(),
          vision_analysis: map(),
          efficiency_report: map(),
          recommendation: String.t()
        }

  @type t :: %__MODULE__{
          signature: Dspy.EnhancedSignature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          vision_enabled: boolean(),
          evaluation_config: evaluation_config(),
          sequential_steps: [map()],
          reward_system: map(),
          content_chunking: boolean(),
          performance_metrics: performance_metrics()
        }

  @doc """
  Create a new sequential vision solver.
  """
  def new(signature, opts \\ []) do
    %__MODULE__{
      signature: get_enhanced_signature(signature, opts),
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      vision_enabled: Keyword.get(opts, :vision_enabled, true),
      evaluation_config: Keyword.get(opts, :evaluation_config, default_evaluation_config()),
      sequential_steps: Keyword.get(opts, :sequential_steps, []),
      reward_system: Keyword.get(opts, :reward_system, default_reward_system()),
      content_chunking: Keyword.get(opts, :content_chunking, true),
      performance_metrics: default_performance_metrics()
    }
  end

  @impl true
  def forward(solver, inputs) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, preprocessed_inputs} <- preprocess_inputs(solver, inputs),
         {:ok, execution_plan} <- create_execution_plan(solver, preprocessed_inputs),
         {:ok, step_results} <- execute_sequential_steps(solver, execution_plan),
         {:ok, final_outputs} <- consolidate_results(solver, step_results),
         {:ok, evaluation_results} <- evaluate_performance(solver, step_results, final_outputs) do
      end_time = System.monotonic_time(:millisecond)
      total_time = end_time - start_time

      result = %{
        final_outputs: final_outputs,
        step_results: step_results,
        overall_metrics: evaluation_results.metrics,
        vision_analysis: evaluation_results.vision_analysis,
        efficiency_report: %{
          total_execution_time: total_time,
          average_step_time: total_time / max(length(step_results), 1),
          vision_processing_time: evaluation_results.vision_processing_time,
          reasoning_complexity: evaluation_results.reasoning_complexity
        },
        recommendation: generate_recommendation(evaluation_results)
      }

      prediction = Dspy.Prediction.new(result)
      {:ok, prediction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Process a single vision-enabled problem with step-by-step evaluation.
  """
  def solve_vision_problem(solver, problem_inputs) do
    vision_content = extract_vision_content(problem_inputs)
    _text_content = extract_text_content(problem_inputs)

    # Generate vision-aware prompt
    prompt_result =
      Dspy.EnhancedSignature.to_vision_prompt(
        solver.signature,
        problem_inputs,
        solver.examples
      )

    # Process with vision support
    case generate_vision_response(solver, prompt_result) do
      {:ok, response} ->
        # Evaluate vision integration
        vision_scores = evaluate_vision_integration(response, vision_content)

        # Parse outputs with vision context
        outputs =
          Dspy.EnhancedSignature.parse_enhanced_outputs(
            solver.signature,
            response.text,
            %{vision_content: vision_content}
          )

        {:ok,
         %{
           outputs: outputs,
           vision_analysis: vision_scores,
           response_metadata: response.metadata
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Evaluate problem-solving performance using evalscompany metrics.
  """
  def evaluate_reasoning_quality(_solver, response_text, expected_outputs \\ nil) do
    reasoning_steps = extract_reasoning_steps(response_text)
    mathematical_expressions = extract_mathematical_expressions(response_text)

    metrics = %{
      reasoning_coherence: evaluate_reasoning_coherence(reasoning_steps),
      conceptual_understanding: evaluate_conceptual_understanding(response_text),
      solution_optimality: evaluate_solution_optimality(response_text, expected_outputs),
      symbolic_manipulation: evaluate_symbolic_manipulation(mathematical_expressions),
      error_sensitivity: evaluate_error_sensitivity(response_text),
      reasoning_depth: evaluate_reasoning_depth(reasoning_steps),
      creativity: evaluate_creativity(response_text)
    }

    %{
      metrics: metrics,
      detailed_analysis: %{
        reasoning_steps: reasoning_steps,
        mathematical_expressions: mathematical_expressions,
        step_count: length(reasoning_steps),
        complexity_score: calculate_complexity_score(response_text)
      }
    }
  end

  # Private helper functions

  defp get_enhanced_signature(signature, opts) when is_atom(signature) do
    base_sig = signature.signature()

    # Enhance with vision and sequential capabilities
    Dspy.EnhancedSignature.new(base_sig.name,
      description: base_sig.description,
      input_fields: enhance_fields_for_vision(base_sig.input_fields),
      output_fields: enhance_fields_for_vision(base_sig.output_fields),
      instructions: base_sig.instructions,
      vision_enabled: Keyword.get(opts, :vision_enabled, true),
      sequential_steps: Keyword.get(opts, :sequential_steps, []),
      evaluation_criteria: Keyword.get(opts, :evaluation_criteria, %{})
    )
  end

  defp get_enhanced_signature(signature, opts) do
    # Already an enhanced signature or regular signature
    if Map.has_key?(signature, :vision_enabled) do
      signature
    else
      Dspy.EnhancedSignature.new(signature.name,
        description: signature.description,
        input_fields: enhance_fields_for_vision(signature.input_fields),
        output_fields: enhance_fields_for_vision(signature.output_fields),
        instructions: signature.instructions,
        vision_enabled: Keyword.get(opts, :vision_enabled, true)
      )
    end
  end

  defp enhance_fields_for_vision(fields) do
    Enum.map(fields, fn field ->
      %{
        name: field[:name] || field.name,
        type: field[:type] || field.type || :string,
        description: field[:description] || field.description || "",
        required: field[:required] || field.required || false,
        default: field[:default] || field.default,
        vision_enabled: should_enable_vision_for_field(field),
        evaluation_weight: 1.0,
        display_priority: 0,
        max_length: 10_000
      }
    end)
  end

  defp should_enable_vision_for_field(field) do
    field_name = to_string(field[:name] || field.name)
    description = to_string(field[:description] || field.description || "")

    vision_keywords = ["image", "picture", "diagram", "chart", "graph", "visual", "photo"]

    Enum.any?(vision_keywords, fn keyword ->
      String.contains?(String.downcase(field_name), keyword) or
        String.contains?(String.downcase(description), keyword)
    end)
  end

  defp default_evaluation_config do
    %{
      enable_step_scoring: true,
      enable_reasoning_analysis: true,
      enable_vision_assessment: true,
      enable_efficiency_tracking: true,
      enable_multi_signal_rewards: true
    }
  end

  defp default_reward_system do
    %{
      cost_weight: 0.2,
      time_weight: 0.15,
      correctness_weight: 0.4,
      conciseness_weight: 0.1,
      learning_weight: 0.15
    }
  end

  defp default_performance_metrics do
    %{
      reasoning_coherence: 0.0,
      conceptual_understanding: 0.0,
      solution_optimality: 0.0,
      symbolic_manipulation: 0.0,
      error_sensitivity: 0.0,
      domain_transfer: 0.0,
      reasoning_depth: 0.0,
      creativity: 0.0,
      vision_integration: 0.0,
      step_efficiency: 0.0
    }
  end

  defp preprocess_inputs(solver, inputs) do
    # Validate inputs using enhanced signature
    case Dspy.EnhancedSignature.validate_enhanced_inputs(solver.signature, inputs) do
      :ok ->
        # Process vision content if enabled
        if solver.vision_enabled do
          processed_inputs = process_vision_inputs(inputs)
          {:ok, processed_inputs}
        else
          {:ok, inputs}
        end

      error ->
        error
    end
  end

  defp process_vision_inputs(inputs) do
    Enum.map(inputs, fn {key, value} ->
      if is_vision_content?(value) do
        {key, process_vision_content(value)}
      else
        {key, value}
      end
    end)
    |> Enum.into(%{})
  end

  defp process_vision_content(content) when is_binary(content) do
    cond do
      String.starts_with?(content, "data:image") ->
        %{type: :base64_image, content: content, processed: true}

      String.contains?(content, ["http", "https"]) ->
        %{type: :image_url, content: content, processed: true}

      String.contains?(content, [".jpg", ".png", ".gif", ".webp"]) ->
        %{type: :image_path, content: content, processed: true}

      true ->
        %{type: :binary_image, content: content, processed: true}
    end
  end

  defp is_vision_content?(value) when is_binary(value) do
    # JPEG
    # PNG
    String.contains?(value, ["data:image", "http", ".jpg", ".png", ".gif", ".webp"]) or
      ((byte_size(value) > 100 and String.starts_with?(value, <<0xFF, 0xD8>>)) or
         String.starts_with?(value, <<0x89, 0x50, 0x4E, 0x47>>))
  end

  defp is_vision_content?(_), do: false

  defp create_execution_plan(solver, inputs) do
    if length(solver.sequential_steps) > 0 do
      # Use predefined sequential steps
      plan = %{
        strategy: :predefined_steps,
        steps: solver.sequential_steps,
        total_steps: length(solver.sequential_steps),
        inputs: inputs
      }

      {:ok, plan}
    else
      # Create dynamic execution plan based on problem complexity
      plan = create_dynamic_execution_plan(solver, inputs)
      {:ok, plan}
    end
  end

  defp create_dynamic_execution_plan(_solver, inputs) do
    # Analyze problem complexity and create appropriate steps
    complexity = estimate_problem_complexity(inputs)

    steps =
      case complexity do
        :simple ->
          [%{step_id: 1, name: "Direct Solution", type: :direct}]

        :moderate ->
          [
            %{step_id: 1, name: "Problem Analysis", type: :analysis},
            %{step_id: 2, name: "Solution Generation", type: :solution}
          ]

        :complex ->
          [
            %{step_id: 1, name: "Problem Decomposition", type: :decomposition},
            %{step_id: 2, name: "Sub-problem Analysis", type: :analysis},
            %{step_id: 3, name: "Solution Synthesis", type: :synthesis},
            %{step_id: 4, name: "Validation", type: :validation}
          ]
      end

    %{
      strategy: :dynamic,
      steps: steps,
      total_steps: length(steps),
      complexity: complexity,
      inputs: inputs
    }
  end

  defp estimate_problem_complexity(inputs) do
    # Simple heuristic for complexity estimation
    text_length =
      inputs |> Map.values() |> Enum.map(&to_string/1) |> Enum.join("") |> String.length()

    vision_count = inputs |> Map.values() |> Enum.count(&is_vision_content?/1)

    cond do
      text_length > 2000 or vision_count > 2 -> :complex
      text_length > 500 or vision_count > 0 -> :moderate
      true -> :simple
    end
  end

  defp execute_sequential_steps(solver, execution_plan) do
    initial_context = %{
      previous_results: [],
      accumulated_outputs: %{},
      vision_context: extract_vision_content(execution_plan.inputs)
    }

    results =
      Enum.reduce_while(execution_plan.steps, initial_context, fn step, context ->
        case execute_single_step(solver, step, context, execution_plan) do
          {:ok, step_result} ->
            new_context = %{
              previous_results: [step_result | context.previous_results],
              accumulated_outputs: Map.merge(context.accumulated_outputs, step_result.outputs),
              vision_context: context.vision_context
            }

            {:cont, new_context}

          {:error, reason} ->
            {:halt, {:error, step.step_id, reason}}
        end
      end)

    case results do
      {:error, step_id, reason} -> {:error, {:step_failed, step_id, reason}}
      context -> {:ok, Enum.reverse(context.previous_results)}
    end
  end

  defp execute_single_step(solver, step, context, execution_plan) do
    start_time = System.monotonic_time(:millisecond)

    # Prepare step-specific inputs
    step_inputs = prepare_step_inputs(step, context, execution_plan.inputs)

    # Generate step-specific prompt
    prompt = generate_step_prompt(solver, step, step_inputs, context)

    # Execute step with retries
    case execute_step_with_retries(solver, prompt, step, solver.max_retries) do
      {:ok, response} ->
        end_time = System.monotonic_time(:millisecond)
        execution_time = end_time - start_time

        # Parse outputs
        outputs = parse_step_outputs(solver, response, step)

        # Extract reasoning trace
        reasoning_trace = extract_reasoning_steps(response)

        # Evaluate step performance
        evaluation_scores =
          if solver.evaluation_config.enable_step_scoring do
            evaluate_step_performance(solver, step, response, outputs)
          else
            default_performance_metrics()
          end

        step_result = %{
          step_id: step.step_id,
          inputs: step_inputs,
          outputs: outputs,
          vision_content: context.vision_context,
          reasoning_trace: reasoning_trace,
          evaluation_scores: evaluation_scores,
          execution_time: execution_time,
          success: true,
          error_details: nil
        }

        {:ok, step_result}

      {:error, reason} ->
        step_result = %{
          step_id: step.step_id,
          inputs: step_inputs,
          outputs: %{},
          vision_content: context.vision_context,
          reasoning_trace: [],
          evaluation_scores: default_performance_metrics(),
          execution_time: 0,
          success: false,
          error_details: %{reason: reason, step: step}
        }

        {:error, step_result}
    end
  end

  defp prepare_step_inputs(step, context, original_inputs) do
    # Combine original inputs with results from previous steps
    base_inputs = original_inputs

    # Add relevant previous results
    previous_outputs = context.accumulated_outputs

    # Add step-specific context
    step_context = %{
      step_id: step.step_id,
      step_name: step.name,
      previous_results: context.previous_results
    }

    Map.merge(base_inputs, Map.merge(previous_outputs, step_context))
  end

  defp generate_step_prompt(solver, step, inputs, context) do
    step_context = %{
      current_step: step.step_id,
      previous_results: context.previous_results
    }

    if solver.vision_enabled and length(context.vision_context) > 0 do
      Dspy.EnhancedSignature.to_vision_prompt(solver.signature, inputs, solver.examples)
    else
      Dspy.EnhancedSignature.to_sequential_prompt(solver.signature, inputs, step_context)
    end
  end

  defp execute_step_with_retries(solver, prompt, step, retries) do
    prompt_text =
      if is_map(prompt) do
        prompt.text_prompt || prompt.prompt
      else
        prompt
      end

    case Dspy.LM.generate_text(prompt_text) do
      {:ok, response} ->
        {:ok, response}

      {:error, _reason} when retries > 0 ->
        Process.sleep(1000)
        execute_step_with_retries(solver, prompt, step, retries - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Parse the raw language-model response into the structured output that the
  # current `solver.signature` expects. We need access to the `solver` struct
  # for its signature, so keep the argument name as `solver` rather than the
  # underscore-prefixed variant that suppresses the "unused variable" warning.
  #
  # NOTE: This function was previously defined with the argument name
  # `_solver` but still referenced the variable `solver` inside the function
  # body, which resulted in an **undefined variable `solver`** compilation
  # error.  Renaming the parameter to `solver` fixes the bug while preserving
  # the original behaviour.
  defp parse_step_outputs(solver, response, _step) do
    Dspy.EnhancedSignature.parse_enhanced_outputs(solver.signature, response)
  end

  defp consolidate_results(solver, step_results) do
    # Combine outputs from all successful steps
    final_outputs =
      step_results
      |> Enum.filter(& &1.success)
      |> Enum.reduce(%{}, fn step_result, acc ->
        Map.merge(acc, step_result.outputs)
      end)

    {:ok, final_outputs}
  end

  defp evaluate_performance(solver, step_results, final_outputs) do
    start_time = System.monotonic_time(:millisecond)

    # Overall metrics
    overall_metrics = calculate_overall_metrics(step_results)

    # Vision analysis if applicable
    vision_analysis =
      if solver.vision_enabled do
        analyze_vision_integration(step_results)
      else
        %{}
      end

    # Reasoning complexity analysis
    reasoning_complexity = analyze_reasoning_complexity(step_results)

    end_time = System.monotonic_time(:millisecond)
    vision_processing_time = end_time - start_time

    evaluation_results = %{
      metrics: overall_metrics,
      vision_analysis: vision_analysis,
      reasoning_complexity: reasoning_complexity,
      vision_processing_time: vision_processing_time
    }

    {:ok, evaluation_results}
  end

  defp calculate_overall_metrics(step_results) do
    successful_steps = Enum.filter(step_results, & &1.success)

    if length(successful_steps) > 0 do
      %{
        reasoning_coherence: average_metric(successful_steps, :reasoning_coherence),
        conceptual_understanding: average_metric(successful_steps, :conceptual_understanding),
        solution_optimality: average_metric(successful_steps, :solution_optimality),
        symbolic_manipulation: average_metric(successful_steps, :symbolic_manipulation),
        error_sensitivity: average_metric(successful_steps, :error_sensitivity),
        domain_transfer: average_metric(successful_steps, :domain_transfer),
        reasoning_depth: average_metric(successful_steps, :reasoning_depth),
        creativity: average_metric(successful_steps, :creativity),
        vision_integration: average_metric(successful_steps, :vision_integration),
        step_efficiency: calculate_step_efficiency(step_results)
      }
    else
      default_performance_metrics()
    end
  end

  defp average_metric(step_results, metric_name) do
    values =
      Enum.map(step_results, fn step ->
        Map.get(step.evaluation_scores, metric_name, 0.0)
      end)

    if length(values) > 0 do
      Enum.sum(values) / length(values)
    else
      0.0
    end
  end

  defp calculate_step_efficiency(step_results) do
    total_time = Enum.sum(Enum.map(step_results, & &1.execution_time))
    successful_steps = Enum.count(step_results, & &1.success)
    total_steps = length(step_results)

    efficiency_ratio = if total_steps > 0, do: successful_steps / total_steps, else: 0.0
    time_efficiency = if total_time > 0, do: 1.0 / :math.log(total_time + 1), else: 1.0

    (efficiency_ratio + time_efficiency) / 2
  end

  defp analyze_vision_integration(step_results) do
    vision_steps =
      Enum.filter(step_results, fn step ->
        length(step.vision_content) > 0
      end)

    if length(vision_steps) > 0 do
      %{
        vision_steps_count: length(vision_steps),
        average_vision_score: average_metric(vision_steps, :vision_integration),
        vision_content_types: extract_vision_types(vision_steps),
        vision_reasoning_quality: analyze_vision_reasoning(vision_steps)
      }
    else
      %{vision_enabled: false}
    end
  end

  defp extract_vision_types(vision_steps) do
    vision_steps
    |> Enum.flat_map(& &1.vision_content)
    |> Enum.map(& &1[:type])
    |> Enum.uniq()
  end

  defp analyze_vision_reasoning(vision_steps) do
    reasoning_mentions =
      vision_steps
      |> Enum.flat_map(& &1.reasoning_trace)
      |> Enum.count(fn trace ->
        String.contains?(String.downcase(trace), ["image", "picture", "visual", "see", "shown"])
      end)

    total_reasoning_steps =
      vision_steps
      |> Enum.flat_map(& &1.reasoning_trace)
      |> length()

    if total_reasoning_steps > 0 do
      reasoning_mentions / total_reasoning_steps
    else
      0.0
    end
  end

  defp analyze_reasoning_complexity(step_results) do
    all_reasoning =
      step_results
      |> Enum.flat_map(& &1.reasoning_trace)

    %{
      total_reasoning_steps: length(all_reasoning),
      average_step_length: average_string_length(all_reasoning),
      complexity_indicators: count_complexity_indicators(all_reasoning),
      mathematical_content: count_mathematical_expressions(all_reasoning)
    }
  end

  defp average_string_length(strings) do
    if length(strings) > 0 do
      total_length = Enum.sum(Enum.map(strings, &String.length/1))
      total_length / length(strings)
    else
      0.0
    end
  end

  defp count_complexity_indicators(reasoning_steps) do
    indicators = ["therefore", "because", "however", "moreover", "furthermore", "consequently"]

    Enum.reduce(reasoning_steps, 0, fn step, acc ->
      step_indicators =
        Enum.count(indicators, fn indicator ->
          String.contains?(String.downcase(step), indicator)
        end)

      acc + step_indicators
    end)
  end

  defp count_mathematical_expressions(reasoning_steps) do
    math_patterns = [
      ~r/\d+\s*[\+\-\*\/]\s*\d+/,
      ~r/=\s*\d+/,
      ~r/\b[a-z]\s*=\s*/,
      ~r/\^/,
      ~r/sqrt|log|sin|cos/
    ]

    Enum.reduce(reasoning_steps, 0, fn step, acc ->
      step_math =
        Enum.count(math_patterns, fn pattern ->
          String.match?(step, pattern)
        end)

      acc + step_math
    end)
  end

  defp generate_recommendation(evaluation_results) do
    metrics = evaluation_results.metrics

    cond do
      metrics.reasoning_coherence > 0.8 and metrics.solution_optimality > 0.8 ->
        "Excellent performance with strong reasoning and optimal solutions."

      metrics.reasoning_coherence > 0.6 and metrics.creativity > 0.7 ->
        "Good creative problem solving, continue developing systematic reasoning."

      metrics.vision_integration > 0.6 and
          Map.has_key?(evaluation_results.vision_analysis, :vision_steps_count) ->
        "Strong vision integration capabilities, focus on improving overall accuracy."

      metrics.step_efficiency < 0.5 ->
        "Focus on improving step efficiency and reducing redundant reasoning."

      true ->
        "Continue developing reasoning skills across all dimensions."
    end
  end

  # Enhanced evaluation functions inspired by evalscompany

  defp extract_reasoning_steps(response_text) do
    # Look for numbered steps or lines that start with step indicators
    step_patterns = [
      # Step 1: ...
      ~r/Step\s*\d+\s*:(.+?)(?=Step\s*\d+\s*:|$)/s,
      # 1. ...
      ~r/^\s*\d+\.\s*(.+?)$/m,
      # First, ...
      ~r/First,(.+?)(?:Second,|Next,|Then,|Finally,|$)/s,
      # Second, ...
      ~r/Second,(.+?)(?:Third,|Next,|Then,|Finally,|$)/s,
      # Third, ...
      ~r/Third,(.+?)(?:Fourth,|Next,|Then,|Finally,|$)/s,
      # Next, ...
      ~r/Next,(.+?)(?:Next,|Then,|Finally,|$)/s,
      # Then, ...
      ~r/Then,(.+?)(?:Next,|Then,|Finally,|$)/s,
      # Finally, ...
      ~r/Finally,(.+?)$/s
    ]

    all_steps = []

    for pattern <- step_patterns do
      matches = Regex.scan(pattern, response_text)

      for [_, step] <- matches do
        step = String.trim(step)
        # Ignore very short matches
        if String.length(step) > 10 do
          all_steps = [step | all_steps]
        end
      end
    end

    # If no structured steps found, try to split by sentences
    if length(all_steps) == 0 do
      sentences = String.split(response_text, ~r/\.\s+/)

      Enum.filter(sentences, fn sentence ->
        String.length(String.trim(sentence)) > 20
      end)
    else
      Enum.reverse(all_steps)
    end
  end

  defp extract_mathematical_expressions(text) do
    # Look for expressions like equations, inequalities, calculations
    expression_patterns = [
      # Basic arithmetic
      ~r/(?:^|\s)((?:\d+(?:\.\d+)?|\([^)]+\))\s*(?:[\+\-\*\/\^\=\<\>\≤\≥]\s*(?:\d+(?:\.\d+)?|\([^)]+\)))+)/,
      # Functions
      ~r/(?:^|\s)((?:sin|cos|tan|log|ln|exp|sqrt|∛|∜|∑|∏|∫|lim)[^\n\r]+)/,
      # Variable assignments
      ~r/(?:^|\s)([a-zA-Z](?:\([^)]+\))?\s*=\s*[^=\n\r]+)/,
      # LaTeX style math
      ~r/(?:^|\s)(\$[^$\n\r]+\$)/
    ]

    all_expressions = []

    for pattern <- expression_patterns do
      matches = Regex.scan(pattern, text)

      for [_, expr] <- matches do
        all_expressions = [String.trim(expr) | all_expressions]
      end
    end

    Enum.reverse(all_expressions)
  end

  defp evaluate_reasoning_coherence(reasoning_steps) do
    if length(reasoning_steps) == 0, do: 0.0

    # Check for logical flow indicators
    coherence_indicators = ["therefore", "because", "since", "thus", "hence", "consequently"]
    transition_words = ["first", "second", "third", "next", "then", "finally", "moreover"]

    coherence_score =
      reasoning_steps
      |> Enum.with_index()
      |> Enum.reduce(0.0, fn {step, index}, acc ->
        step_lower = String.downcase(step)

        # Check for coherence indicators
        coherence_count =
          Enum.count(coherence_indicators, fn indicator ->
            String.contains?(step_lower, indicator)
          end)

        # Check for appropriate transitions
        transition_count =
          Enum.count(transition_words, fn word ->
            String.contains?(step_lower, word)
          end)

        # Bonus for logical positioning
        position_bonus =
          if index > 0 do
            # Check if this step references previous steps
            if String.contains?(step_lower, ["previous", "above", "earlier", "from step"]) do
              0.2
            else
              0.0
            end
          else
            # First step gets small bonus
            0.1
          end

        step_score = coherence_count * 0.3 + transition_count * 0.2 + position_bonus
        acc + step_score
      end)

    # Normalize by number of steps
    normalized_score = coherence_score / length(reasoning_steps)
    min(1.0, normalized_score)
  end

  defp evaluate_conceptual_understanding(response_text) do
    # Look for evidence of deep understanding
    understanding_indicators = [
      "because",
      "since",
      "this means",
      "in other words",
      "this implies",
      "the reason is",
      "this is due to",
      "therefore",
      "consequently"
    ]

    domain_terms = [
      "principle",
      "theorem",
      "law",
      "concept",
      "theory",
      "definition",
      "property",
      "characteristic",
      "relationship",
      "pattern"
    ]

    response_lower = String.downcase(response_text)

    understanding_count =
      Enum.count(understanding_indicators, fn indicator ->
        String.contains?(response_lower, indicator)
      end)

    domain_count =
      Enum.count(domain_terms, fn term ->
        String.contains?(response_lower, term)
      end)

    # Check for explanatory depth
    explanation_depth =
      if String.length(response_text) > 200 do
        0.3
      else
        0.0
      end

    understanding_score = understanding_count * 0.2 + domain_count * 0.3 + explanation_depth
    min(1.0, understanding_score)
  end

  defp evaluate_solution_optimality(response_text, expected_outputs) do
    # Basic optimality check - can be enhanced with domain-specific logic
    if expected_outputs do
      # Compare with expected outputs if available
      # Placeholder - would implement actual comparison
      0.8
    else
      # Evaluate based on response characteristics
      efficiency_indicators = [
        "efficient",
        "optimal",
        "best",
        "minimize",
        "maximize",
        "least",
        "most"
      ]

      response_lower = String.downcase(response_text)

      efficiency_count =
        Enum.count(efficiency_indicators, fn indicator ->
          String.contains?(response_lower, indicator)
        end)

      min(1.0, efficiency_count * 0.25)
    end
  end

  defp evaluate_symbolic_manipulation(mathematical_expressions) do
    if length(mathematical_expressions) == 0, do: 0.0

    # Evaluate complexity and correctness of mathematical expressions
    complexity_score =
      mathematical_expressions
      |> Enum.reduce(0.0, fn expr, acc ->
        expr_score =
          cond do
            # Advanced operations
            String.contains?(expr, ["∫", "∑", "lim", "√"]) -> 1.0
            # Intermediate operations
            String.contains?(expr, ["^", "log", "sin", "cos"]) -> 0.8
            # Basic operations
            String.contains?(expr, ["+", "-", "*", "/"]) -> 0.6
            true -> 0.3
          end

        acc + expr_score
      end)

    # Normalize by number of expressions
    normalized_score = complexity_score / length(mathematical_expressions)
    min(1.0, normalized_score)
  end

  defp evaluate_error_sensitivity(_response_text) do
    # Placeholder for error sensitivity evaluation
    # Would check for error handling, edge cases, validation
    0.7
  end

  defp evaluate_reasoning_depth(reasoning_steps) do
    if length(reasoning_steps) == 0, do: 0.0

    # Evaluate depth based on step count and complexity
    # Optimal around 5 steps
    step_count_score = min(1.0, length(reasoning_steps) / 5.0)

    # Check for depth indicators
    depth_indicators = ["analyze", "examine", "consider", "evaluate", "assess", "investigate"]

    depth_score =
      reasoning_steps
      |> Enum.reduce(0.0, fn step, acc ->
        step_lower = String.downcase(step)

        depth_count =
          Enum.count(depth_indicators, fn indicator ->
            String.contains?(step_lower, indicator)
          end)

        acc + depth_count * 0.2
      end)

    # Normalize
    normalized_depth = depth_score / length(reasoning_steps)

    (step_count_score + normalized_depth) / 2
  end

  defp evaluate_creativity(response_text) do
    # Look for creative indicators
    creativity_indicators = [
      "alternative",
      "different",
      "novel",
      "unique",
      "creative",
      "innovative",
      "original",
      "new approach",
      "another way",
      "differently"
    ]

    response_lower = String.downcase(response_text)

    creativity_count =
      Enum.count(creativity_indicators, fn indicator ->
        String.contains?(response_lower, indicator)
      end)

    # Check for multiple solution approaches
    approach_indicators = ["method", "approach", "way", "technique", "strategy"]

    approach_count =
      Enum.count(approach_indicators, fn indicator ->
        String.contains?(response_lower, indicator)
      end)

    creativity_score = creativity_count * 0.3 + approach_count * 0.2
    min(1.0, creativity_score)
  end

  defp evaluate_step_performance(solver, step, response, outputs) do
    # Comprehensive step evaluation
    reasoning_analysis = evaluate_reasoning_quality(solver, response)

    %{
      reasoning_coherence: reasoning_analysis.metrics.reasoning_coherence,
      conceptual_understanding: reasoning_analysis.metrics.conceptual_understanding,
      solution_optimality: reasoning_analysis.metrics.solution_optimality,
      symbolic_manipulation: reasoning_analysis.metrics.symbolic_manipulation,
      error_sensitivity: reasoning_analysis.metrics.error_sensitivity,
      reasoning_depth: reasoning_analysis.metrics.reasoning_depth,
      creativity: reasoning_analysis.metrics.creativity,
      vision_integration: evaluate_vision_integration_score(response, step),
      # Placeholder
      step_efficiency: 0.8
    }
  end

  defp evaluate_vision_integration_score(response, step) do
    # Check if response appropriately references visual content
    if Map.get(step, :type) == :vision or String.contains?(to_string(step.name || ""), "vision") do
      response_lower = String.downcase(response)
      vision_references = ["image", "picture", "visual", "see", "shown", "displayed", "diagram"]

      reference_count =
        Enum.count(vision_references, fn ref ->
          String.contains?(response_lower, ref)
        end)

      min(1.0, reference_count * 0.3)
    else
      0.0
    end
  end

  defp generate_vision_response(solver, prompt_result) do
    # Handle vision-enabled generation
    if Map.has_key?(prompt_result, :vision_content) and length(prompt_result.vision_content) > 0 do
      # Use vision-capable model
      case generate_with_vision_support(prompt_result) do
        {:ok, response} ->
          {:ok,
           %{
             text: response,
             metadata: Map.merge(prompt_result.metadata, %{vision_processed: true})
           }}

        error ->
          error
      end
    else
      # Standard text generation
      case Dspy.LM.generate_text(prompt_result.text_prompt) do
        {:ok, response} ->
          {:ok,
           %{
             text: response,
             metadata: Map.merge(prompt_result.metadata, %{vision_processed: false})
           }}

        error ->
          error
      end
    end
  end

  defp generate_with_vision_support(prompt_result) do
    # Build vision-enabled request
    vision_messages = build_vision_messages(prompt_result)

    request = %{
      messages: vision_messages,
      max_tokens: 2000,
      temperature: 0.7
    }

    case Dspy.LM.generate(request) do
      {:ok, response} ->
        case get_in(response, [:choices, Access.at(0), :message, "content"]) do
          content when is_binary(content) -> {:ok, content}
          _ -> {:error, :invalid_vision_response}
        end

      error ->
        error
    end
  end

  defp build_vision_messages(prompt_result) do
    # Build messages with vision content
    text_message = %{
      "role" => "user",
      "content" => prompt_result.text_prompt
    }

    vision_messages =
      Enum.map(prompt_result.vision_content, fn content ->
        %{
          "role" => "user",
          "content" => [
            %{"type" => "text", "text" => "Please analyze this image: #{content.description}"},
            %{"type" => "image_url", "image_url" => %{"url" => content.content}}
          ]
        }
      end)

    [text_message | vision_messages]
  end

  defp extract_vision_content(inputs) do
    inputs
    |> Enum.filter(fn {_key, value} -> is_vision_content?(value) end)
    |> Enum.map(fn {key, value} ->
      %{
        field: key,
        content: value,
        description: "Visual content for #{key}"
      }
    end)
  end

  defp extract_text_content(inputs) do
    inputs
    |> Enum.reject(fn {_key, value} -> is_vision_content?(value) end)
    |> Enum.into(%{})
  end

  defp evaluate_vision_integration(response, vision_content) do
    if length(vision_content) > 0 do
      response_lower = String.downcase(response.text || response)
      vision_keywords = ["image", "picture", "visual", "see", "shown", "diagram", "chart"]

      keyword_matches =
        Enum.count(vision_keywords, fn keyword ->
          String.contains?(response_lower, keyword)
        end)

      %{
        vision_reference_score: min(1.0, keyword_matches * 0.2),
        total_vision_items: length(vision_content),
        vision_keywords_found: keyword_matches
      }
    else
      %{vision_enabled: false}
    end
  end

  defp calculate_complexity_score(text) do
    # Estimate complexity based on various factors
    base_complexity = 0.5

    text_length = String.length(text)
    length_factor = min(text_length / 1000.0, 0.3)

    # Count complex words/phrases
    complex_indicators = ["therefore", "consequently", "furthermore", "however", "nevertheless"]

    complex_count =
      Enum.count(complex_indicators, fn indicator ->
        String.contains?(String.downcase(text), indicator)
      end)

    complexity_factor = complex_count * 0.1

    min(1.0, base_complexity + length_factor + complexity_factor)
  end
end
