defmodule Dspy.AdaptiveBacktracking do
  @moduledoc """
  Advanced reflection with intelligent backtracking capabilities.

  This module combines reflection with sophisticated backtracking strategies:
  - Confidence-based backtracking
  - Constraint violation detection
  - Multi-path exploration with memory
  - Adaptive depth control based on problem complexity
  """

  use Dspy.Module

  defstruct [
    :signature,
    :examples,
    :max_retries,
    :confidence_threshold,
    :max_backtrack_depth,
    :constraint_functions,
    :exploration_strategy,
    :memory_enabled,
    :adaptive_depth
  ]

  @type reasoning_step :: %{
          id: String.t(),
          content: String.t(),
          confidence: float(),
          constraints_satisfied: boolean(),
          parent_id: String.t() | nil,
          depth: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @type reasoning_memory :: %{
          successful_paths: [reasoning_step()],
          failed_attempts: [reasoning_step()],
          constraint_violations: [%{step_id: String.t(), constraint: String.t()}],
          confidence_history: [{String.t(), float()}]
        }

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          confidence_threshold: float(),
          max_backtrack_depth: pos_integer(),
          constraint_functions: [function()],
          exploration_strategy: atom(),
          memory_enabled: boolean(),
          adaptive_depth: boolean()
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)

    %__MODULE__{
      signature: base_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      confidence_threshold: Keyword.get(opts, :confidence_threshold, 0.7),
      max_backtrack_depth: Keyword.get(opts, :max_backtrack_depth, 5),
      constraint_functions: Keyword.get(opts, :constraint_functions, []),
      exploration_strategy: Keyword.get(opts, :exploration_strategy, :adaptive),
      memory_enabled: Keyword.get(opts, :memory_enabled, true),
      adaptive_depth: Keyword.get(opts, :adaptive_depth, true)
    }
  end

  @impl true
  def forward(module, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(module.signature, inputs),
         {:ok, initial_memory} <- initialize_memory(module),
         {:ok, reasoning_tree} <- explore_with_backtracking(module, inputs, initial_memory),
         {:ok, best_path} <- select_optimal_path(reasoning_tree),
         {:ok, final_answer} <- synthesize_final_answer(module, inputs, best_path) do
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

  defp initialize_memory(%{memory_enabled: false}), do: {:ok, nil}

  defp initialize_memory(_module) do
    memory = %{
      successful_paths: [],
      failed_attempts: [],
      constraint_violations: [],
      confidence_history: []
    }

    {:ok, memory}
  end

  defp explore_with_backtracking(module, inputs, memory) do
    case module.exploration_strategy do
      :adaptive -> adaptive_exploration(module, inputs, memory)
      :breadth_first -> breadth_first_exploration(module, inputs, memory)
      :depth_first -> depth_first_exploration(module, inputs, memory)
      _ -> adaptive_exploration(module, inputs, memory)
    end
  end

  defp adaptive_exploration(module, inputs, memory) do
    # Start with initial reasoning step
    with {:ok, initial_step} <- generate_initial_reasoning(module, inputs),
         {:ok, evaluated_step} <- evaluate_reasoning_step(module, initial_step, inputs) do
      if should_continue_reasoning?(module, evaluated_step, memory) do
        explore_branch_adaptively(module, inputs, evaluated_step, memory, 1)
      else
        {:ok, [evaluated_step]}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp explore_branch_adaptively(module, _inputs, current_step, memory, depth)
       when depth >= module.max_backtrack_depth do
    # Max depth reached, finalize current path
    {:ok, reconstruct_path(memory, current_step)}
  end

  defp explore_branch_adaptively(module, inputs, current_step, memory, depth) do
    # Check if we should backtrack based on confidence and constraints
    case should_backtrack?(module, current_step, memory) do
      {:backtrack, reason} ->
        backtrack_and_explore_alternative(module, inputs, current_step, memory, depth, reason)

      :continue ->
        case generate_next_reasoning_step(module, inputs, current_step, depth) do
          {:ok, next_step} ->
            {:ok, step} = evaluate_reasoning_step(module, next_step, inputs)
            updated_memory = update_memory(memory, step, :successful)
            explore_branch_adaptively(module, inputs, step, updated_memory, depth + 1)

          {:error, reason} ->
            backtrack_and_explore_alternative(module, inputs, current_step, memory, depth, reason)
        end

      :terminate ->
        {:ok, reconstruct_path(memory, current_step)}
    end
  end

  defp should_backtrack?(module, step, memory) do
    cond do
      step.confidence < module.confidence_threshold ->
        {:backtrack, :low_confidence}

      not step.constraints_satisfied ->
        {:backtrack, :constraint_violation}

      is_similar_to_failed_attempt?(step, memory) ->
        {:backtrack, :similar_to_failure}

      step.confidence > 0.9 and step.constraints_satisfied ->
        :terminate

      true ->
        :continue
    end
  end

  defp backtrack_and_explore_alternative(module, inputs, current_step, memory, depth, reason) do
    # Find alternative path from a previous step
    case find_backtrack_point(memory, current_step, reason) do
      {:ok, backtrack_step} ->
        # Generate alternative reasoning from backtrack point
        case generate_alternative_reasoning(module, inputs, backtrack_step, reason) do
          {:ok, alternative_step} ->
            {:ok, step} = evaluate_reasoning_step(module, alternative_step, inputs)

            updated_memory =
              memory
              |> update_memory(current_step, :failed)
              |> update_memory(step, :alternative)

            explore_branch_adaptively(module, inputs, step, updated_memory, depth)

          {:error, _} ->
            {:ok, reconstruct_path(memory, current_step)}
        end

      {:error, _} ->
        # No suitable backtrack point, return current path
        {:ok, reconstruct_path(memory, current_step)}
    end
  end

  defp generate_initial_reasoning(module, inputs) do
    reasoning_signature = create_reasoning_signature(module.signature, :initial)

    with {:ok, prompt} <- build_reasoning_prompt(reasoning_signature, inputs, module.examples),
         {:ok, response} <- generate_with_retries(prompt, module.max_retries),
         {:ok, parsed} <- parse_reasoning_response(reasoning_signature, response) do
      step = %{
        id: generate_step_id(),
        content: Map.get(parsed, :reasoning, ""),
        # Will be evaluated separately
        confidence: 0.5,
        # Will be evaluated separately
        constraints_satisfied: true,
        parent_id: nil,
        depth: 0,
        timestamp: DateTime.utc_now()
      }

      {:ok, step}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_next_reasoning_step(module, inputs, parent_step, depth) do
    reasoning_signature = create_reasoning_signature(module.signature, :continuation)

    enhanced_inputs =
      inputs
      |> Map.put(:previous_reasoning, parent_step.content)
      |> Map.put(:depth, depth)

    with {:ok, prompt} <- build_reasoning_prompt(reasoning_signature, enhanced_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, module.max_retries),
         {:ok, parsed} <- parse_reasoning_response(reasoning_signature, response) do
      step = %{
        id: generate_step_id(),
        content: Map.get(parsed, :reasoning, ""),
        confidence: 0.5,
        constraints_satisfied: true,
        parent_id: parent_step.id,
        depth: depth,
        timestamp: DateTime.utc_now()
      }

      {:ok, step}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_alternative_reasoning(module, inputs, backtrack_step, reason) do
    reasoning_signature = create_reasoning_signature(module.signature, :alternative)

    enhanced_inputs =
      inputs
      |> Map.put(:previous_reasoning, backtrack_step.content)
      |> Map.put(:backtrack_reason, reason_to_string(reason))
      |> Map.put(:depth, backtrack_step.depth + 1)

    with {:ok, prompt} <- build_reasoning_prompt(reasoning_signature, enhanced_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, module.max_retries),
         {:ok, parsed} <- parse_reasoning_response(reasoning_signature, response) do
      step = %{
        id: generate_step_id(),
        content: Map.get(parsed, :reasoning, ""),
        confidence: 0.5,
        constraints_satisfied: true,
        parent_id: backtrack_step.id,
        depth: backtrack_step.depth + 1,
        timestamp: DateTime.utc_now()
      }

      {:ok, step}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp evaluate_reasoning_step(module, step, inputs) do
    # Evaluate confidence
    confidence = calculate_confidence(step.content, inputs)

    # Check constraints
    constraints_satisfied = check_constraints(module, step, inputs)

    updated_step = %{
      step
      | confidence: confidence,
        constraints_satisfied: constraints_satisfied
    }

    {:ok, updated_step}
  end

  defp calculate_confidence(reasoning_content, _inputs) do
    # Simple heuristic-based confidence calculation
    base_confidence = 0.5

    # Longer reasoning tends to be more confident (up to a point)
    length_factor = min(String.length(reasoning_content) / 500.0, 0.3)

    # Presence of uncertainty words reduces confidence
    uncertainty_words = ["maybe", "possibly", "might", "could", "perhaps", "unsure"]

    uncertainty_penalty =
      uncertainty_words
      |> Enum.count(fn word -> String.contains?(String.downcase(reasoning_content), word) end)
      |> Kernel.*(0.1)

    # Presence of confidence words increases confidence
    confidence_words = ["definitely", "certainly", "clearly", "obviously", "sure"]

    confidence_bonus =
      confidence_words
      |> Enum.count(fn word -> String.contains?(String.downcase(reasoning_content), word) end)
      |> Kernel.*(0.05)

    result = base_confidence + length_factor + confidence_bonus - uncertainty_penalty
    max(0.0, min(1.0, result))
  end

  defp check_constraints(module, step, inputs) do
    module.constraint_functions
    |> Enum.all?(fn constraint_fn ->
      try do
        constraint_fn.(step, inputs)
      rescue
        _ -> false
      end
    end)
  end

  defp should_continue_reasoning?(_module, step, _memory) do
    # Continue if confidence is not extremely high and constraints are satisfied
    step.confidence < 0.95 and step.constraints_satisfied
  end

  defp find_backtrack_point(memory, _current_step, _reason) do
    # Simple strategy: backtrack to the most recent successful step
    case memory.successful_paths do
      [] -> {:error, :no_backtrack_point}
      [latest | _] -> {:ok, latest}
    end
  end

  defp is_similar_to_failed_attempt?(step, memory) do
    memory.failed_attempts
    |> Enum.any?(fn failed_step ->
      similarity = calculate_similarity(step.content, failed_step.content)
      similarity > 0.8
    end)
  end

  defp calculate_similarity(text1, text2) do
    # Simple word-based similarity
    words1 = String.split(String.downcase(text1))
    words2 = String.split(String.downcase(text2))

    common_words = MapSet.intersection(MapSet.new(words1), MapSet.new(words2))
    total_words = MapSet.union(MapSet.new(words1), MapSet.new(words2))

    case MapSet.size(total_words) do
      0 -> 0.0
      size -> MapSet.size(common_words) / size
    end
  end

  defp update_memory(nil, _step, _type), do: nil

  defp update_memory(memory, step, type) do
    case type do
      :successful ->
        %{memory | successful_paths: [step | memory.successful_paths]}

      :failed ->
        %{memory | failed_attempts: [step | memory.failed_attempts]}

      :alternative ->
        %{memory | successful_paths: [step | memory.successful_paths]}
    end
  end

  defp reconstruct_path(_memory, final_step) do
    # For now, just return the final step as a single-element path
    # In a full implementation, would reconstruct the full reasoning path
    [final_step]
  end

  defp breadth_first_exploration(_module, _inputs, _memory) do
    # Placeholder for breadth-first exploration strategy
    {:error, :not_implemented}
  end

  defp depth_first_exploration(_module, _inputs, _memory) do
    # Placeholder for depth-first exploration strategy
    {:error, :not_implemented}
  end

  defp select_optimal_path(reasoning_tree) do
    case reasoning_tree do
      [] ->
        {:error, :no_reasoning_path}

      steps ->
        # Select the step with highest confidence
        best_step = Enum.max_by(steps, & &1.confidence)
        {:ok, [best_step]}
    end
  end

  defp synthesize_final_answer(module, inputs, reasoning_path) do
    synthesis_signature = create_synthesis_signature(module.signature)

    path_summary = summarize_reasoning_path(reasoning_path)

    synthesis_inputs =
      inputs
      |> Map.put(:reasoning_path, path_summary)

    with {:ok, prompt} <- build_reasoning_prompt(synthesis_signature, synthesis_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, module.max_retries),
         {:ok, outputs} <- parse_reasoning_response(synthesis_signature, response) do
      {:ok, outputs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_reasoning_signature(base_signature, type) do
    {input_fields, output_fields, instructions} =
      signature_components_for_type(type, base_signature)

    %{
      base_signature
      | input_fields: base_signature.input_fields ++ input_fields,
        output_fields: base_signature.output_fields ++ output_fields,
        instructions: instructions
    }
  end

  defp signature_components_for_type(:initial, _base) do
    input_fields = []

    output_fields = [
      %{
        name: :reasoning,
        type: :string,
        description: "Initial reasoning step",
        required: true,
        default: nil
      },
      %{
        name: :confidence_self_assessment,
        type: :string,
        description: "Self-assessment of confidence",
        required: false,
        default: nil
      }
    ]

    instructions =
      "Begin reasoning about this problem step by step. Provide your initial thoughts and approach."

    {input_fields, output_fields, instructions}
  end

  defp signature_components_for_type(:continuation, _base) do
    input_fields = [
      %{
        name: :previous_reasoning,
        type: :string,
        description: "Previous reasoning step",
        required: true,
        default: nil
      },
      %{
        name: :depth,
        type: :integer,
        description: "Current reasoning depth",
        required: true,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :reasoning,
        type: :string,
        description: "Next reasoning step",
        required: true,
        default: nil
      }
    ]

    instructions =
      "Continue the reasoning process from the previous step. Build upon previous insights."

    {input_fields, output_fields, instructions}
  end

  defp signature_components_for_type(:alternative, _base) do
    input_fields = [
      %{
        name: :previous_reasoning,
        type: :string,
        description: "Previous reasoning that needs alternative",
        required: true,
        default: nil
      },
      %{
        name: :backtrack_reason,
        type: :string,
        description: "Reason for backtracking",
        required: true,
        default: nil
      },
      %{
        name: :depth,
        type: :integer,
        description: "Current reasoning depth",
        required: true,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :reasoning,
        type: :string,
        description: "Alternative reasoning approach",
        required: true,
        default: nil
      }
    ]

    instructions =
      "Provide an alternative reasoning approach due to issues with the previous path."

    {input_fields, output_fields, instructions}
  end

  defp create_synthesis_signature(base_signature) do
    input_fields = [
      %{
        name: :reasoning_path,
        type: :string,
        description: "Summary of reasoning path",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Based on the reasoning path provided, synthesize a final answer.
    Use the insights and conclusions from the reasoning process.
    """

    %{
      base_signature
      | input_fields: input_fields ++ base_signature.input_fields,
        instructions: instructions
    }
  end

  defp summarize_reasoning_path(path) do
    path
    |> Enum.with_index(1)
    |> Enum.map(fn {step, index} ->
      "Step #{index} (confidence: #{Float.round(step.confidence, 2)}): #{step.content}"
    end)
    |> Enum.join("\n")
  end

  defp reason_to_string(:low_confidence), do: "low confidence in reasoning"
  defp reason_to_string(:constraint_violation), do: "constraint violation detected"
  defp reason_to_string(:similar_to_failure), do: "similar to previous failed attempt"
  defp reason_to_string(reason), do: "#{reason}"

  defp generate_step_id do
    "step_#{System.unique_integer([:positive])}_#{:rand.uniform(1000)}"
  end

  defp build_reasoning_prompt(signature, inputs, examples) do
    prompt_template = Dspy.Signature.to_prompt(signature, examples)

    filled_prompt =
      Enum.reduce(inputs, prompt_template, fn {key, value}, acc ->
        placeholder = "[input]"
        field_name = String.capitalize(Atom.to_string(key))
        String.replace(acc, "#{field_name}: #{placeholder}", "#{field_name}: #{value}")
      end)

    # Trim the prompt if it's too long (OpenAI has limits)
    max_prompt_length = 8000
    trimmed_prompt = 
      if String.length(filled_prompt) > max_prompt_length do
        String.slice(filled_prompt, 0, max_prompt_length) <> "..."
      else
        filled_prompt
      end

    {:ok, trimmed_prompt}
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

  defp parse_reasoning_response(signature, response_text) do
    outputs = Dspy.Signature.parse_outputs(signature, response_text)
    {:ok, outputs}
  end
end
