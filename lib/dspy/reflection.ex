defmodule Dspy.Reflection do
  @moduledoc """
  Reflection reasoning module.

  Uses a two-stage process: first generates an initial answer,
  then reflects on that answer to potentially revise and improve it.
  This helps catch errors and improve the quality of reasoning.
  """

  use Dspy.Module

  defstruct [:signature, :examples, :max_retries, :reflection_prompt, :max_reflections]

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          reflection_prompt: String.t(),
          max_reflections: pos_integer()
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)

    %__MODULE__{
      signature: base_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      reflection_prompt: Keyword.get(opts, :reflection_prompt, default_reflection_prompt()),
      max_reflections: Keyword.get(opts, :max_reflections, 2)
    }
  end

  @impl true
  def forward(reflection, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(reflection.signature, inputs),
         {:ok, initial_answer} <- generate_initial_answer(reflection, inputs),
         {:ok, final_answer} <- reflect_and_improve(reflection, inputs, initial_answer, 0) do
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

  defp default_reflection_prompt do
    """
    Look at your previous answer carefully. Consider:
    1. Is the reasoning sound and logical?
    2. Are there any errors in the calculation or logic?
    3. Could the answer be improved or made more accurate?
    4. Is there any additional information that should be considered?

    If you find any issues, provide a corrected answer. If the original answer is correct, confirm it.
    """
  end

  defp generate_initial_answer(reflection, inputs) do
    cot_signature = add_reasoning_field(reflection.signature)
    enhanced_signature = add_cot_instructions(cot_signature)

    with {:ok, prompt} <- build_prompt(enhanced_signature, inputs, reflection.examples),
         {:ok, response} <- generate_with_retries(prompt, reflection.max_retries),
         {:ok, outputs} <- parse_response(enhanced_signature, response) do
      {:ok, outputs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp reflect_and_improve(reflection, _inputs, current_answer, reflection_count)
       when reflection_count >= reflection.max_reflections do
    {:ok, current_answer}
  end

  defp reflect_and_improve(reflection, inputs, current_answer, reflection_count) do
    reflection_signature = create_reflection_signature(reflection.signature)

    reflection_inputs =
      inputs
      |> Map.put(:previous_answer, format_previous_answer(current_answer))
      |> Map.put(:reflection_prompt, reflection.reflection_prompt)

    with {:ok, prompt} <- build_prompt(reflection_signature, reflection_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, reflection.max_retries),
         {:ok, reflected_outputs} <- parse_response(reflection_signature, response) do
      if should_update_answer?(current_answer, reflected_outputs) do
        reflect_and_improve(reflection, inputs, reflected_outputs, reflection_count + 1)
      else
        {:ok, current_answer}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp add_reasoning_field(signature) do
    reasoning_field_def = %{
      name: :reasoning,
      type: :string,
      description: "Think step by step to solve this problem",
      required: true,
      default: nil
    }

    new_output_fields = [reasoning_field_def | signature.output_fields]
    %{signature | output_fields: new_output_fields}
  end

  defp add_cot_instructions(signature) do
    cot_instructions = """
    Think step by step and show your reasoning before providing the final answer.
    Break down the problem and explain your thought process clearly.
    """

    existing_instructions = signature.instructions || ""

    combined_instructions =
      [existing_instructions, cot_instructions]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    %{signature | instructions: combined_instructions}
  end

  defp create_reflection_signature(base_signature) do
    input_fields = [
      %{
        name: :previous_answer,
        type: :string,
        description: "Previous answer to reflect upon",
        required: true,
        default: nil
      },
      %{
        name: :reflection_prompt,
        type: :string,
        description: "Reflection instructions",
        required: true,
        default: nil
      }
      | base_signature.input_fields
    ]

    output_fields = [
      %{
        name: :reflection,
        type: :string,
        description: "Reflection on the previous answer",
        required: true,
        default: nil
      },
      %{
        name: :should_revise,
        type: :boolean,
        description: "Whether the answer should be revised",
        required: true,
        default: nil
      }
      | base_signature.output_fields
    ]

    %{
      base_signature
      | input_fields: input_fields,
        output_fields: output_fields,
        instructions: "Reflect on the previous answer and determine if it needs revision."
    }
  end

  defp format_previous_answer(answer) do
    answer
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join("\n")
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
    {:ok, outputs}
  end

  defp should_update_answer?(_current_answer, reflected_outputs) do
    Map.get(reflected_outputs, :should_revise, false)
  end
end
