defmodule Dspy.VerificationBehavior do
  @moduledoc """
  Verification behavior module implementing systematic verification strategies.

  This module embodies the cognitive behavior of verification - the systematic
  checking and validation of reasoning steps, solutions, and conclusions.
  It implements multiple verification strategies used by expert problem solvers.
  """

  use Dspy.Module

  defstruct [
    :signature,
    :examples,
    :max_retries,
    :verification_strategies,
    :error_types,
    :confidence_threshold,
    :multi_method_verification
  ]

  @type verification_strategy ::
          :dimensional_analysis
          | :sanity_check
          | :edge_case_testing
          | :logical_consistency
          | :empirical_validation
          | :peer_review_simulation
          | :alternative_methods
          | :boundary_testing

  @type verification_result :: %{
          strategy: verification_strategy(),
          passed: boolean(),
          confidence: float(),
          evidence: String.t(),
          issues_found: [String.t()]
        }

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          verification_strategies: [verification_strategy()],
          error_types: [atom()],
          confidence_threshold: float(),
          multi_method_verification: boolean()
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)

    default_strategies = [
      :sanity_check,
      :logical_consistency,
      :edge_case_testing,
      :dimensional_analysis,
      :alternative_methods
    ]

    %__MODULE__{
      signature: base_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      verification_strategies: Keyword.get(opts, :verification_strategies, default_strategies),
      error_types:
        Keyword.get(opts, :error_types, [:calculation, :logic, :assumption, :boundary]),
      confidence_threshold: Keyword.get(opts, :confidence_threshold, 0.8),
      multi_method_verification: Keyword.get(opts, :multi_method_verification, true)
    }
  end

  @impl true
  def forward(verifier, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(verifier.signature, inputs),
         {:ok, initial_solution} <- generate_initial_solution(verifier, inputs),
         {:ok, verification_results} <-
           run_verification_battery(verifier, inputs, initial_solution),
         {:ok, final_solution} <-
           synthesize_verified_solution(verifier, inputs, initial_solution, verification_results) do
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

  defp generate_initial_solution(verifier, inputs) do
    solution_signature = create_solution_signature(verifier.signature)

    with {:ok, prompt} <- build_prompt(solution_signature, inputs, verifier.examples),
         {:ok, response} <- generate_with_retries(prompt, verifier.max_retries),
         {:ok, outputs} <- parse_response(solution_signature, response) do
      {:ok, outputs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_verification_battery(verifier, inputs, solution) do
    verification_tasks =
      verifier.verification_strategies
      |> Enum.map(fn strategy ->
        Task.async(fn ->
          run_single_verification(verifier, inputs, solution, strategy)
        end)
      end)

    results = Task.await_many(verification_tasks, 30_000)

    successful_verifications =
      results
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, result} -> result end)

    {:ok, successful_verifications}
  end

  defp run_single_verification(verifier, inputs, solution, strategy) do
    verification_signature = create_verification_signature(verifier.signature, strategy)

    verification_inputs =
      inputs
      |> Map.put(:original_solution, format_solution(solution))
      |> Map.put(:verification_strategy, Atom.to_string(strategy))

    with {:ok, prompt} <- build_prompt(verification_signature, verification_inputs, []),
         {:ok, response} <- generate_with_retries(prompt, verifier.max_retries),
         {:ok, parsed} <- parse_response(verification_signature, response) do
      result = %{
        strategy: strategy,
        passed: Map.get(parsed, :verification_passed, false),
        confidence: calculate_verification_confidence(parsed, strategy),
        evidence: Map.get(parsed, :verification_evidence, ""),
        issues_found: parse_issues(Map.get(parsed, :issues_identified, ""))
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_solution_signature(base_signature) do
    output_fields = [
      %{
        name: :reasoning_steps,
        type: :string,
        description: "Step-by-step reasoning process",
        required: true,
        default: nil
      },
      %{
        name: :key_assumptions,
        type: :string,
        description: "Key assumptions made",
        required: false,
        default: nil
      }
      | base_signature.output_fields
    ]

    instructions = """
    Solve this problem step by step, clearly showing your reasoning.
    State any key assumptions you're making.
    Provide a complete solution with detailed explanation.
    """

    %{base_signature | output_fields: output_fields, instructions: instructions}
  end

  defp create_verification_signature(base_signature, strategy) do
    {input_fields, output_fields, instructions} = verification_components_for_strategy(strategy)

    combined_input_fields = [
      %{
        name: :original_solution,
        type: :string,
        description: "Original solution to verify",
        required: true,
        default: nil
      },
      %{
        name: :verification_strategy,
        type: :string,
        description: "Verification strategy being used",
        required: true,
        default: nil
      }
      | input_fields ++ base_signature.input_fields
    ]

    combined_output_fields =
      output_fields ++
        [
          %{
            name: :verification_passed,
            type: :boolean,
            description: "Whether verification passed",
            required: true,
            default: nil
          },
          %{
            name: :verification_evidence,
            type: :string,
            description: "Evidence for verification result",
            required: true,
            default: nil
          },
          %{
            name: :issues_identified,
            type: :string,
            description: "List of issues found (if any)",
            required: false,
            default: nil
          }
        ]

    %{
      base_signature
      | input_fields: combined_input_fields,
        output_fields: combined_output_fields,
        instructions: instructions
    }
  end

  defp verification_components_for_strategy(:sanity_check) do
    input_fields = []

    output_fields = [
      %{
        name: :reasonableness_check,
        type: :string,
        description: "Assessment of answer reasonableness",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Perform a sanity check on the solution. Does the answer make intuitive sense?
    Are the orders of magnitude reasonable? Are there any obviously wrong conclusions?
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(:logical_consistency) do
    input_fields = []

    output_fields = [
      %{
        name: :consistency_analysis,
        type: :string,
        description: "Analysis of logical consistency",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Check the logical consistency of the reasoning. Are there any contradictions?
    Do the conclusions follow from the premises? Are all steps logically valid?
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(:edge_case_testing) do
    input_fields = []

    output_fields = [
      %{
        name: :edge_cases_tested,
        type: :string,
        description: "Edge cases considered",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Test the solution against edge cases and boundary conditions.
    What happens at extremes? Does the solution handle special cases correctly?
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(:dimensional_analysis) do
    input_fields = []

    output_fields = [
      %{
        name: :dimensional_check,
        type: :string,
        description: "Dimensional analysis result",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Verify that all quantities have consistent dimensions and units.
    Check that equations are dimensionally balanced. Verify unit conversions.
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(:alternative_methods) do
    input_fields = []

    output_fields = [
      %{
        name: :alternative_approach,
        type: :string,
        description: "Alternative solution method",
        required: true,
        default: nil
      },
      %{
        name: :results_comparison,
        type: :string,
        description: "Comparison of results",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Solve the problem using a different approach or method.
    Compare the results with the original solution. Do they agree?
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(:empirical_validation) do
    input_fields = []

    output_fields = [
      %{
        name: :empirical_test,
        type: :string,
        description: "Empirical validation approach",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Design an empirical test or check for the solution.
    Can the answer be validated against known data or simple test cases?
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(:peer_review_simulation) do
    input_fields = []

    output_fields = [
      %{
        name: :peer_review_feedback,
        type: :string,
        description: "Simulated peer review",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Simulate a peer review of the solution. What questions would a colleague ask?
    What aspects might they challenge or want clarified?
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(:boundary_testing) do
    input_fields = []

    output_fields = [
      %{
        name: :boundary_analysis,
        type: :string,
        description: "Boundary condition analysis",
        required: true,
        default: nil
      }
    ]

    instructions = """
    Test the solution at boundary conditions and limits.
    What happens as parameters approach their limits? Is behavior correct?
    """

    {input_fields, output_fields, instructions}
  end

  defp verification_components_for_strategy(_default) do
    input_fields = []
    output_fields = []
    instructions = "Verify the solution using standard checking procedures."
    {input_fields, output_fields, instructions}
  end

  defp calculate_verification_confidence(parsed_result, strategy) do
    base_confidence = if Map.get(parsed_result, :verification_passed, false), do: 0.8, else: 0.2

    # Adjust confidence based on strategy reliability
    strategy_weight =
      case strategy do
        :dimensional_analysis -> 1.2
        :alternative_methods -> 1.1
        :logical_consistency -> 1.0
        :empirical_validation -> 1.1
        :sanity_check -> 0.8
        _ -> 0.9
      end

    # Adjust based on evidence quality
    evidence = Map.get(parsed_result, :verification_evidence, "")
    evidence_bonus = min(String.length(evidence) / 200.0, 0.1)

    result = base_confidence * strategy_weight + evidence_bonus
    max(0.0, min(1.0, result))
  end

  defp parse_issues(issues_text) do
    if is_binary(issues_text) and String.trim(issues_text) != "" do
      issues_text
      |> String.split(~r/[,;.\n]/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    else
      []
    end
  end

  defp synthesize_verified_solution(verifier, inputs, original_solution, verification_results) do
    synthesis_signature = create_synthesis_signature(verifier.signature)

    verification_summary = summarize_verification_results(verification_results)
    overall_confidence = calculate_overall_confidence(verification_results)

    synthesis_inputs =
      inputs
      |> Map.put(:original_solution, format_solution(original_solution))
      |> Map.put(:verification_summary, verification_summary)
      |> Map.put(:overall_confidence, overall_confidence)

    if overall_confidence >= verifier.confidence_threshold do
      # High confidence - use original solution with verification notes
      enhanced_solution =
        original_solution
        |> Map.put(:verification_summary, verification_summary)
        |> Map.put(:confidence_score, overall_confidence)

      {:ok, enhanced_solution}
    else
      # Low confidence - generate improved solution
      with {:ok, prompt} <- build_prompt(synthesis_signature, synthesis_inputs, []),
           {:ok, response} <- generate_with_retries(prompt, verifier.max_retries),
           {:ok, improved_solution} <- parse_response(synthesis_signature, response) do
        final_solution =
          improved_solution
          |> Map.put(:verification_summary, verification_summary)
          |> Map.put(:confidence_score, overall_confidence)

        {:ok, final_solution}
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp create_synthesis_signature(base_signature) do
    input_fields = [
      %{
        name: :original_solution,
        type: :string,
        description: "Original solution",
        required: true,
        default: nil
      },
      %{
        name: :verification_summary,
        type: :string,
        description: "Summary of verification results",
        required: true,
        default: nil
      },
      %{
        name: :overall_confidence,
        type: :number,
        description: "Overall confidence score",
        required: true,
        default: nil
      }
    ]

    output_fields = [
      %{
        name: :improved_reasoning,
        type: :string,
        description: "Improved reasoning addressing verification issues",
        required: true,
        default: nil
      }
      | base_signature.output_fields
    ]

    instructions = """
    Based on the verification results, improve the original solution.
    Address any issues identified during verification.
    Provide a refined and more robust solution.
    """

    %{
      base_signature
      | input_fields: input_fields ++ base_signature.input_fields,
        output_fields: output_fields,
        instructions: instructions
    }
  end

  defp summarize_verification_results(results) do
    passed_count = Enum.count(results, & &1.passed)
    total_count = length(results)

    summary_parts = [
      "Verification Results: #{passed_count}/#{total_count} checks passed",
      ""
    ]

    detailed_results =
      results
      |> Enum.map(fn result ->
        status = if result.passed, do: "✓", else: "✗"
        "#{status} #{result.strategy}: #{result.evidence}"
      end)

    issues =
      results
      |> Enum.flat_map(& &1.issues_found)
      |> Enum.uniq()

    issue_summary =
      if length(issues) > 0 do
        ["", "Issues identified:"] ++ Enum.map(issues, &"- #{&1}")
      else
        ["", "No significant issues identified."]
      end

    (summary_parts ++ detailed_results ++ issue_summary)
    |> Enum.join("\n")
  end

  defp calculate_overall_confidence(results) do
    if length(results) == 0 do
      0.0
    else
      # Weighted average of verification confidences
      total_confidence =
        results
        |> Enum.map(& &1.confidence)
        |> Enum.sum()

      average_confidence = total_confidence / length(results)

      # Bonus for having multiple successful verifications
      success_rate = Enum.count(results, & &1.passed) / length(results)
      consistency_bonus = success_rate * 0.1

      min(1.0, average_confidence + consistency_bonus)
    end
  end

  defp format_solution(solution) do
    solution
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
end
