defmodule Dspy.Teleprompt.SIMBA do
  @moduledoc """
  SIMBA (Stochastic Iterative Model-Based Augmentation) teleprompt.
  
  SIMBA optimizes programs through iterative trajectory sampling and candidate generation:
  1. Sample program trajectories across training examples
  2. Generate new candidate programs using various strategies
  3. Evaluate candidates and select best-performing variations
  4. Iteratively refine the program
  
  ## Usage
  
      teleprompt = Dspy.Teleprompt.SIMBA.new(
        metric: &Dspy.Metrics.f1_score/2,
        max_steps: 8,
        num_candidates: 6
      )
      
      {:ok, optimized_program} = Dspy.Teleprompt.SIMBA.compile(
        teleprompt, 
        program, 
        trainset
      )
  
  """
  
  @behaviour Dspy.Teleprompt
  
  alias Dspy.{Example, Module, Prediction, Evaluate, Trainset, LM, Settings}
  
  defstruct [
    :metric,                        # Evaluation metric function
    :bsize,                         # Mini-batch size for optimization
    :num_candidates,                # Number of candidates per iteration
    :max_steps,                     # Maximum optimization iterations
    :max_demos,                     # Maximum demos per predictor
    :demo_input_field_maxlen,       # Maximum input field characters
    :num_threads,                   # Parallel execution threads
    :temperature_for_sampling,      # Temperature for program selection
    :temperature_for_candidates,    # Temperature for candidate generation
    :candidate_strategies,          # Strategies for generating candidates
    :trajectory_sampling_config,    # Configuration for trajectory sampling
    :seed,                          # Random seed
    :verbose                        # Whether to print progress
  ]
  
  @type candidate_strategy :: :append_demos | :append_rules | :modify_instructions | :sample_variations
  
  @type t :: %__MODULE__{
    metric: function(),
    bsize: pos_integer(),
    num_candidates: pos_integer(),
    max_steps: pos_integer(),
    max_demos: pos_integer(),
    demo_input_field_maxlen: pos_integer(),
    num_threads: pos_integer(),
    temperature_for_sampling: float(),
    temperature_for_candidates: float(),
    candidate_strategies: list(candidate_strategy()),
    trajectory_sampling_config: map(),
    seed: integer(),
    verbose: boolean()
  }
  
  @doc """
  Create a new SIMBA teleprompt.
  
  ## Options
  
  - `:metric` - Evaluation metric function (required)
  - `:bsize` - Mini-batch size for optimization (default: 32)
  - `:num_candidates` - Number of candidates per iteration (default: 6)
  - `:max_steps` - Maximum optimization iterations (default: 8)
  - `:max_demos` - Maximum demos per predictor (default: 4)
  - `:demo_input_field_maxlen` - Max input field characters (default: 100,000)
  - `:num_threads` - Parallel execution threads (default: auto)
  - `:temperature_for_sampling` - Temperature for sampling (default: 0.2)
  - `:temperature_for_candidates` - Temperature for candidates (default: 0.2)
  - `:seed` - Random seed for reproducibility
  - `:verbose` - Print optimization progress (default: true)
  
  """
  @impl Dspy.Teleprompt
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    unless Keyword.has_key?(opts, :metric) do
      raise ArgumentError, "SIMBA requires a :metric function"
    end
    
    %__MODULE__{
      metric: Keyword.fetch!(opts, :metric),
      bsize: Keyword.get(opts, :bsize, 32),
      num_candidates: Keyword.get(opts, :num_candidates, 6),
      max_steps: Keyword.get(opts, :max_steps, 8),
      max_demos: Keyword.get(opts, :max_demos, 4),
      demo_input_field_maxlen: Keyword.get(opts, :demo_input_field_maxlen, 100_000),
      num_threads: Keyword.get(opts, :num_threads, System.schedulers_online()),
      temperature_for_sampling: Keyword.get(opts, :temperature_for_sampling, 0.2),
      temperature_for_candidates: Keyword.get(opts, :temperature_for_candidates, 0.2),
      candidate_strategies: Keyword.get(opts, :candidate_strategies, [:append_demos, :append_rules, :modify_instructions]),
      trajectory_sampling_config: configure_trajectory_sampling(),
      seed: Keyword.get(opts, :seed, :os.system_time(:microsecond)),
      verbose: Keyword.get(opts, :verbose, true)
    }
  end
  
  @doc """
  Compile a program using SIMBA optimization.
  
  ## Process
  
  1. Initialize with baseline program
  2. For each iteration:
     a. Sample program trajectories across training examples
     b. Generate candidate programs using various strategies  
     c. Evaluate candidates on mini-batches
     d. Select best-performing program for next iteration
  3. Return final optimized program
  
  """
  @impl Dspy.Teleprompt
  @spec compile(t(), module(), list(Example.t())) :: {:ok, module()} | {:error, term()}
  def compile(%__MODULE__{} = teleprompt, student, trainset) do
    if teleprompt.verbose do
      IO.puts("Starting SIMBA optimization with #{teleprompt.max_steps} steps...")
    end
    
    with {:ok, validated_trainset} <- validate_trainset(trainset),
         {:ok, optimized_program} <- run_simba_optimization(teleprompt, student, validated_trainset) do
      
      if teleprompt.verbose do
        IO.puts("SIMBA optimization completed successfully")
      end
      
      {:ok, optimized_program}
    end
  end
  
  # Private functions
  
  defp configure_trajectory_sampling do
    %{
      num_trajectories: 10,
      trajectory_length: 5,
      error_analysis: true,
      pattern_extraction: true
    }
  end
  
  defp validate_trainset(trainset) do
    if length(trainset) < 5 do
      {:error, "Insufficient training data for SIMBA (need at least 5 examples)"}
    else
      {:ok, trainset}
    end
  end
  
  defp run_simba_optimization(%__MODULE__{} = teleprompt, initial_program, trainset) do
    %{max_steps: max_steps, verbose: verbose} = teleprompt
    
    # Initialize optimization state
    current_program = initial_program
    best_score = evaluate_program_baseline(teleprompt, current_program, trainset)
    
    if verbose do
      IO.puts("Baseline score: #{Float.round(best_score, 3)}")
    end
    
    # Run SIMBA iterations
    final_program = for step <- 1..max_steps, reduce: current_program do
      program ->
        if verbose do
          IO.puts("SIMBA step #{step}/#{max_steps}")
        end
        
        run_simba_step(teleprompt, program, trainset, step)
    end
    
    {:ok, final_program}
  end
  
  defp evaluate_program_baseline(%__MODULE__{metric: metric, bsize: bsize}, program, trainset) do
    eval_batch = Enum.take_random(trainset, min(bsize, length(trainset)))
    result = Evaluate.evaluate(program, eval_batch, metric, progress: false)
    result.mean
  end
  
  defp run_simba_step(%__MODULE__{} = teleprompt, current_program, trainset, step) do
    %{
      num_candidates: num_candidates,
      bsize: bsize,
      verbose: verbose
    } = teleprompt
    
    # Sample program trajectories
    trajectories = sample_program_trajectories(teleprompt, current_program, trainset)
    
    # Generate candidate programs
    candidates = generate_candidate_programs(teleprompt, current_program, trajectories, step)
    
    # Evaluate candidates on mini-batch
    eval_batch = Enum.take_random(trainset, min(bsize, length(trainset)))
    
    evaluations = evaluate_candidates(teleprompt, candidates, eval_batch)
    
    # Select best candidate
    {best_candidate, best_score} = select_best_candidate(evaluations)
    
    current_score = evaluate_program_baseline(teleprompt, current_program, eval_batch)
    
    if best_score > current_score do
      if verbose do
        IO.puts("  Improved: #{Float.round(current_score, 3)} -> #{Float.round(best_score, 3)}")
      end
      best_candidate
    else
      if verbose do
        IO.puts("  No improvement found")
      end
      current_program
    end
  end
  
  defp sample_program_trajectories(%__MODULE__{} = teleprompt, program, trainset) do
    %{
      trajectory_sampling_config: config,
      num_threads: num_threads
    } = teleprompt
    
    num_trajectories = config.num_trajectories
    trajectory_length = config.trajectory_length
    
    # Sample diverse examples for trajectory analysis
    sample_examples = Trainset.sample(trainset, num_trajectories, strategy: :diverse)
    
    # Generate trajectories in parallel
    trajectories = sample_examples
    |> Task.async_stream(fn example ->
      generate_single_trajectory(program, example, trajectory_length, teleprompt.metric)
    end, max_concurrency: num_threads, timeout: 30_000)
    |> Enum.map(fn {:ok, trajectory} -> trajectory end)
    |> Enum.filter(&(&1 != nil))
    
    trajectories
  end
  
  defp generate_single_trajectory(program, example, max_length, metric) do
    try do
      # Generate program execution trajectory
      case Module.forward(program, example.attrs) do
        {:ok, prediction} ->
          score = Dspy.Teleprompt.run_metric(metric, example, prediction)
          
          %{
            input: example.attrs,
            output: prediction.attrs,
            score: score,
            success: is_number(score) and score > 0,
            error_analysis: analyze_prediction_errors(example, prediction),
            patterns: extract_patterns(example, prediction)
          }
          
        {:error, reason} ->
          %{
            input: example.attrs,
            output: nil,
            score: 0.0,
            success: false,
            error_analysis: %{error: reason},
            patterns: []
          }
      end
    rescue
      e ->
        %{
          input: example.attrs,
          output: nil,
          score: 0.0,
          success: false,
          error_analysis: %{exception: Exception.message(e)},
          patterns: []
        }
    end
  end
  
  defp analyze_prediction_errors(example, prediction) do
    # Simple error analysis
    expected_fields = Map.keys(example.attrs)
    predicted_fields = Map.keys(prediction.attrs)
    
    %{
      missing_fields: expected_fields -- predicted_fields,
      extra_fields: predicted_fields -- expected_fields,
      field_mismatches: analyze_field_mismatches(example.attrs, prediction.attrs)
    }
  end
  
  defp analyze_field_mismatches(expected, predicted) do
    common_fields = Map.keys(expected) |> Enum.filter(&Map.has_key?(predicted, &1))
    
    common_fields
    |> Enum.map(fn field ->
      expected_val = Map.get(expected, field)
      predicted_val = Map.get(predicted, field)
      
      if expected_val != predicted_val do
        {field, %{expected: expected_val, predicted: predicted_val}}
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Map.new()
  end
  
  defp extract_patterns(example, prediction) do
    # Extract useful patterns from successful examples
    input_text = example.attrs |> Map.values() |> Enum.join(" ")
    output_text = prediction.attrs |> Map.values() |> Enum.join(" ")
    
    [
      %{type: :input_length, value: String.length(input_text)},
      %{type: :output_length, value: String.length(output_text)},
      %{type: :field_count, value: map_size(prediction.attrs)},
      %{type: :common_words, value: extract_common_words(input_text, output_text)}
    ]
  end
  
  defp extract_common_words(input, output) do
    input_words = String.split(input) |> MapSet.new()
    output_words = String.split(output) |> MapSet.new()
    
    MapSet.intersection(input_words, output_words) |> MapSet.to_list() |> Enum.take(5)
  end
  
  defp generate_candidate_programs(%__MODULE__{} = teleprompt, current_program, trajectories, step) do
    %{
      num_candidates: num_candidates,
      candidate_strategies: strategies,
      temperature_for_candidates: temperature
    } = teleprompt
    
    # Generate candidates using different strategies
    candidates = strategies
    |> Enum.flat_map(fn strategy ->
      generate_candidates_with_strategy(strategy, current_program, trajectories, num_candidates, temperature, step)
    end)
    |> Enum.take(num_candidates)
    
    candidates
  end
  
  defp generate_candidates_with_strategy(strategy, program, trajectories, num_candidates, temperature, step) do
    case strategy do
      :append_demos ->
        generate_demo_candidates(program, trajectories, num_candidates)
        
      :append_rules ->
        generate_rule_candidates(program, trajectories, num_candidates, temperature)
        
      :modify_instructions ->
        generate_instruction_candidates(program, trajectories, num_candidates, temperature)
        
      :sample_variations ->
        generate_variation_candidates(program, trajectories, num_candidates, step)
        
      _ ->
        []
    end
  end
  
  defp generate_demo_candidates(program, trajectories, num_candidates) do
    # Generate candidates by adding successful trajectories as demonstrations
    successful_trajectories = trajectories |> Enum.filter(& &1.success) |> Enum.take(num_candidates)
    
    successful_trajectories
    |> Enum.with_index()
    |> Enum.map(fn {trajectory, idx} ->
      create_demo_enhanced_program(program, trajectory, idx)
    end)
  end
  
  defp generate_rule_candidates(program, trajectories, num_candidates, temperature) do
    # Generate candidates by extracting and adding rules from patterns
    patterns = trajectories |> Enum.flat_map(& &1.patterns) |> Enum.uniq()
    
    patterns
    |> Enum.take(num_candidates)
    |> Enum.with_index()
    |> Enum.map(fn {pattern, idx} ->
      create_rule_enhanced_program(program, pattern, idx, temperature)
    end)
  end
  
  defp generate_instruction_candidates(program, trajectories, num_candidates, temperature) do
    # Generate candidates by modifying instructions based on error analysis
    error_patterns = trajectories 
    |> Enum.map(& &1.error_analysis) 
    |> Enum.filter(&(&1 != %{}))
    |> Enum.take(num_candidates)
    
    error_patterns
    |> Enum.with_index()
    |> Enum.map(fn {error_analysis, idx} ->
      create_instruction_modified_program(program, error_analysis, idx, temperature)
    end)
  end
  
  defp generate_variation_candidates(program, trajectories, num_candidates, step) do
    # Generate variants by sampling different configurations
    for i <- 1..num_candidates do
      create_variation_program(program, trajectories, i, step)
    end
  end
  
  defp create_demo_enhanced_program(original_program, trajectory, candidate_id) do
    # Create program with additional demonstration
    {:module, module_name, _binary, _exports} = defmodule :"Elixir.SIMBADemoCandidate#{candidate_id}" do
      @behaviour Dspy.Module
      
      @original_program original_program
      @demo_trajectory trajectory
      @candidate_id candidate_id
      
      def __original_program__, do: @original_program
      def __demo_trajectory__, do: @demo_trajectory
      def __candidate_id__, do: @candidate_id
      
      @impl Dspy.Module
      def forward(input) do
        original = __original_program__()
        demo = __demo_trajectory__()
        
        # Add demonstration to context
        enhanced_input = add_demo_to_context(input, demo)
        
        # Forward to original program
        Module.forward(original, enhanced_input)
      end
      
      @impl Dspy.Module
      def parameters do
        original_params = Module.parameters(__original_program__())
        
        Map.merge(original_params, %{
          simba_demo_trajectory: __demo_trajectory__(),
          simba_candidate_type: :demo_enhanced,
          simba_candidate_id: __candidate_id__()
        })
      end
      
      defp add_demo_to_context(input, demo) when is_map(input) do
        demo_text = format_demo_for_context(demo)
        Map.put(input, :simba_demo, demo_text)
      end
      
      defp add_demo_to_context(input, demo) do
        demo_text = format_demo_for_context(demo)
        %{input: input, simba_demo: demo_text}
      end
      
      defp format_demo_for_context(demo) do
        if demo.success do
          input_text = demo.input |> Enum.map(fn {k, v} -> "#{k}: #{v}" end) |> Enum.join(", ")
          output_text = demo.output |> Enum.map(fn {k, v} -> "#{k}: #{v}" end) |> Enum.join(", ")
          "Example: #{input_text} -> #{output_text}"
        else
          ""
        end
      end
    end
    
    module_name
  end
  
  defp create_rule_enhanced_program(original_program, pattern, candidate_id, _temperature) do
    # Create program with extracted rule
    {:module, module_name, _binary, _exports} = defmodule :"Elixir.SIMBARuleCandidate#{candidate_id}" do
      @behaviour Dspy.Module
      
      @original_program original_program
      @pattern_rule pattern
      @candidate_id candidate_id
      
      def __original_program__, do: @original_program
      def __pattern_rule__, do: @pattern_rule
      def __candidate_id__, do: @candidate_id
      
      @impl Dspy.Module
      def forward(input) do
        original = __original_program__()
        rule = __pattern_rule__()
        
        # Apply rule to input
        enhanced_input = apply_rule_to_context(input, rule)
        
        # Forward to original program
        Module.forward(original, enhanced_input)
      end
      
      @impl Dspy.Module
      def parameters do
        original_params = Module.parameters(__original_program__())
        
        Map.merge(original_params, %{
          simba_pattern_rule: __pattern_rule__(),
          simba_candidate_type: :rule_enhanced,
          simba_candidate_id: __candidate_id__()
        })
      end
      
      defp apply_rule_to_context(input, rule) when is_map(input) do
        rule_guidance = format_rule_guidance(rule)
        Map.put(input, :simba_rule, rule_guidance)
      end
      
      defp apply_rule_to_context(input, rule) do
        rule_guidance = format_rule_guidance(rule)
        %{input: input, simba_rule: rule_guidance}
      end
      
      defp format_rule_guidance(pattern) do
        case pattern.type do
          :input_length -> "Consider input length: #{pattern.value} characters"
          :output_length -> "Target output length: ~#{pattern.value} characters"
          :field_count -> "Include #{pattern.value} output fields"
          :common_words -> "Focus on these key terms: #{Enum.join(pattern.value, ", ")}"
          _ -> "Apply pattern: #{inspect(pattern)}"
        end
      end
    end
    
    module_name
  end
  
  defp create_instruction_modified_program(original_program, error_analysis, candidate_id, _temperature) do
    # Create program with modified instructions based on error analysis
    {:module, module_name, _binary, _exports} = defmodule :"Elixir.SIMBAInstructionCandidate#{candidate_id}" do
      @behaviour Dspy.Module
      
      @original_program original_program
      @error_analysis error_analysis
      @candidate_id candidate_id
      
      def __original_program__, do: @original_program
      def __error_analysis__, do: @error_analysis
      def __candidate_id__, do: @candidate_id
      
      @impl Dspy.Module
      def forward(input) do
        original = __original_program__()
        errors = __error_analysis__()
        
        # Add error-based instruction modifications
        enhanced_input = add_error_corrections(input, errors)
        
        # Forward to original program
        Module.forward(original, enhanced_input)
      end
      
      @impl Dspy.Module
      def parameters do
        original_params = Module.parameters(__original_program__())
        
        Map.merge(original_params, %{
          simba_error_analysis: __error_analysis__(),
          simba_candidate_type: :instruction_modified,
          simba_candidate_id: __candidate_id__()
        })
      end
      
      defp add_error_corrections(input, error_analysis) when is_map(input) do
        corrections = format_error_corrections(error_analysis)
        Map.put(input, :simba_corrections, corrections)
      end
      
      defp add_error_corrections(input, error_analysis) do
        corrections = format_error_corrections(error_analysis)
        %{input: input, simba_corrections: corrections}
      end
      
      defp format_error_corrections(error_analysis) do
        corrections = []
        
        corrections = if length(error_analysis.missing_fields || []) > 0 do
          ["Ensure these fields are included: #{Enum.join(error_analysis.missing_fields, ", ")}" | corrections]
        else
          corrections
        end
        
        corrections = if length(error_analysis.extra_fields || []) > 0 do
          ["Avoid including these fields: #{Enum.join(error_analysis.extra_fields, ", ")}" | corrections]
        else
          corrections
        end
        
        corrections = if map_size(error_analysis.field_mismatches || %{}) > 0 do
          mismatch_guidance = error_analysis.field_mismatches
          |> Enum.map(fn {field, mismatch} -> "#{field}: expected #{mismatch.expected}" end)
          |> Enum.join("; ")
          
          ["Fix these field values: #{mismatch_guidance}" | corrections]
        else
          corrections
        end
        
        Enum.join(corrections, ". ")
      end
    end
    
    module_name
  end
  
  defp create_variation_program(original_program, _trajectories, variant_id, step) do
    # Create program variation
    {:module, module_name, _binary, _exports} = defmodule :"Elixir.SIMBAVariationCandidate#{variant_id}_#{step}" do
      @behaviour Dspy.Module
      
      @original_program original_program
      @variant_id variant_id
      @step step
      
      def __original_program__, do: @original_program
      def __variant_id__, do: @variant_id
      def __step__, do: @step
      
      @impl Dspy.Module
      def forward(input) do
        original = __original_program__()
        
        # Apply variation to input
        varied_input = apply_variation(input, __variant_id__(), __step__())
        
        # Forward to original program
        Module.forward(original, varied_input)
      end
      
      @impl Dspy.Module
      def parameters do
        original_params = Module.parameters(__original_program__())
        
        Map.merge(original_params, %{
          simba_variant_id: __variant_id__(),
          simba_step: __step__(),
          simba_candidate_type: :variation
        })
      end
      
      defp apply_variation(input, variant_id, step) when is_map(input) do
        variation_hint = "Variation #{variant_id}, Step #{step}: Try alternative approach"
        Map.put(input, :simba_variation, variation_hint)
      end
      
      defp apply_variation(input, variant_id, step) do
        variation_hint = "Variation #{variant_id}, Step #{step}: Try alternative approach"
        %{input: input, simba_variation: variation_hint}
      end
    end
    
    module_name
  end
  
  defp evaluate_candidates(%__MODULE__{metric: metric, num_threads: num_threads}, candidates, eval_batch) do
    # Evaluate all candidates in parallel
    candidates
    |> Task.async_stream(fn candidate ->
      result = Evaluate.evaluate(candidate, eval_batch, metric, progress: false)
      {candidate, result.mean}
    end, max_concurrency: num_threads, timeout: 60_000)
    |> Enum.map(fn {:ok, result} -> result end)
  end
  
  defp select_best_candidate(evaluations) do
    evaluations
    |> Enum.max_by(fn {_candidate, score} -> score end)
  end
end