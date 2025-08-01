defmodule Dspy.Teleprompt.BootstrapFewShot do
  @moduledoc """
  BootstrapFewShot teleprompt - Automatic few-shot example generation and selection.
  
  This teleprompt automatically generates and validates few-shot examples by:
  1. Running the student program on training inputs
  2. Validating outputs using the provided metric
  3. Selecting the best examples for few-shot learning
  
  ## Usage
  
      teleprompt = Dspy.Teleprompt.BootstrapFewShot.new(
        metric: &Dspy.Metrics.exact_match/2,
        max_bootstrapped_demos: 4,
        max_labeled_demos: 4
      )
      
      {:ok, optimized_program} = Dspy.Teleprompt.BootstrapFewShot.compile(
        teleprompt, 
        program, 
        trainset
      )
  
  """
  
  @behaviour Dspy.Teleprompt
  
  alias Dspy.{Example, Module, Prediction, Evaluate, Trainset, Metrics}
  
  defstruct [
    :metric,                    # Evaluation metric function
    :teacher,                   # Teacher program for generating examples
    :max_bootstrapped_demos,    # Max bootstrapped examples
    :max_labeled_demos,         # Max labeled examples  
    :max_rounds,                # Max bootstrap rounds
    :max_errors,                # Max errors before stopping
    :num_candidate_programs,    # Number of candidate programs to try
    :num_threads,               # Parallel processing threads
    :seed,                      # Random seed
    :bootstrap_strategy         # Bootstrap sampling strategy
  ]
  
  @type t :: %__MODULE__{
    metric: function(),
    teacher: module() | nil,
    max_bootstrapped_demos: pos_integer(),
    max_labeled_demos: pos_integer(),
    max_rounds: pos_integer(),
    max_errors: pos_integer(),
    num_candidate_programs: pos_integer(),
    num_threads: pos_integer(),
    seed: integer(),
    bootstrap_strategy: atom()
  }
  
  @doc """
  Create a new BootstrapFewShot teleprompt.
  
  ## Options
  
  - `:metric` - Evaluation metric function (required)
  - `:teacher` - Teacher program for generating examples (defaults to student)
  - `:max_bootstrapped_demos` - Maximum bootstrapped examples (default: 4)
  - `:max_labeled_demos` - Maximum labeled examples (default: 4)
  - `:max_rounds` - Maximum bootstrap rounds (default: 1)
  - `:max_errors` - Maximum errors before stopping (default: 5)
  - `:num_candidate_programs` - Number of candidate programs (default: 16)
  - `:num_threads` - Parallel processing threads (default: auto)
  - `:seed` - Random seed for reproducibility
  - `:bootstrap_strategy` - Sampling strategy (:random, :diverse, :hard)
  
  """
  @impl Dspy.Teleprompt
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    unless Keyword.has_key?(opts, :metric) do
      raise ArgumentError, "BootstrapFewShot requires a :metric function"
    end
    
    %__MODULE__{
      metric: Keyword.fetch!(opts, :metric),
      teacher: Keyword.get(opts, :teacher),
      max_bootstrapped_demos: Keyword.get(opts, :max_bootstrapped_demos, 4),
      max_labeled_demos: Keyword.get(opts, :max_labeled_demos, 4),
      max_rounds: Keyword.get(opts, :max_rounds, 1),
      max_errors: Keyword.get(opts, :max_errors, 5),
      num_candidate_programs: Keyword.get(opts, :num_candidate_programs, 16),
      num_threads: Keyword.get(opts, :num_threads, System.schedulers_online()),
      seed: Keyword.get(opts, :seed, :os.system_time(:microsecond)),
      bootstrap_strategy: Keyword.get(opts, :bootstrap_strategy, :random)
    }
  end
  
  @doc """
  Compile a program with bootstrapped few-shot examples.
  
  ## Process
  
  1. Validate training set
  2. Generate bootstrapped examples using teacher/student
  3. Select best examples using metric
  4. Create optimized program with examples
  5. Evaluate and return best performing variant
  
  """
  @impl Dspy.Teleprompt
  @spec compile(t(), module(), list(Example.t())) :: {:ok, module()} | {:error, term()}
  def compile(%__MODULE__{} = teleprompt, student, trainset) do
    IO.puts("Starting BootstrapFewShot compilation...")
    
    with {:ok, validated_trainset} <- Trainset.validate(trainset),
         {:ok, teacher} <- get_teacher_program(teleprompt, student),
         {:ok, bootstrapped_examples} <- bootstrap_examples(teleprompt, teacher, validated_trainset),
         {:ok, labeled_examples} <- select_labeled_examples(teleprompt, validated_trainset),
         {:ok, candidate_programs} <- generate_candidate_programs(teleprompt, student, bootstrapped_examples, labeled_examples),
         {:ok, best_program} <- select_best_program(teleprompt, candidate_programs, validated_trainset) do
      
      IO.puts("BootstrapFewShot compilation completed successfully")
      {:ok, best_program}
    end
  end
  
  # Private functions
  
  defp get_teacher_program(%__MODULE__{teacher: nil}, student), do: {:ok, student}
  defp get_teacher_program(%__MODULE__{teacher: teacher}, _student), do: {:ok, teacher}
  
  defp bootstrap_examples(%__MODULE__{} = teleprompt, teacher, trainset) do
    IO.puts("Bootstrapping examples from #{length(trainset)} training examples...")
    
    %{
      max_bootstrapped_demos: max_demos,
      max_rounds: max_rounds,
      max_errors: max_errors,
      metric: metric,
      num_threads: num_threads,
      seed: seed
    } = teleprompt
    
    :rand.seed(:exsss, {seed, seed + 1, seed + 2})
    
    # Bootstrap examples across multiple rounds
    all_examples = for round <- 1..max_rounds, reduce: [] do
      acc_examples ->
        IO.puts("Bootstrap round #{round}/#{max_rounds}")
        
        round_examples = bootstrap_round(teacher, trainset, metric, max_demos, max_errors, num_threads)
        acc_examples ++ round_examples
    end
    
    # Select best examples
    best_examples = all_examples
    |> Enum.uniq_by(fn {example, _score} -> example.attrs end)
    |> Enum.sort_by(fn {_example, score} -> score end, :desc)
    |> Enum.take(max_demos)
    |> Enum.map(fn {example, _score} -> example end)
    
    IO.puts("Bootstrapped #{length(best_examples)} high-quality examples")
    {:ok, best_examples}
  end
  
  defp bootstrap_round(teacher, trainset, metric, max_demos, max_errors, num_threads) do
    # Sample training inputs for bootstrapping
    inputs = trainset
    |> Trainset.sample(max_demos * 2, strategy: :random)
    |> Enum.map(& &1.attrs)
    
    # Generate outputs using teacher program
    chunk_size = max(1, div(length(inputs), num_threads))
    chunks = Enum.chunk_every(inputs, chunk_size)
    
    results = chunks
    |> Task.async_stream(fn chunk ->
      bootstrap_chunk(teacher, chunk, metric, max_errors)
    end, max_concurrency: num_threads, timeout: 30_000)
    |> Enum.flat_map(fn {:ok, chunk_results} -> chunk_results end)
    |> Enum.filter(fn {_example, score} -> score > 0 end)
    
    results
  end
  
  defp bootstrap_chunk(teacher, inputs, metric, max_errors) do
    {results, _errors} = inputs
    |> Enum.reduce({[], 0}, fn input, {acc, error_count} ->
      if error_count >= max_errors do
        {acc, error_count}
      else
        case generate_bootstrap_example(teacher, input, metric) do
          {:ok, {example, score}} -> {[{example, score} | acc], error_count}
          {:error, _reason} -> {acc, error_count + 1}
        end
      end
    end)
    
    results
  end
  
  defp generate_bootstrap_example(teacher, input, metric) do
    try do
      # Generate output using teacher
      case Module.forward(teacher, input) do
        {:ok, prediction} ->
          # Create example from input + generated output
          example_attrs = Map.merge(input, prediction.attrs)
          example = Example.new(example_attrs)
          
          # Score the example (for self-consistency)
          score = Dspy.Teleprompt.run_metric(metric, example, prediction)
          
          if is_number(score) and score > 0 do
            {:ok, {example, score}}
          else
            {:error, "Invalid score: #{inspect(score)}"}
          end
          
        {:error, reason} ->
          {:error, "Teacher failed: #{reason}"}
      end
    rescue
      e -> {:error, "Exception: #{Exception.message(e)}"}
    end
  end
  
  defp select_labeled_examples(%__MODULE__{max_labeled_demos: max_labeled}, trainset) do
    # Select diverse labeled examples from training set
    labeled = Trainset.sample(trainset, max_labeled, strategy: :diverse)
    {:ok, labeled}
  end
  
  defp generate_candidate_programs(%__MODULE__{num_candidate_programs: num_candidates, seed: seed}, student, bootstrapped, labeled) do
    IO.puts("Generating #{num_candidates} candidate programs...")
    
    :rand.seed(:exsss, {seed + 1000, seed + 1001, seed + 1002})
    
    candidates = for i <- 1..num_candidates do
      # Randomly combine bootstrapped and labeled examples
      num_bootstrap = :rand.uniform(length(bootstrapped) + 1) - 1
      num_labeled = :rand.uniform(length(labeled) + 1) - 1
      
      selected_bootstrap = Enum.take_random(bootstrapped, num_bootstrap)
      selected_labeled = Enum.take_random(labeled, num_labeled)
      
      all_examples = selected_bootstrap ++ selected_labeled
      
      create_candidate_program(student, all_examples, i)
    end
    
    {:ok, candidates}
  end
  
  defp create_candidate_program(student, examples, candidate_id) do
    # Create a program variant with specific examples
    {:module, module_name, _binary, _exports} = defmodule :"Elixir.BootstrapCandidate#{candidate_id}" do
      @behaviour Dspy.Module
      
      @student student
      @examples examples
      @candidate_id candidate_id
      
      def __student__, do: @student
      def __examples__, do: @examples
      def __candidate_id__, do: @candidate_id
      
      @impl Dspy.Module
      def forward(input) do
        student = __student__()
        examples = __examples__()
        
        # Enhance input with few-shot examples
        enhanced_input = add_examples_to_context(input, examples)
        
        # Forward to student program
        Module.forward(student, enhanced_input)
      end
      
      @impl Dspy.Module
      def parameters do
        original_params = Module.parameters(__student__())
        
        Map.merge(original_params, %{
          few_shot_examples: __examples__(),
          num_bootstrap_examples: length(Enum.filter(__examples__(), &is_bootstrap_example/1)),
          num_labeled_examples: length(__examples__()) - length(Enum.filter(__examples__(), &is_bootstrap_example/1)),
          candidate_id: __candidate_id__()
        })
      end
      
      defp add_examples_to_context(input, examples) when is_map(input) do
        example_context = format_examples_for_context(examples)
        Map.put(input, :few_shot_examples, example_context)
      end
      
      defp add_examples_to_context(input, examples) do
        example_context = format_examples_for_context(examples)
        %{input: input, few_shot_examples: example_context}
      end
      
      defp format_examples_for_context(examples) do
        examples
        |> Enum.with_index(1)
        |> Enum.map(fn {example, idx} ->
          "Example #{idx}:\n" <> format_example_fields(example.attrs)
        end)
        |> Enum.join("\n\n")
      end
      
      defp format_example_fields(attrs) do
        attrs
        |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
        |> Enum.join("\n")
      end
      
      defp is_bootstrap_example(%Example{attrs: attrs}) do
        # Simple heuristic: if it has high confidence or was generated
        Map.get(attrs, :confidence, 0) > 0.8 or Map.has_key?(attrs, :generated)
      end
    end
    
    module_name
  end
  
  defp select_best_program(%__MODULE__{metric: metric, num_threads: num_threads}, candidates, validation_set) do
    IO.puts("Evaluating #{length(candidates)} candidate programs...")
    
    # Evaluate each candidate on validation set
    evaluations = candidates
    |> Task.async_stream(fn candidate ->
      result = Evaluate.evaluate(candidate, validation_set, metric, 
        num_threads: 1, progress: false)
      {candidate, result}
    end, max_concurrency: num_threads, timeout: 60_000)
    |> Enum.map(fn {:ok, result} -> result end)
    
    # Select best performing candidate
    {best_program, best_result} = evaluations
    |> Enum.max_by(fn {_program, result} -> result.mean end)
    
    IO.puts("Best program score: #{Float.round(best_result.mean, 3)} ± #{Float.round(best_result.std, 3)}")
    
    {:ok, best_program}
  end
end