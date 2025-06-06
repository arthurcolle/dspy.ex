defmodule Dspy.TreeOfThoughts do
  @moduledoc """
  Tree of Thoughts (ToT) reasoning module.

  Explores multiple reasoning paths simultaneously in a tree-like structure.
  Each path represents a different approach to solving the problem, and the
  best path is selected based on evaluation criteria.
  """

  use Dspy.Module

  defstruct [:signature, :examples, :max_retries, :num_thoughts, :max_depth, :evaluation_strategy]

  @type thought :: %{
          id: String.t(),
          content: String.t(),
          depth: non_neg_integer(),
          parent_id: String.t() | nil,
          score: float(),
          state: map()
        }

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          num_thoughts: pos_integer(),
          max_depth: pos_integer(),
          evaluation_strategy: atom()
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)

    %__MODULE__{
      signature: base_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      num_thoughts: Keyword.get(opts, :num_thoughts, 3),
      max_depth: Keyword.get(opts, :max_depth, 3),
      evaluation_strategy: Keyword.get(opts, :evaluation_strategy, :value_based)
    }
  end

  @impl true
  def forward(tot, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(tot.signature, inputs),
         {:ok, thoughts_tree} <- explore_thoughts_tree(tot, inputs),
         {:ok, best_path} <- select_best_path(tot, thoughts_tree),
         {:ok, final_outputs} <- synthesize_final_answer(tot, inputs, best_path) do
      prediction = Dspy.Prediction.new(final_outputs)
      {:ok, prediction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_signature(signature) when is_atom(signature) do
    signature.signature()
  end

  defp get_signature(signature), do: signature

  defp explore_thoughts_tree(tot, inputs) do
    initial_thoughts = generate_initial_thoughts(tot, inputs)

    case initial_thoughts do
      {:ok, thoughts} ->
        tree = build_tree_iteratively(tot, inputs, thoughts, 1)
        {:ok, tree}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_initial_thoughts(tot, inputs) do
    thought_generation_signature = create_thought_generation_signature(tot.signature)

    tasks =
      1..tot.num_thoughts
      |> Enum.map(fn i ->
        Task.async(fn ->
          generate_single_thought(thought_generation_signature, inputs, tot, nil, 0, i)
        end)
      end)

    results = Task.await_many(tasks, 30_000)

    successful_thoughts =
      results
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, thought} -> thought end)

    case successful_thoughts do
      [] -> {:error, :no_initial_thoughts_generated}
      thoughts -> {:ok, thoughts}
    end
  end

  defp build_tree_iteratively(%{max_depth: max_depth}, _inputs, current_thoughts, depth)
       when depth >= max_depth do
    current_thoughts
  end

  defp build_tree_iteratively(tot, inputs, current_thoughts, depth) do
    # Evaluate current thoughts
    evaluated_thoughts = evaluate_thoughts(tot, current_thoughts)

    # Select promising thoughts for expansion
    selected_thoughts = select_thoughts_for_expansion(evaluated_thoughts, tot.num_thoughts)

    # Generate next level thoughts
    next_level_thoughts =
      selected_thoughts
      |> Enum.flat_map(fn parent_thought ->
        case generate_child_thoughts(tot, inputs, parent_thought, depth) do
          {:ok, children} -> children
          _ -> []
        end
      end)

    all_thoughts = evaluated_thoughts ++ next_level_thoughts
    build_tree_iteratively(tot, inputs, all_thoughts, depth + 1)
  end

  defp generate_child_thoughts(tot, inputs, parent_thought, depth) do
    thought_generation_signature = create_thought_generation_signature(tot.signature)

    tasks =
      1..tot.num_thoughts
      |> Enum.map(fn i ->
        Task.async(fn ->
          generate_single_thought(
            thought_generation_signature,
            inputs,
            tot,
            parent_thought.id,
            depth,
            i
          )
        end)
      end)

    results = Task.await_many(tasks, 30_000)

    successful_thoughts =
      results
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, thought} -> thought end)

    {:ok, successful_thoughts}
  end

  defp generate_single_thought(signature, inputs, tot, parent_id, depth, thought_num) do
    enhanced_inputs =
      inputs
      |> Map.put(:depth, depth)
      |> Map.put(:thought_number, thought_num)
      |> add_parent_context(parent_id)

    with {:ok, prompt} <- build_thought_prompt(signature, enhanced_inputs, tot.examples),
         {:ok, response} <- generate_with_retries(prompt, tot.max_retries),
         {:ok, parsed_output} <- parse_thought_response(signature, response) do
      thought = %{
        id: generate_thought_id(parent_id, depth, thought_num),
        content: Map.get(parsed_output, :thought, ""),
        depth: depth,
        parent_id: parent_id,
        score: 0.0,
        state: parsed_output
      }

      {:ok, thought}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_thought_generation_signature(base_signature) do
    input_fields = [
      %{
        name: :depth,
        type: :integer,
        description: "Current depth in the tree",
        required: true,
        default: nil
      },
      %{
        name: :thought_number,
        type: :integer,
        description: "Thought number at this level",
        required: true,
        default: nil
      },
      %{
        name: :parent_context,
        type: :string,
        description: "Context from parent thought",
        required: false,
        default: nil
      }
      | base_signature.input_fields
    ]

    output_fields = [
      %{
        name: :thought,
        type: :string,
        description: "A single reasoning step or approach",
        required: true,
        default: nil
      },
      %{
        name: :reasoning,
        type: :string,
        description: "Explanation of this thought",
        required: true,
        default: nil
      }
      | base_signature.output_fields
    ]

    instructions = """
    Generate a single reasoning step or approach to solve this problem.
    Each thought should represent a different way of thinking about the problem.
    Build on previous thoughts if parent context is provided.
    Be creative and explore different angles.
    """

    %{
      base_signature
      | input_fields: input_fields,
        output_fields: output_fields,
        instructions: instructions
    }
  end

  defp add_parent_context(inputs, nil), do: inputs

  defp add_parent_context(inputs, _parent_id) do
    # In a full implementation, you would look up the parent thought content
    Map.put(inputs, :parent_context, "Building on previous reasoning...")
  end

  defp generate_thought_id(nil, depth, thought_num) do
    "thought_#{depth}_#{thought_num}_#{:rand.uniform(1000)}"
  end

  defp generate_thought_id(parent_id, depth, thought_num) do
    "#{parent_id}_#{depth}_#{thought_num}"
  end

  defp evaluate_thoughts(tot, thoughts) do
    case tot.evaluation_strategy do
      :value_based -> evaluate_thoughts_by_value(thoughts)
      :vote_based -> evaluate_thoughts_by_vote(thoughts)
      _ -> evaluate_thoughts_by_value(thoughts)
    end
  end

  defp evaluate_thoughts_by_value(thoughts) do
    # Simple heuristic evaluation based on thought content
    Enum.map(thoughts, fn thought ->
      score = calculate_thought_score(thought.content)
      %{thought | score: score}
    end)
  end

  defp evaluate_thoughts_by_vote(thoughts) do
    # For demo purposes, assign random scores
    # In real implementation, would use separate evaluation model
    Enum.map(thoughts, fn thought ->
      score = :rand.uniform()
      %{thought | score: score}
    end)
  end

  defp calculate_thought_score(content) do
    # Simple scoring based on content characteristics
    base_score = 0.5

    # Reward longer, more detailed thoughts
    length_bonus = min(String.length(content) / 200.0, 0.3)

    # Reward presence of keywords indicating reasoning
    reasoning_keywords = ["because", "therefore", "since", "thus", "hence", "consequently"]

    keyword_bonus =
      reasoning_keywords
      |> Enum.count(fn keyword -> String.contains?(String.downcase(content), keyword) end)
      |> Kernel.*(0.05)

    base_score + length_bonus + keyword_bonus
  end

  defp select_thoughts_for_expansion(thoughts, num_to_select) do
    thoughts
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(num_to_select)
  end

  defp select_best_path(_tot, thoughts) do
    # Find the path with the highest cumulative score
    leaf_thoughts =
      Enum.filter(thoughts, fn thought ->
        # A leaf is a thought with no children
        !Enum.any?(thoughts, fn other -> other.parent_id == thought.id end)
      end)

    case leaf_thoughts do
      [] ->
        {:error, :no_complete_paths}

      leaves ->
        best_leaf = Enum.max_by(leaves, & &1.score)
        path = reconstruct_path(thoughts, best_leaf)
        {:ok, path}
    end
  end

  defp reconstruct_path(thoughts, leaf_thought) do
    reconstruct_path_recursive(thoughts, leaf_thought, [])
  end

  defp reconstruct_path_recursive(_thoughts, %{parent_id: nil} = thought, acc) do
    [thought | acc]
  end

  defp reconstruct_path_recursive(thoughts, thought, acc) do
    parent = Enum.find(thoughts, fn t -> t.id == thought.parent_id end)
    reconstruct_path_recursive(thoughts, parent, [thought | acc])
  end

  defp synthesize_final_answer(tot, inputs, best_path) do
    synthesis_signature = create_synthesis_signature(tot.signature)

    path_summary = summarize_thought_path(best_path)

    synthesis_inputs =
      inputs
      |> Map.put(:thought_path, path_summary)

    with {:ok, prompt} <- build_thought_prompt(synthesis_signature, synthesis_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, tot.max_retries),
         {:ok, outputs} <- parse_thought_response(synthesis_signature, response) do
      {:ok, outputs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_synthesis_signature(base_signature) do
    input_fields = [
      %{
        name: :thought_path,
        type: :string,
        description: "Summary of the best reasoning path",
        required: true,
        default: nil
      }
      | base_signature.input_fields
    ]

    instructions = """
    Based on the best reasoning path found through tree exploration,
    synthesize a final answer. Use the insights from each step in the path
    to provide a comprehensive and well-reasoned solution.
    """

    %{
      base_signature
      | input_fields: input_fields,
        instructions: instructions
    }
  end

  defp summarize_thought_path(path) do
    path
    |> Enum.with_index(1)
    |> Enum.map(fn {thought, index} ->
      "Step #{index}: #{thought.content}"
    end)
    |> Enum.join("\n")
  end

  defp build_thought_prompt(signature, inputs, examples) do
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

  defp parse_thought_response(signature, response_text) do
    outputs = Dspy.Signature.parse_outputs(signature, response_text)
    {:ok, outputs}
  end
end
