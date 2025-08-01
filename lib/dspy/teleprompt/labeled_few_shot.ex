defmodule Dspy.Teleprompt.LabeledFewShot do
  @moduledoc """
  LabeledFewShot teleprompt - Simple few-shot learning with labeled examples.
  
  This is the most basic teleprompt that simply adds labeled examples
  to the program's signature to enable few-shot learning.
  
  ## Usage
  
      teleprompt = Dspy.Teleprompt.LabeledFewShot.new(k: 3)
      {:ok, optimized_program} = Dspy.Teleprompt.LabeledFewShot.compile(teleprompt, program, trainset)
  
  """
  
  @behaviour Dspy.Teleprompt
  
  alias Dspy.{Example, Module, Signature, Trainset}
  
  defstruct [
    :k,                    # Number of examples to include
    :seed,                 # Random seed for example selection
    :selection_strategy,   # How to select examples (:random, :diverse, etc.)
    :include_reasoning     # Whether to include reasoning in examples
  ]
  
  @type t :: %__MODULE__{
    k: pos_integer(),
    seed: integer(),
    selection_strategy: atom(),
    include_reasoning: boolean()
  }
  
  @doc """
  Create a new LabeledFewShot teleprompt.
  
  ## Options
  
  - `:k` - Number of few-shot examples to include (default: 3)
  - `:seed` - Random seed for reproducible example selection
  - `:selection_strategy` - Strategy for selecting examples (:random, :diverse, :balanced)
  - `:include_reasoning` - Include reasoning traces in examples (default: false)
  
  ## Examples
  
      teleprompt = LabeledFewShot.new(k: 5, selection_strategy: :diverse)
  
  """
  @impl Dspy.Teleprompt
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      k: Keyword.get(opts, :k, 3),
      seed: Keyword.get(opts, :seed, :os.system_time(:microsecond)),
      selection_strategy: Keyword.get(opts, :selection_strategy, :random),
      include_reasoning: Keyword.get(opts, :include_reasoning, false)
    }
  end
  
  @doc """
  Compile a program with labeled few-shot examples.
  
  ## Parameters
  
  - `teleprompt` - LabeledFewShot configuration
  - `program` - DSPy program to optimize
  - `trainset` - Training examples to select from
  
  ## Returns
  
  `{:ok, optimized_program}` with few-shot examples embedded
  
  """
  @impl Dspy.Teleprompt
  @spec compile(t(), module(), list(Example.t())) :: {:ok, module()} | {:error, term()}
  def compile(%__MODULE__{} = teleprompt, program, trainset) do
    with {:ok, validated_trainset} <- Trainset.validate(trainset),
         {:ok, selected_examples} <- select_examples(teleprompt, validated_trainset) do
      
      # Create optimized program with few-shot examples
      optimized_program = create_few_shot_program(program, selected_examples, teleprompt)
      
      {:ok, optimized_program}
    end
  end
  
  # Private functions
  
  defp select_examples(%__MODULE__{k: k, selection_strategy: strategy, seed: seed}, trainset) do
    if length(trainset) == 0 do
      {:error, "Empty training set"}
    else
      selected = Trainset.sample(trainset, k, strategy: strategy, seed: seed)
      {:ok, selected}
    end
  end
  
  defp create_few_shot_program(program, examples, %__MODULE__{include_reasoning: include_reasoning}) do
    # Create a new module that wraps the original program with few-shot examples
    {:module, optimized_program, _binary, _exports} = defmodule OptimizedLabeledFewShotProgram do
      @behaviour Dspy.Module
      
      @program program
      @examples examples
      @include_reasoning include_reasoning
      
      def __program__, do: @program
      def __examples__, do: @examples
      def __include_reasoning__, do: @include_reasoning
      
      @impl Dspy.Module
      def forward(input) do
        program = __program__()
        examples = __examples__()
        include_reasoning = __include_reasoning__()
        
        # Add examples to the program's context
        enhanced_input = enhance_input_with_examples(input, examples, include_reasoning)
        
        # Forward to original program
        Module.forward(program, enhanced_input)
      end
      
      @impl Dspy.Module
      def parameters do
        # Return parameters from the original program plus our examples
        original_params = Module.parameters(__program__())
        example_params = %{
          few_shot_examples: __examples__(),
          num_examples: length(__examples__())
        }
        
        Map.merge(original_params, example_params)
      end
      
      defp enhance_input_with_examples(input, examples, include_reasoning) do
        # Add few-shot examples to the input context
        example_text = format_examples_as_text(examples, include_reasoning)
        
        # Add examples to input (implementation depends on program structure)
        case input do
          %{} = input_map ->
            Map.put(input_map, :few_shot_examples, example_text)
          
          input ->
            # For non-map inputs, we'll need to modify the signature
            # This is a simplified implementation
            %{input: input, few_shot_examples: example_text}
        end
      end
      
      defp format_examples_as_text(examples, include_reasoning) do
        examples
        |> Enum.with_index(1)
        |> Enum.map(fn {example, idx} ->
          format_single_example(example, idx, include_reasoning)
        end)
        |> Enum.join("\n\n")
      end
      
      defp format_single_example(%Example{attrs: attrs}, idx, include_reasoning) do
        # Format example as demonstration
        formatted_fields = attrs
        |> Enum.map(fn {key, value} ->
          "#{humanize_field_name(key)}: #{value}"
        end)
        |> Enum.join("\n")
        
        if include_reasoning and Map.has_key?(attrs, :reasoning) do
          "Example #{idx}:\n#{formatted_fields}"
        else
          # Exclude reasoning field for cleaner examples
          filtered_attrs = Map.delete(attrs, :reasoning)
          formatted_fields = filtered_attrs
          |> Enum.map(fn {key, value} ->
            "#{humanize_field_name(key)}: #{value}"
          end)
          |> Enum.join("\n")
          
          "Example #{idx}:\n#{formatted_fields}"
        end
      end
      
      defp humanize_field_name(field) when is_atom(field) do
        field
        |> Atom.to_string()
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
      end
      
      defp humanize_field_name(field), do: to_string(field)
    end
    
    optimized_program
  end
end