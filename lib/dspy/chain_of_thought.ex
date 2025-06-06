defmodule Dspy.ChainOfThought do
  @moduledoc """
  Chain of Thought reasoning module.

  Extends basic prediction with step-by-step reasoning by adding
  a reasoning field to the signature and encouraging the model
  to show its work before generating the final answer.
  """

  use Dspy.Module

  defstruct [:signature, :examples, :max_retries, :reasoning_field]

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          reasoning_field: atom()
        }

  @doc """
  Create a new ChainOfThought module.
  """
  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)
    reasoning_field = Keyword.get(opts, :reasoning_field, :reasoning)

    augmented_signature = add_reasoning_field(base_signature, reasoning_field)

    %__MODULE__{
      signature: augmented_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      reasoning_field: reasoning_field
    }
  end

  @impl true
  def forward(cot, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(cot.signature, inputs),
         {:ok, prompt} <- build_prompt(cot, inputs),
         {:ok, response} <- generate_with_retries(prompt, cot.max_retries),
         {:ok, outputs} <- parse_response(cot, response) do
      prediction = Dspy.Prediction.new(outputs)
      {:ok, prediction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_signature(signature) when is_atom(signature) do
    signature.signature()
  end

  defp get_signature(signature), do: signature

  defp add_reasoning_field(signature, reasoning_field) do
    reasoning_field_def = %{
      name: reasoning_field,
      type: :string,
      description: "Think step by step to solve this problem",
      required: true,
      default: nil
    }

    # Insert reasoning field before other output fields
    new_output_fields = [reasoning_field_def | signature.output_fields]

    %{signature | output_fields: new_output_fields}
  end

  defp build_prompt(cot, inputs) do
    # Add chain of thought instructions
    enhanced_signature = add_cot_instructions(cot.signature)

    prompt_template = Dspy.Signature.to_prompt(enhanced_signature, cot.examples)

    filled_prompt =
      Enum.reduce(inputs, prompt_template, fn {key, value}, acc ->
        placeholder = "[input]"
        field_name = String.capitalize(Atom.to_string(key))
        String.replace(acc, "#{field_name}: #{placeholder}", "#{field_name}: #{value}")
      end)

    {:ok, filled_prompt}
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

  defp parse_response(cot, response_text) do
    case Dspy.Signature.parse_outputs(cot.signature, response_text) do
      {:error, _reason} = error -> error
      outputs when is_map(outputs) -> {:ok, outputs}
    end
  end
end
