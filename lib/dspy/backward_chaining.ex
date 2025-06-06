defmodule Dspy.BackwardChaining do
  @moduledoc """
  Backward chaining reasoning module.

  This module implements goal-driven reasoning where the system starts with
  the desired conclusion and works backwards to identify the premises,
  conditions, or steps needed to achieve that goal. This mirrors how expert
  problem solvers approach complex challenges by reasoning from goals to means.
  """

  use Dspy.Module

  defstruct [
    :signature,
    :examples,
    :max_retries,
    :max_chain_depth,
    :goal_refinement,
    :premise_validation,
    :alternative_paths,
    :constraint_checking,
    :evidence_requirements
  ]

  @type reasoning_step :: %{
          id: String.t(),
          goal: String.t(),
          required_premises: [String.t()],
          conditions: [String.t()],
          confidence: float(),
          depth: non_neg_integer(),
          parent_id: String.t() | nil,
          validation_status: atom(),
          evidence_strength: float()
        }

  @type chain_result :: %{
          goal_achieved: boolean(),
          reasoning_chain: [reasoning_step()],
          unresolved_premises: [String.t()],
          confidence_score: float(),
          alternative_paths: [[reasoning_step()]]
        }

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          max_chain_depth: pos_integer(),
          goal_refinement: boolean(),
          premise_validation: boolean(),
          alternative_paths: boolean(),
          constraint_checking: boolean(),
          evidence_requirements: [String.t()]
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)

    %__MODULE__{
      signature: base_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      max_chain_depth: Keyword.get(opts, :max_chain_depth, 6),
      goal_refinement: Keyword.get(opts, :goal_refinement, true),
      premise_validation: Keyword.get(opts, :premise_validation, true),
      alternative_paths: Keyword.get(opts, :alternative_paths, true),
      constraint_checking: Keyword.get(opts, :constraint_checking, true),
      evidence_requirements: Keyword.get(opts, :evidence_requirements, [])
    }
  end

  @impl true
  def forward(chainer, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(chainer.signature, inputs),
         {:ok, goal_specification} <- extract_goal_specification(chainer, inputs),
         {:ok, chain_result} <- build_backward_chain(chainer, inputs, goal_specification),
         {:ok, validated_chain} <- validate_reasoning_chain(chainer, chain_result),
         {:ok, final_solution} <- synthesize_solution(chainer, inputs, validated_chain) do
      prediction = Dspy.Prediction.new(final_solution)
      {:ok, prediction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_signature(signature) when is_atom(signature) do
    signature.signature()
  end

  defp get_signature(signature), do: signature

  defp extract_goal_specification(chainer, inputs) do
    goal_signature = create_goal_specification_signature(chainer.signature)

    with {:ok, prompt} <- build_prompt(goal_signature, inputs, chainer.examples),
         {:ok, response} <- generate_with_retries(prompt, chainer.max_retries),
         {:ok, goal_spec} <- parse_response(goal_signature, response) do
      refined_goal = %{
        primary_goal: Map.get(goal_spec, :primary_goal, ""),
        success_criteria: parse_criteria_list(Map.get(goal_spec, :success_criteria, "")),
        constraints: parse_constraints_list(Map.get(goal_spec, :constraints, "")),
        context: Map.get(goal_spec, :goal_context, ""),
        measurability: Map.get(goal_spec, :measurability_score, 0.5)
      }

      {:ok, refined_goal}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_backward_chain(chainer, inputs, goal_specification) do
    initial_step = create_initial_reasoning_step(goal_specification)

    case build_chain_recursively(chainer, inputs, initial_step, [initial_step], 0) do
      {:ok, complete_chain} ->
        chain_result = %{
          goal_achieved: true,
          reasoning_chain: complete_chain,
          unresolved_premises: find_unresolved_premises(complete_chain),
          confidence_score: calculate_chain_confidence(complete_chain),
          alternative_paths: []
        }

        if chainer.alternative_paths do
          {:ok, enhanced_result} =
            explore_alternative_paths(chainer, inputs, goal_specification, chain_result)

          {:ok, enhanced_result}
        else
          {:ok, chain_result}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_chain_recursively(chainer, _inputs, _current_step, chain, depth)
       when depth >= chainer.max_chain_depth do
    # Max depth reached, return current chain
    {:ok, Enum.reverse(chain)}
  end

  defp build_chain_recursively(chainer, inputs, current_step, chain, depth) do
    if all_premises_satisfied?(current_step) do
      # Goal achieved, return complete chain
      {:ok, Enum.reverse(chain)}
    else
      # Need to work backwards to satisfy premises
      case generate_backward_step(chainer, inputs, current_step, depth) do
        {:ok, backward_steps} ->
          # Continue chaining with the most promising step
          best_step = select_best_backward_step(backward_steps)
          updated_chain = [best_step | chain]
          build_chain_recursively(chainer, inputs, best_step, updated_chain, depth + 1)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp generate_backward_step(chainer, inputs, current_step, depth) do
    backward_signature = create_backward_reasoning_signature(chainer.signature)

    backward_inputs =
      inputs
      |> Map.put(:current_goal, current_step.goal)
      |> Map.put(:required_premises, format_premises_list(current_step.required_premises))
      |> Map.put(:current_conditions, format_conditions_list(current_step.conditions))
      |> Map.put(:reasoning_depth, depth)

    with {:ok, prompt} <- build_prompt(backward_signature, backward_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, chainer.max_retries),
         {:ok, backward_result} <- parse_response(backward_signature, response) do
      # Create reasoning steps for each premise that needs to be established
      premises_to_establish = parse_premises_list(Map.get(backward_result, :premises_needed, ""))

      backward_steps =
        premises_to_establish
        |> Enum.with_index()
        |> Enum.map(fn {premise, index} ->
          %{
            id: generate_step_id(current_step.id, depth, index),
            goal: premise,
            required_premises: parse_premises_list(Map.get(backward_result, :sub_premises, "")),
            conditions: parse_conditions_list(Map.get(backward_result, :required_conditions, "")),
            confidence: calculate_step_confidence(backward_result, premise),
            depth: depth + 1,
            parent_id: current_step.id,
            validation_status: :pending,
            evidence_strength: estimate_evidence_strength(premise)
          }
        end)

      {:ok, backward_steps}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp explore_alternative_paths(chainer, inputs, goal_specification, base_result) do
    # Generate alternative reasoning paths
    alternative_signature = create_alternative_path_signature(chainer.signature)

    alt_inputs =
      inputs
      |> Map.put(:primary_goal, goal_specification.primary_goal)
      |> Map.put(:existing_approach, summarize_reasoning_chain(base_result.reasoning_chain))

    with {:ok, prompt} <- build_prompt(alternative_signature, alt_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, chainer.max_retries),
         {:ok, alternatives} <- parse_response(alternative_signature, response) do
      alternative_approaches =
        parse_approaches_list(Map.get(alternatives, :alternative_approaches, ""))

      # Build chains for each alternative approach
      alternative_chains =
        alternative_approaches
        # Limit to 3 alternatives
        |> Enum.take(3)
        |> Enum.map(fn approach ->
          alt_goal = %{goal_specification | primary_goal: approach}

          case build_backward_chain_simple(chainer, inputs, alt_goal) do
            {:ok, alt_chain} -> alt_chain.reasoning_chain
            _ -> []
          end
        end)
        |> Enum.reject(&(length(&1) == 0))

      enhanced_result = %{base_result | alternative_paths: alternative_chains}
      {:ok, enhanced_result}
    else
      {:error, _} ->
        # If alternative exploration fails, return original result
        {:ok, base_result}
    end
  end

  defp build_backward_chain_simple(chainer, inputs, goal_specification) do
    # Simplified version for alternative path exploration
    initial_step = create_initial_reasoning_step(goal_specification)

    case build_chain_recursively(chainer, inputs, initial_step, [initial_step], 0) do
      {:ok, chain} ->
        result = %{
          goal_achieved: true,
          reasoning_chain: chain,
          unresolved_premises: [],
          confidence_score: calculate_chain_confidence(chain),
          alternative_paths: []
        }

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_reasoning_chain(chainer, chain_result) do
    if chainer.premise_validation do
      validated_steps =
        chain_result.reasoning_chain
        |> Enum.map(fn step ->
          validation_status = validate_single_step(chainer, step)
          %{step | validation_status: validation_status}
        end)

      validated_result = %{chain_result | reasoning_chain: validated_steps}
      {:ok, validated_result}
    else
      {:ok, chain_result}
    end
  end

  defp validate_single_step(_chainer, step) do
    # Simple validation based on confidence and evidence strength
    if step.confidence > 0.6 and step.evidence_strength > 0.5 do
      :validated
    else
      :needs_verification
    end
  end

  defp synthesize_solution(chainer, inputs, validated_chain) do
    synthesis_signature = create_synthesis_signature(chainer.signature)

    chain_summary = summarize_reasoning_chain(validated_chain.reasoning_chain)
    confidence_assessment = assess_overall_confidence(validated_chain)

    synthesis_inputs =
      inputs
      |> Map.put(:reasoning_chain_summary, chain_summary)
      |> Map.put(:confidence_assessment, confidence_assessment)
      |> Map.put(:unresolved_premises, format_premises_list(validated_chain.unresolved_premises))
      |> Map.put(:alternative_paths_count, length(validated_chain.alternative_paths))

    with {:ok, prompt} <- build_prompt(synthesis_signature, synthesis_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, chainer.max_retries),
         {:ok, solution} <- parse_response(synthesis_signature, response) do
      enhanced_solution =
        solution
        |> Map.put(:backward_chain_summary, chain_summary)
        |> Map.put(:reasoning_confidence, validated_chain.confidence_score)
        |> Map.put(:goal_achievement_status, validated_chain.goal_achieved)

      {:ok, enhanced_solution}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper functions

  defp create_initial_reasoning_step(goal_specification) do
    %{
      id: "goal_0",
      goal: goal_specification.primary_goal,
      required_premises: [],
      conditions: goal_specification.constraints,
      confidence: 1.0,
      depth: 0,
      parent_id: nil,
      validation_status: :pending,
      evidence_strength: 0.0
    }
  end

  defp all_premises_satisfied?(step) do
    length(step.required_premises) == 0
  end

  defp select_best_backward_step(backward_steps) do
    case backward_steps do
      [] -> nil
      steps -> Enum.max_by(steps, fn step -> step.confidence * step.evidence_strength end)
    end
  end

  defp calculate_step_confidence(backward_result, premise) do
    # Base confidence from the backward reasoning quality
    base_confidence = 0.7

    # Adjust based on premise clarity and specificity
    premise_length = String.length(premise)
    clarity_bonus = min(premise_length / 100.0, 0.2)

    # Check for uncertainty indicators
    uncertainty_words = ["might", "possibly", "unclear", "uncertain"]
    reasoning_text = Map.get(backward_result, :reasoning_explanation, "")

    uncertainty_penalty =
      uncertainty_words
      |> Enum.count(fn word -> String.contains?(String.downcase(reasoning_text), word) end)
      |> Kernel.*(0.05)

    result = base_confidence + clarity_bonus - uncertainty_penalty
    max(0.1, min(1.0, result))
  end

  defp estimate_evidence_strength(premise) do
    # Estimate based on premise characteristics
    base_strength = 0.5

    # Stronger evidence for specific, measurable statements
    specific_indicators = ["data", "research", "study", "evidence", "proven"]

    specificity_bonus =
      specific_indicators
      |> Enum.count(fn indicator -> String.contains?(String.downcase(premise), indicator) end)
      |> Kernel.*(0.1)

    result = base_strength + specificity_bonus
    max(0.1, min(1.0, result))
  end

  defp find_unresolved_premises(reasoning_chain) do
    reasoning_chain
    |> Enum.flat_map(& &1.required_premises)
    |> Enum.uniq()
    |> Enum.filter(fn premise ->
      # Check if this premise is addressed by any step in the chain
      not Enum.any?(reasoning_chain, fn step -> step.goal == premise end)
    end)
  end

  defp calculate_chain_confidence(reasoning_chain) do
    if length(reasoning_chain) == 0 do
      0.0
    else
      # Weighted average with more weight on later (more fundamental) steps
      weighted_sum =
        reasoning_chain
        |> Enum.with_index()
        |> Enum.map(fn {step, index} ->
          # Later steps get more weight
          weight = 1.0 + index * 0.1
          step.confidence * weight
        end)
        |> Enum.sum()

      total_weight =
        reasoning_chain
        |> Enum.with_index()
        |> Enum.map(fn {_, index} -> 1.0 + index * 0.1 end)
        |> Enum.sum()

      weighted_sum / total_weight
    end
  end

  defp summarize_reasoning_chain(reasoning_chain) do
    reasoning_chain
    |> Enum.with_index(1)
    |> Enum.map(fn {step, index} ->
      "Step #{index}: #{step.goal} (confidence: #{Float.round(step.confidence, 2)})"
    end)
    |> Enum.join("\n")
  end

  defp assess_overall_confidence(validated_chain) do
    confidence = validated_chain.confidence_score
    unresolved_count = length(validated_chain.unresolved_premises)

    cond do
      confidence > 0.8 and unresolved_count == 0 -> "High confidence"
      confidence > 0.6 and unresolved_count <= 2 -> "Moderate confidence"
      confidence > 0.4 -> "Low confidence"
      true -> "Very low confidence"
    end
  end

  defp generate_step_id(parent_id, depth, index) do
    "#{parent_id}_d#{depth}_#{index}"
  end

  # Parsing helper functions

  defp parse_criteria_list(criteria_text) do
    parse_list(criteria_text)
  end

  defp parse_constraints_list(constraints_text) do
    parse_list(constraints_text)
  end

  defp parse_premises_list(premises_text) do
    parse_list(premises_text)
  end

  defp parse_conditions_list(conditions_text) do
    parse_list(conditions_text)
  end

  defp parse_approaches_list(approaches_text) do
    parse_list(approaches_text)
  end

  defp parse_list(text) do
    if is_binary(text) and String.trim(text) != "" do
      text
      |> String.split(~r/[,;.\n]/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    else
      []
    end
  end

  defp format_premises_list(premises) do
    Enum.join(premises, ", ")
  end

  defp format_conditions_list(conditions) do
    Enum.join(conditions, ", ")
  end

  # Signature creation functions

  defp create_goal_specification_signature(base_signature) do
    output_fields = [
      %{
        name: :primary_goal,
        type: :string,
        description: "Clear statement of the primary goal",
        required: true,
        default: nil
      },
      %{
        name: :success_criteria,
        type: :string,
        description: "Criteria for success (comma-separated)",
        required: true,
        default: nil
      },
      %{
        name: :constraints,
        type: :string,
        description: "Constraints and limitations (comma-separated)",
        required: false,
        default: nil
      },
      %{
        name: :goal_context,
        type: :string,
        description: "Context and background for the goal",
        required: false,
        default: nil
      },
      %{
        name: :measurability_score,
        type: :number,
        description: "How measurable is this goal (0-1)",
        required: false,
        default: nil
      }
    ]

    instructions = """
    Clearly define the goal that needs to be achieved through backward reasoning.
    Specify what success looks like and any constraints that must be considered.
    Make the goal as specific and measurable as possible.
    """

    %{base_signature | output_fields: output_fields, instructions: instructions}
  end

  defp create_backward_reasoning_signature(base_signature) do
    input_fields = [
      %{
        name: :current_goal,
        type: :string,
        description: "The goal to work backwards from",
        required: true,
        default: nil
      },
      %{
        name: :required_premises,
        type: :string,
        description: "Currently required premises",
        required: false,
        default: nil
      },
      %{
        name: :current_conditions,
        type: :string,
        description: "Current conditions and constraints",
        required: false,
        default: nil
      },
      %{
        name: :reasoning_depth,
        type: :integer,
        description: "Current depth in backward chain",
        required: true,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :premises_needed,
        type: :string,
        description: "Premises needed to achieve the goal (comma-separated)",
        required: true,
        default: nil
      },
      %{
        name: :sub_premises,
        type: :string,
        description: "Sub-premises for each main premise (comma-separated)",
        required: false,
        default: nil
      },
      %{
        name: :required_conditions,
        type: :string,
        description: "Conditions that must be met (comma-separated)",
        required: false,
        default: nil
      },
      %{
        name: :reasoning_explanation,
        type: :string,
        description: "Explanation of the backward reasoning",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Work backwards from the given goal to identify what premises, conditions, or steps
    are needed to achieve it. Think about what must be true or what must be done
    in order for the goal to be accomplished.
    """

    %{
      base_signature
      | input_fields: input_fields ++ base_signature.input_fields,
        output_fields: output_fields,
        instructions: instructions
    }
  end

  defp create_alternative_path_signature(base_signature) do
    input_fields = [
      %{
        name: :primary_goal,
        type: :string,
        description: "The main goal to achieve",
        required: true,
        default: nil
      },
      %{
        name: :existing_approach,
        type: :string,
        description: "Summary of existing reasoning approach",
        required: true,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :alternative_approaches,
        type: :string,
        description: "Alternative approaches to achieve the goal (comma-separated)",
        required: true,
        default: nil
      },
      %{
        name: :approach_comparison,
        type: :string,
        description: "Comparison of different approaches",
        required: false,
        default: nil
      }
    ]

    instructions = """
    Identify alternative ways to achieve the same goal.
    Think of different strategies, methods, or reasoning paths that could lead
    to the same outcome. Consider various perspectives and approaches.
    """

    %{
      base_signature
      | input_fields: input_fields ++ base_signature.input_fields,
        output_fields: output_fields,
        instructions: instructions
    }
  end

  defp create_synthesis_signature(base_signature) do
    input_fields = [
      %{
        name: :reasoning_chain_summary,
        type: :string,
        description: "Summary of backward reasoning chain",
        required: true,
        default: nil
      },
      %{
        name: :confidence_assessment,
        type: :string,
        description: "Overall confidence assessment",
        required: true,
        default: nil
      },
      %{
        name: :unresolved_premises,
        type: :string,
        description: "Any unresolved premises",
        required: false,
        default: nil
      },
      %{
        name: :alternative_paths_count,
        type: :integer,
        description: "Number of alternative paths explored",
        required: false,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :goal_achievement_strategy,
        type: :string,
        description: "Strategy for achieving the goal",
        required: true,
        default: nil
      }
      | base_signature.output_fields
    ]

    instructions = """
    Synthesize the backward reasoning chain into a clear strategy for achieving the goal.
    Address any unresolved premises and provide a comprehensive approach based on
    the backward chaining analysis.
    """

    %{
      base_signature
      | input_fields: input_fields ++ base_signature.input_fields,
        output_fields: output_fields,
        instructions: instructions
    }
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
end
