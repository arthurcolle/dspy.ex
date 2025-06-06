defmodule Dspy.MultiStep do
  @moduledoc """
  Multi-Step reasoning module.

  Breaks down complex problems into multiple sequential steps,
  where each step builds on the previous ones. This allows for
  more structured problem-solving for complex tasks.
  """

  use Dspy.Module

  defstruct [:steps, :examples, :max_retries]

  @type step :: %{
          name: atom(),
          signature: Dspy.Signature.t(),
          description: String.t(),
          depends_on: [atom()]
        }

  @type t :: %__MODULE__{
          steps: [step()],
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer()
        }

  def new(steps, opts \\ []) do
    %__MODULE__{
      steps: steps,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3)
    }
  end

  @impl true
  def forward(multi_step, inputs) do
    case execute_steps(multi_step.steps, inputs, %{}, multi_step) do
      {:ok, final_outputs} ->
        prediction = Dspy.Prediction.new(final_outputs)
        {:ok, prediction}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_steps([], _inputs, accumulated_outputs, _multi_step) do
    {:ok, accumulated_outputs}
  end

  defp execute_steps([step | remaining_steps], original_inputs, accumulated_outputs, multi_step) do
    with {:ok, step_inputs} <- prepare_step_inputs(step, original_inputs, accumulated_outputs),
         {:ok, step_outputs} <- execute_single_step(step, step_inputs, multi_step) do
      new_accumulated = Map.merge(accumulated_outputs, step_outputs)
      execute_steps(remaining_steps, original_inputs, new_accumulated, multi_step)
    else
      {:error, reason} -> {:error, {:step_failed, step.name, reason}}
    end
  end

  defp prepare_step_inputs(step, original_inputs, accumulated_outputs) do
    step_inputs =
      step.depends_on
      |> Enum.reduce(original_inputs, fn dependency, acc ->
        case Map.get(accumulated_outputs, dependency) do
          nil -> acc
          value -> Map.put(acc, dependency, value)
        end
      end)

    {:ok, step_inputs}
  end

  defp execute_single_step(step, inputs, multi_step) do
    enhanced_signature = add_step_context(step.signature, step.description)

    with {:ok, prompt} <- build_step_prompt(enhanced_signature, inputs, multi_step.examples),
         {:ok, response} <- generate_with_retries(prompt, multi_step.max_retries),
         {:ok, outputs} <- parse_step_response(enhanced_signature, response) do
      step_outputs =
        Map.put(outputs, step.name, Map.get(outputs, get_primary_output_field(step.signature)))

      {:ok, step_outputs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp add_step_context(signature, description) do
    step_instructions = """
    Step: #{description}

    Complete this step carefully, using any previously computed information as context.
    """

    existing_instructions = signature.instructions || ""

    combined_instructions =
      [existing_instructions, step_instructions]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    %{signature | instructions: combined_instructions}
  end

  defp build_step_prompt(signature, inputs, examples) do
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

  defp parse_step_response(signature, response_text) do
    outputs = Dspy.Signature.parse_outputs(signature, response_text)
    {:ok, outputs}
  end

  defp get_primary_output_field(signature) do
    signature.output_fields
    |> List.first()
    |> Map.get(:name)
  end
end
