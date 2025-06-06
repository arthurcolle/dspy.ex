defmodule Dspy.Predict do
  @moduledoc """
  Basic prediction module for DSPy.

  The Predict module takes a signature and generates predictions
  by constructing prompts and calling the language model.
  """

  use Dspy.Module

  defstruct [:signature, :examples, :max_retries]

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer()
        }

  @doc """
  Create a new Predict module.
  """
  def new(signature, opts \\ []) do
    %__MODULE__{
      signature: get_signature(signature),
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3)
    }
  end

  @impl true
  def forward(predict, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(predict.signature, inputs),
         {:ok, prompt} <- build_prompt(predict, inputs),
         {:ok, response} <- generate_with_retries(prompt, predict.max_retries),
         {:ok, outputs} <- parse_response(predict, response) do
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

  defp build_prompt(predict, inputs) do
    prompt_template = Dspy.Signature.to_prompt(predict.signature, predict.examples)

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

  defp parse_response(predict, response_text) do
    outputs = Dspy.Signature.parse_outputs(predict.signature, response_text)
    {:ok, outputs}
  end
end
