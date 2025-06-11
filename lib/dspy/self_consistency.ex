defmodule Dspy.SelfConsistency do
  @moduledoc """
  Self-Consistency reasoning module.

  Generates multiple reasoning paths and selects the most consistent answer.
  This technique improves accuracy by sampling multiple chain-of-thought
  reasoning paths and choosing the answer that appears most frequently.
  """

  use Dspy.Module

  defstruct [:signature, :examples, :max_retries, :num_samples, :temperature, :reasoning_field]

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          num_samples: pos_integer(),
          temperature: float(),
          reasoning_field: atom()
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)
    reasoning_field = Keyword.get(opts, :reasoning_field, :reasoning)

    augmented_signature = add_reasoning_field(base_signature, reasoning_field)

    %__MODULE__{
      signature: augmented_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      num_samples: Keyword.get(opts, :num_samples, 5),
      temperature: Keyword.get(opts, :temperature, 0.7),
      reasoning_field: reasoning_field
    }
  end

  @impl true
  def forward(sc, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(sc.signature, inputs),
         {:ok, prompt} <- build_prompt(sc, inputs),
         {:ok, samples} <- generate_samples(prompt, sc),
         {:ok, outputs} <- select_consistent_answer(sc, samples) do
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

    new_output_fields = [reasoning_field_def | signature.output_fields]
    %{signature | output_fields: new_output_fields}
  end

  defp build_prompt(sc, inputs) do
    enhanced_signature = add_cot_instructions(sc.signature)
    prompt_template = Dspy.Signature.to_prompt(enhanced_signature, sc.examples)

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

  defp generate_samples(prompt, sc) do
    tasks =
      1..sc.num_samples
      |> Enum.map(fn _i ->
        Task.async(fn ->
          generate_with_retries(prompt, sc.max_retries, sc.temperature)
        end)
      end)

    results = Task.await_many(tasks, 15_000)

    successful_samples =
      results
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, sample} -> sample end)

    case successful_samples do
      [] -> {:error, :no_successful_samples}
      samples -> {:ok, samples}
    end
  end

  defp generate_with_retries(prompt, retries, temperature) do
    case Dspy.LM.generate_text(prompt, temperature: temperature) do
      {:ok, response} ->
        {:ok, response}

      {:error, _reason} when retries > 0 ->
        Process.sleep(1000)
        generate_with_retries(prompt, retries - 1, temperature)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp select_consistent_answer(sc, samples) do
    parsed_samples =
      samples
      |> Enum.map(&Dspy.Signature.parse_outputs(sc.signature, &1))
      |> Enum.reject(&is_nil/1)

    case parsed_samples do
      [] ->
        {:error, :no_valid_samples}

      valid_samples ->
        answer_field = get_answer_field(sc.signature)
        most_common = find_most_common_answer(valid_samples, answer_field)
        {:ok, most_common}
    end
  end

  defp get_answer_field(signature) do
    signature.output_fields
    |> Enum.find(fn field -> field.name != :reasoning end)
    |> Map.get(:name)
  end

  defp find_most_common_answer(samples, answer_field) do
    answer_counts =
      samples
      |> Enum.map(&Map.get(&1, answer_field))
      |> Enum.frequencies()

    {most_common_answer, _count} = Enum.max_by(answer_counts, fn {_answer, count} -> count end)

    best_sample =
      samples
      |> Enum.find(fn sample -> Map.get(sample, answer_field) == most_common_answer end)

    best_sample
  end
end
