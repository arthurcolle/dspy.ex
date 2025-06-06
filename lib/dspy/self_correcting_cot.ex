defmodule Dspy.SelfCorrectingCoT do
  @moduledoc """
  Self-Correcting Chain of Thought reasoning module.

  Extends basic Chain of Thought with self-correction capabilities.
  After generating an initial answer, the model reviews its own work
  and makes corrections if necessary, improving accuracy.
  """

  use Dspy.Module

  defstruct [:signature, :examples, :max_retries, :max_corrections, :correction_threshold]

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          max_corrections: pos_integer(),
          correction_threshold: float()
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)
    augmented_signature = add_cot_fields(base_signature)

    %__MODULE__{
      signature: augmented_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      max_corrections: Keyword.get(opts, :max_corrections, 2),
      correction_threshold: Keyword.get(opts, :correction_threshold, 0.7)
    }
  end

  @impl true
  def forward(sccot, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(sccot.signature, inputs),
         {:ok, initial_answer} <- generate_initial_answer(sccot, inputs),
         {:ok, final_answer} <- self_correct(sccot, inputs, initial_answer, 0) do
      prediction = Dspy.Prediction.new(final_answer)
      {:ok, prediction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_signature(signature) when is_atom(signature) do
    signature.signature()
  end

  defp get_signature(signature), do: signature

  defp add_cot_fields(signature) do
    new_output_fields = [
      %{
        name: :reasoning,
        type: :string,
        description: "Step-by-step reasoning",
        required: true,
        default: nil
      },
      %{
        name: :confidence,
        type: :float,
        description: "Confidence in the answer (0.0 to 1.0)",
        required: true,
        default: nil
      }
      | signature.output_fields
    ]

    %{signature | output_fields: new_output_fields}
  end

  defp generate_initial_answer(sccot, inputs) do
    enhanced_signature = add_initial_instructions(sccot.signature)

    with {:ok, prompt} <- build_prompt(enhanced_signature, inputs, sccot.examples),
         {:ok, response} <- generate_with_retries(prompt, sccot.max_retries),
         {:ok, outputs} <- parse_response(enhanced_signature, response) do
      {:ok, outputs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp self_correct(sccot, _inputs, current_answer, correction_count)
       when correction_count >= sccot.max_corrections do
    {:ok, current_answer}
  end

  defp self_correct(sccot, inputs, current_answer, correction_count) do
    confidence = Map.get(current_answer, :confidence, 1.0)

    if confidence >= sccot.correction_threshold do
      {:ok, current_answer}
    else
      case attempt_correction(sccot, inputs, current_answer) do
        {:ok, corrected_answer} ->
          self_correct(sccot, inputs, corrected_answer, correction_count + 1)

        {:error, _reason} ->
          {:ok, current_answer}
      end
    end
  end

  defp attempt_correction(sccot, inputs, previous_answer) do
    correction_signature = create_correction_signature(sccot.signature)

    correction_inputs =
      inputs
      |> Map.put(:previous_reasoning, Map.get(previous_answer, :reasoning, ""))
      |> Map.put(:previous_answer, format_previous_answer(previous_answer))
      |> Map.put(:previous_confidence, Map.get(previous_answer, :confidence, 0.0))

    with {:ok, prompt} <- build_prompt(correction_signature, correction_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, sccot.max_retries),
         {:ok, outputs} <- parse_response(correction_signature, response) do
      {:ok, outputs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp add_initial_instructions(signature) do
    initial_instructions = """
    Think step by step to solve this problem. Show your reasoning clearly.
    At the end, provide a confidence score from 0.0 to 1.0 indicating how confident you are in your answer.
    Be honest about your confidence - if you're unsure, use a lower score.
    """

    existing_instructions = signature.instructions || ""

    combined_instructions =
      [existing_instructions, initial_instructions]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    %{signature | instructions: combined_instructions}
  end

  defp create_correction_signature(base_signature) do
    input_fields = [
      %{
        name: :previous_reasoning,
        type: :string,
        description: "Previous reasoning steps",
        required: true,
        default: nil
      },
      %{
        name: :previous_answer,
        type: :string,
        description: "Previous answer",
        required: true,
        default: nil
      },
      %{
        name: :previous_confidence,
        type: :float,
        description: "Previous confidence score",
        required: true,
        default: nil
      }
      | base_signature.input_fields
    ]

    correction_instructions = """
    Review your previous reasoning and answer carefully. Look for:
    1. Logical errors or inconsistencies
    2. Calculation mistakes
    3. Missing steps or considerations
    4. Assumptions that might be incorrect

    If you find errors, provide corrected reasoning and answer.
    If the original is correct, reaffirm it but try to improve confidence.
    Provide a new confidence score reflecting your certainty.
    """

    %{
      base_signature
      | input_fields: input_fields,
        instructions: correction_instructions
    }
  end

  defp format_previous_answer(answer) do
    main_answer_field = find_main_answer_field(answer)
    Map.get(answer, main_answer_field, "No answer found")
  end

  defp find_main_answer_field(answer) do
    # Look for common answer field names, excluding meta fields
    answer_fields = [:answer, :result, :solution, :output, :response]

    # If no standard field found, get the first non-meta field
    Enum.find(answer_fields, fn field ->
      Map.has_key?(answer, field)
    end) ||
      answer
      |> Map.keys()
      |> Enum.reject(fn key -> key in [:reasoning, :confidence] end)
      |> List.first()
  end

  defp build_prompt(signature, inputs, examples) do
    prompt_template = Dspy.Signature.to_prompt(signature, examples)

    filled_prompt =
      Enum.reduce(inputs, prompt_template, fn {key, value}, acc ->
        placeholder = "[input]"
        field_name = String.capitalize(Atom.to_string(key))
        String.replace(acc, "#{field_name}: #{placeholder}", "#{field_name}: #{value}")
      end)

    {:ok, filled_prompt}
  end

  defp generate_with_retries(prompt, retries) do
    case Dspy.LM.generate_text(prompt) do
      {:ok, response} ->
        {:ok, response}

      {:error, _reason} when retries > 0 ->
        Process.sleep(1000)
        generate_with_retries(prompt, retries - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(signature, response_text) do
    outputs = Dspy.Signature.parse_outputs(signature, response_text)

    # Ensure confidence is parsed as a float
    outputs_with_confidence =
      case Map.get(outputs, :confidence) do
        confidence when is_binary(confidence) ->
          case Float.parse(confidence) do
            {parsed_confidence, _} -> Map.put(outputs, :confidence, parsed_confidence)
            :error -> Map.put(outputs, :confidence, 0.5)
          end

        confidence when is_number(confidence) ->
          Map.put(outputs, :confidence, confidence / 1.0)

        _ ->
          Map.put(outputs, :confidence, 0.5)
      end

    {:ok, outputs_with_confidence}
  end
end
