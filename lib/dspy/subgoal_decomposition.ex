defmodule Dspy.SubgoalDecomposition do
  @moduledoc """
  Subgoal setting and problem decomposition module.

  This module implements the cognitive behavior of breaking complex problems
  into manageable subgoals and subproblems. It employs hierarchical decomposition
  strategies used by expert problem solvers to tackle complex challenges.
  """

  use Dspy.Module

  defstruct [
    :signature,
    :examples,
    :max_retries,
    :decomposition_strategies,
    :max_depth,
    :min_subgoal_complexity,
    :dependency_tracking,
    :parallel_execution,
    :success_criteria
  ]

  @type subgoal :: %{
          id: String.t(),
          description: String.t(),
          complexity: float(),
          dependencies: [String.t()],
          status: atom(),
          solution: map() | nil,
          parent_id: String.t() | nil,
          depth: non_neg_integer(),
          priority: float(),
          estimated_effort: float()
        }

  @type decomposition_strategy ::
          :hierarchical
          | :functional
          | :temporal
          | :causal
          | :constraint_based
          | :resource_based
          | :abstraction_layers

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          decomposition_strategies: [decomposition_strategy()],
          max_depth: pos_integer(),
          min_subgoal_complexity: float(),
          dependency_tracking: boolean(),
          parallel_execution: boolean(),
          success_criteria: [String.t()]
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)

    %__MODULE__{
      signature: base_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      decomposition_strategies:
        Keyword.get(opts, :decomposition_strategies, [:hierarchical, :functional]),
      max_depth: Keyword.get(opts, :max_depth, 4),
      min_subgoal_complexity: Keyword.get(opts, :min_subgoal_complexity, 0.2),
      dependency_tracking: Keyword.get(opts, :dependency_tracking, true),
      parallel_execution: Keyword.get(opts, :parallel_execution, true),
      success_criteria: Keyword.get(opts, :success_criteria, [])
    }
  end

  @impl true
  def forward(decomposer, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(decomposer.signature, inputs),
         {:ok, problem_analysis} <- analyze_problem_complexity(decomposer, inputs),
         {:ok, subgoal_tree} <- decompose_into_subgoals(decomposer, inputs, problem_analysis),
         {:ok, execution_plan} <- create_execution_plan(decomposer, subgoal_tree),
         {:ok, solved_subgoals} <- execute_subgoals(decomposer, inputs, execution_plan),
         {:ok, final_solution} <- synthesize_final_solution(decomposer, inputs, solved_subgoals) do
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

  defp analyze_problem_complexity(decomposer, inputs) do
    analysis_signature = create_complexity_analysis_signature(decomposer.signature)

    with {:ok, prompt} <- build_prompt(analysis_signature, inputs, decomposer.examples),
         {:ok, response} <- generate_with_retries(prompt, decomposer.max_retries),
         {:ok, analysis} <- parse_response(analysis_signature, response) do
      complexity_metrics = %{
        overall_complexity: Map.get(analysis, :complexity_score, 0.5),
        decomposability: Map.get(analysis, :decomposability_score, 0.5),
        interdependency: Map.get(analysis, :interdependency_level, 0.3),
        domain_specificity: Map.get(analysis, :domain_specificity, 0.5),
        time_sensitivity: Map.get(analysis, :time_sensitivity, 0.3)
      }

      {:ok, Map.merge(analysis, complexity_metrics)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp decompose_into_subgoals(decomposer, inputs, problem_analysis) do
    # Use the most appropriate decomposition strategy based on problem analysis
    strategy = select_decomposition_strategy(decomposer, problem_analysis)

    case strategy do
      :hierarchical -> hierarchical_decomposition(decomposer, inputs, problem_analysis)
      :functional -> functional_decomposition(decomposer, inputs, problem_analysis)
      :temporal -> temporal_decomposition(decomposer, inputs, problem_analysis)
      :causal -> causal_decomposition(decomposer, inputs, problem_analysis)
      :constraint_based -> constraint_based_decomposition(decomposer, inputs, problem_analysis)
      _ -> hierarchical_decomposition(decomposer, inputs, problem_analysis)
    end
  end

  defp select_decomposition_strategy(decomposer, problem_analysis) do
    # Select strategy based on problem characteristics
    complexity = Map.get(problem_analysis, :overall_complexity, 0.5)
    interdependency = Map.get(problem_analysis, :interdependency_level, 0.3)
    time_sensitivity = Map.get(problem_analysis, :time_sensitivity, 0.3)

    cond do
      time_sensitivity > 0.7 -> :temporal
      interdependency > 0.8 -> :causal
      complexity > 0.8 -> :hierarchical
      true -> List.first(decomposer.decomposition_strategies, :hierarchical)
    end
  end

  defp hierarchical_decomposition(decomposer, inputs, _problem_analysis) do
    decompose_recursively(decomposer, inputs, nil, 0, "main_problem")
  end

  defp decompose_recursively(decomposer, _inputs, parent_id, depth, problem_desc)
       when depth >= decomposer.max_depth do
    # Max depth reached, create leaf subgoal
    subgoal = create_leaf_subgoal(problem_desc, parent_id, depth)
    {:ok, [subgoal]}
  end

  defp decompose_recursively(decomposer, inputs, parent_id, depth, problem_desc) do
    decomposition_signature = create_decomposition_signature(decomposer.signature)

    decomposition_inputs =
      inputs
      |> Map.put(:problem_description, problem_desc)
      |> Map.put(:decomposition_depth, depth)
      |> Map.put(:parent_context, parent_id || "root")

    with {:ok, prompt} <- build_prompt(decomposition_signature, decomposition_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, decomposer.max_retries),
         {:ok, decomposition_result} <- parse_response(decomposition_signature, response) do
      subgoals_descriptions = parse_subgoals_list(Map.get(decomposition_result, :subgoals, ""))

      if should_further_decompose?(decomposer, subgoals_descriptions, depth) do
        # Create subgoals and recursively decompose them
        subgoals_with_children =
          subgoals_descriptions
          |> Enum.with_index()
          |> Enum.flat_map(fn {subgoal_desc, index} ->
            subgoal_id = generate_subgoal_id(parent_id, depth, index)

            subgoal = %{
              id: subgoal_id,
              description: subgoal_desc,
              complexity: estimate_subgoal_complexity(subgoal_desc),
              dependencies: [],
              status: :pending,
              solution: nil,
              parent_id: parent_id,
              depth: depth,
              priority: 1.0 / (index + 1),
              estimated_effort: estimate_effort(subgoal_desc)
            }

            case decompose_recursively(decomposer, inputs, subgoal_id, depth + 1, subgoal_desc) do
              {:ok, child_subgoals} -> [subgoal | child_subgoals]
              _ -> [subgoal]
            end
          end)

        {:ok, subgoals_with_children}
      else
        # Create leaf subgoals
        leaf_subgoals =
          subgoals_descriptions
          |> Enum.with_index()
          |> Enum.map(fn {subgoal_desc, index} ->
            subgoal_id = generate_subgoal_id(parent_id, depth, index)
            create_leaf_subgoal(subgoal_desc, subgoal_id, depth)
          end)

        {:ok, leaf_subgoals}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp functional_decomposition(decomposer, inputs, _problem_analysis) do
    # Decompose based on functional components
    functional_signature = create_functional_decomposition_signature(decomposer.signature)

    with {:ok, prompt} <- build_prompt(functional_signature, inputs, []),
         {:ok, response} <- generate_with_retries(prompt, decomposer.max_retries),
         {:ok, decomposition} <- parse_response(functional_signature, response) do
      functions = parse_functions_list(Map.get(decomposition, :functional_components, ""))

      functional_subgoals =
        functions
        |> Enum.with_index()
        |> Enum.map(fn {function_desc, index} ->
          %{
            id: "func_#{index}",
            description: function_desc,
            complexity: estimate_subgoal_complexity(function_desc),
            dependencies: extract_dependencies(function_desc, functions),
            status: :pending,
            solution: nil,
            parent_id: nil,
            depth: 1,
            priority: 1.0,
            estimated_effort: estimate_effort(function_desc)
          }
        end)

      {:ok, functional_subgoals}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp temporal_decomposition(decomposer, inputs, _problem_analysis) do
    # Decompose based on temporal sequence
    temporal_signature = create_temporal_decomposition_signature(decomposer.signature)

    with {:ok, prompt} <- build_prompt(temporal_signature, inputs, []),
         {:ok, response} <- generate_with_retries(prompt, decomposer.max_retries),
         {:ok, decomposition} <- parse_response(temporal_signature, response) do
      phases = parse_phases_list(Map.get(decomposition, :temporal_phases, ""))

      temporal_subgoals =
        phases
        |> Enum.with_index()
        |> Enum.map(fn {phase_desc, index} ->
          dependencies = if index > 0, do: ["phase_#{index - 1}"], else: []

          %{
            id: "phase_#{index}",
            description: phase_desc,
            complexity: estimate_subgoal_complexity(phase_desc),
            dependencies: dependencies,
            status: :pending,
            solution: nil,
            parent_id: nil,
            depth: 1,
            priority: (length(phases) - index) * 1.0,
            estimated_effort: estimate_effort(phase_desc)
          }
        end)

      {:ok, temporal_subgoals}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp causal_decomposition(_decomposer, _inputs, _problem_analysis) do
    # Decompose based on causal relationships
    {:ok, [create_leaf_subgoal("Causal decomposition not fully implemented", nil, 1)]}
  end

  defp constraint_based_decomposition(_decomposer, _inputs, _problem_analysis) do
    # Decompose based on constraints
    {:ok, [create_leaf_subgoal("Constraint-based decomposition not fully implemented", nil, 1)]}
  end

  defp create_execution_plan(decomposer, subgoals) do
    if decomposer.dependency_tracking do
      # Create execution plan respecting dependencies
      execution_order = topological_sort(subgoals)
      parallel_groups = group_parallel_subgoals(execution_order, subgoals)

      plan = %{
        execution_order: execution_order,
        parallel_groups: parallel_groups,
        total_subgoals: length(subgoals)
      }

      {:ok, plan}
    else
      # Simple sequential execution
      plan = %{
        execution_order: Enum.map(subgoals, & &1.id),
        parallel_groups: [],
        total_subgoals: length(subgoals)
      }

      {:ok, plan}
    end
  end

  defp execute_subgoals(decomposer, inputs, execution_plan) do
    if decomposer.parallel_execution and length(execution_plan.parallel_groups) > 0 do
      execute_subgoals_parallel(decomposer, inputs, execution_plan)
    else
      execute_subgoals_sequential(decomposer, inputs, execution_plan)
    end
  end

  defp execute_subgoals_sequential(decomposer, inputs, execution_plan) do
    # Execute subgoals one by one
    solved_subgoals =
      execution_plan.execution_order
      |> Enum.reduce([], fn subgoal_id, acc ->
        case solve_single_subgoal(decomposer, inputs, subgoal_id, acc) do
          {:ok, solved_subgoal} -> [solved_subgoal | acc]
          _ -> acc
        end
      end)
      |> Enum.reverse()

    {:ok, solved_subgoals}
  end

  defp execute_subgoals_parallel(decomposer, inputs, execution_plan) do
    # Execute subgoals in parallel groups
    solved_subgoals =
      execution_plan.parallel_groups
      |> Enum.reduce([], fn group, acc ->
        group_tasks =
          group
          |> Enum.map(fn subgoal_id ->
            Task.async(fn ->
              solve_single_subgoal(decomposer, inputs, subgoal_id, acc)
            end)
          end)

        group_results = Task.await_many(group_tasks, 30_000)

        successful_solutions =
          group_results
          |> Enum.filter(fn
            {:ok, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {:ok, solution} -> solution end)

        acc ++ successful_solutions
      end)

    {:ok, solved_subgoals}
  end

  defp solve_single_subgoal(decomposer, inputs, subgoal_id, previous_solutions) do
    subgoal_signature = create_subgoal_solution_signature(decomposer.signature)

    # Include context from previous solutions
    context = build_subgoal_context(previous_solutions)

    subgoal_inputs =
      inputs
      |> Map.put(:subgoal_id, subgoal_id)
      |> Map.put(:previous_context, context)

    with {:ok, prompt} <- build_prompt(subgoal_signature, subgoal_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, decomposer.max_retries),
         {:ok, solution} <- parse_response(subgoal_signature, response) do
      solved_subgoal = Map.merge(solution, %{subgoal_id: subgoal_id})
      {:ok, solved_subgoal}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp synthesize_final_solution(decomposer, inputs, solved_subgoals) do
    synthesis_signature = create_synthesis_signature(decomposer.signature)

    subgoals_summary = summarize_solved_subgoals(solved_subgoals)

    synthesis_inputs =
      inputs
      |> Map.put(:solved_subgoals, subgoals_summary)
      |> Map.put(:total_subgoals, length(solved_subgoals))

    with {:ok, prompt} <- build_prompt(synthesis_signature, synthesis_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, decomposer.max_retries),
         {:ok, final_solution} <- parse_response(synthesis_signature, response) do
      enhanced_solution =
        final_solution
        |> Map.put(:decomposition_summary, subgoals_summary)
        |> Map.put(:subgoals_count, length(solved_subgoals))

      {:ok, enhanced_solution}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper functions

  defp should_further_decompose?(decomposer, subgoals_descriptions, depth) do
    avg_complexity =
      subgoals_descriptions
      |> Enum.map(&estimate_subgoal_complexity/1)
      |> Enum.sum()
      |> Kernel./(length(subgoals_descriptions))

    depth < decomposer.max_depth and
      avg_complexity > decomposer.min_subgoal_complexity and
      length(subgoals_descriptions) > 1
  end

  defp estimate_subgoal_complexity(description) do
    # Simple heuristic based on description length and keywords
    base_complexity = min(String.length(description) / 100.0, 1.0)

    complex_keywords = ["analyze", "design", "implement", "evaluate", "optimize"]
    simple_keywords = ["list", "identify", "find", "calculate"]

    complexity_adjustment =
      complex_keywords
      |> Enum.count(fn keyword -> String.contains?(String.downcase(description), keyword) end)
      |> Kernel.*(0.1)

    simplicity_adjustment =
      simple_keywords
      |> Enum.count(fn keyword -> String.contains?(String.downcase(description), keyword) end)
      |> Kernel.*(-0.05)

    result = base_complexity + complexity_adjustment + simplicity_adjustment
    max(0.1, min(1.0, result))
  end

  defp estimate_effort(description) do
    # Estimate effort based on description characteristics
    estimate_subgoal_complexity(description) * 2.0
  end

  defp generate_subgoal_id(parent_id, depth, index) do
    prefix = if parent_id, do: "#{parent_id}_", else: ""
    "#{prefix}d#{depth}_sg#{index}"
  end

  defp create_leaf_subgoal(description, parent_id, depth) do
    %{
      id: generate_subgoal_id(parent_id, depth, 0),
      description: description,
      complexity: estimate_subgoal_complexity(description),
      dependencies: [],
      status: :pending,
      solution: nil,
      parent_id: parent_id,
      depth: depth,
      priority: 1.0,
      estimated_effort: estimate_effort(description)
    }
  end

  defp parse_subgoals_list(subgoals_text) do
    subgoals_text
    |> String.split(~r/[,;.\n]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    # Limit to reasonable number
    |> Enum.take(10)
  end

  defp parse_functions_list(functions_text) do
    parse_subgoals_list(functions_text)
  end

  defp parse_phases_list(phases_text) do
    parse_subgoals_list(phases_text)
  end

  defp extract_dependencies(function_desc, all_functions) do
    # Simple dependency extraction based on keywords
    deps =
      all_functions
      |> Enum.with_index()
      |> Enum.filter(fn {other_func, _} ->
        other_func != function_desc and
          String.contains?(String.downcase(function_desc), String.downcase(other_func))
      end)
      |> Enum.map(fn {_, index} -> "func_#{index}" end)

    deps
  end

  defp topological_sort(subgoals) do
    # Simple topological sort implementation
    # For now, just return IDs in dependency order
    Enum.map(subgoals, & &1.id)
  end

  defp group_parallel_subgoals(execution_order, _subgoals) do
    # Simple grouping - each subgoal in its own group for now
    Enum.map(execution_order, &[&1])
  end

  defp build_subgoal_context(previous_solutions) do
    previous_solutions
    |> Enum.map(fn solution ->
      "#{solution.subgoal_id}: #{Map.get(solution, :summary, "Solved")}"
    end)
    |> Enum.join("\n")
  end

  defp summarize_solved_subgoals(solved_subgoals) do
    solved_subgoals
    |> Enum.with_index(1)
    |> Enum.map(fn {subgoal, index} ->
      "Subgoal #{index}: #{Map.get(subgoal, :summary, "Completed")}"
    end)
    |> Enum.join("\n")
  end

  # Signature creation functions

  defp create_complexity_analysis_signature(base_signature) do
    output_fields = [
      %{
        name: :complexity_score,
        type: :number,
        description: "Overall problem complexity (0-1)",
        required: true,
        default: nil
      },
      %{
        name: :decomposability_score,
        type: :number,
        description: "How well can this be decomposed (0-1)",
        required: true,
        default: nil
      },
      %{
        name: :interdependency_level,
        type: :number,
        description: "Level of interdependency (0-1)",
        required: true,
        default: nil
      },
      %{
        name: :suggested_strategy,
        type: :string,
        description: "Recommended decomposition strategy",
        required: false,
        default: nil
      }
    ]

    instructions = """
    Analyze the complexity and decomposability of this problem.
    Consider factors like size, interdependency, domain specificity, and time constraints.
    Provide numerical scores and suggest the best decomposition approach.
    """

    %{base_signature | output_fields: output_fields, instructions: instructions}
  end

  defp create_decomposition_signature(base_signature) do
    input_fields = [
      %{
        name: :problem_description,
        type: :string,
        description: "Problem to decompose",
        required: true,
        default: nil
      },
      %{
        name: :decomposition_depth,
        type: :integer,
        description: "Current decomposition depth",
        required: true,
        default: nil
      },
      %{
        name: :parent_context,
        type: :string,
        description: "Parent problem context",
        required: true,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :subgoals,
        type: :string,
        description: "List of subgoals (comma-separated)",
        required: true,
        default: nil
      },
      %{
        name: :decomposition_rationale,
        type: :string,
        description: "Explanation of decomposition approach",
        required: false,
        default: nil
      }
    ]

    instructions = """
    Break down the given problem into 2-5 manageable subgoals.
    Each subgoal should be clear, specific, and contribute to solving the overall problem.
    List the subgoals separated by commas.
    """

    %{
      base_signature
      | input_fields: input_fields ++ base_signature.input_fields,
        output_fields: output_fields,
        instructions: instructions
    }
  end

  defp create_functional_decomposition_signature(base_signature) do
    output_fields = [
      %{
        name: :functional_components,
        type: :string,
        description: "Functional components (comma-separated)",
        required: true,
        default: nil
      }
    ]

    instructions = "Identify the key functional components needed to solve this problem."

    %{base_signature | output_fields: output_fields, instructions: instructions}
  end

  defp create_temporal_decomposition_signature(base_signature) do
    output_fields = [
      %{
        name: :temporal_phases,
        type: :string,
        description: "Temporal phases (comma-separated)",
        required: true,
        default: nil
      }
    ]

    instructions = "Break down the problem into temporal phases or sequential steps."

    %{base_signature | output_fields: output_fields, instructions: instructions}
  end

  defp create_subgoal_solution_signature(base_signature) do
    input_fields = [
      %{
        name: :subgoal_id,
        type: :string,
        description: "Subgoal identifier",
        required: true,
        default: nil
      },
      %{
        name: :previous_context,
        type: :string,
        description: "Context from previous subgoals",
        required: false,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :summary,
        type: :string,
        description: "Summary of subgoal solution",
        required: true,
        default: nil
      }
      | base_signature.output_fields
    ]

    instructions = """
    Solve this specific subgoal within the context of the larger problem.
    Use information from previously solved subgoals if provided.
    Provide a clear solution summary.
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
        name: :solved_subgoals,
        type: :string,
        description: "Summary of solved subgoals",
        required: true,
        default: nil
      },
      %{
        name: :total_subgoals,
        type: :integer,
        description: "Total number of subgoals",
        required: true,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :integration_approach,
        type: :string,
        description: "How subgoals were integrated",
        required: true,
        default: nil
      }
      | base_signature.output_fields
    ]

    instructions = """
    Synthesize the solutions from all subgoals into a comprehensive final solution.
    Ensure all subgoal results are properly integrated and any conflicts are resolved.
    Provide a complete solution to the original problem.
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
