defmodule Dspy.ProgramOfThoughts do
  @moduledoc """
  Program of Thoughts (PoT) reasoning module.

  Combines natural language reasoning with executable code generation.
  The model generates both reasoning steps and executable code to solve
  mathematical and logical problems more accurately.
  """

  use Dspy.Module

  defstruct [:signature, :examples, :max_retries, :executor, :language]

  @type t :: %__MODULE__{
          signature: Dspy.Signature.t(),
          examples: [Dspy.Example.t()],
          max_retries: non_neg_integer(),
          executor: atom(),
          language: atom()
        }

  def new(signature, opts \\ []) do
    base_signature = get_signature(signature)
    augmented_signature = add_pot_fields(base_signature)

    %__MODULE__{
      signature: augmented_signature,
      examples: Keyword.get(opts, :examples, []),
      max_retries: Keyword.get(opts, :max_retries, 3),
      executor: Keyword.get(opts, :executor, :elixir),
      language: Keyword.get(opts, :language, :elixir)
    }
  end

  @impl true
  def forward(pot, inputs) do
    with :ok <- Dspy.Signature.validate_inputs(pot.signature, inputs),
         {:ok, prompt} <- build_prompt(pot, inputs),
         {:ok, response} <- generate_with_retries(prompt, pot.max_retries),
         {:ok, parsed_outputs} <- parse_response(pot, response),
         {:ok, executed_result} <- execute_code(pot, parsed_outputs),
         {:ok, final_outputs} <- finalize_outputs(parsed_outputs, executed_result) do
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

  defp add_pot_fields(signature) do
    new_output_fields = [
      %{
        name: :reasoning,
        type: :string,
        description: "Natural language reasoning about the problem",
        required: true,
        default: nil
      },
      %{
        name: :code,
        type: :string,
        description: "Executable code to solve the problem",
        required: true,
        default: nil
      },
      %{
        name: :execution_result,
        type: :string,
        description: "Result from executing the code",
        required: false,
        default: nil
      }
      | signature.output_fields
    ]

    %{signature | output_fields: new_output_fields}
  end

  defp build_prompt(pot, inputs) do
    enhanced_signature = add_pot_instructions(pot.signature, pot.language)
    prompt_template = Dspy.Signature.to_prompt(enhanced_signature, pot.examples)

    filled_prompt =
      Enum.reduce(inputs, prompt_template, fn {key, value}, acc ->
        placeholder = "[input]"
        field_name = String.capitalize(Atom.to_string(key))
        String.replace(acc, "#{field_name}: #{placeholder}", "#{field_name}: #{value}")
      end)

    {:ok, filled_prompt}
  end

  defp add_pot_instructions(signature, language) do
    language_name = language |> Atom.to_string() |> String.capitalize()

    pot_instructions = """
    Solve this problem using Program of Thoughts approach:
    1. First, reason about the problem in natural language
    2. Then, write executable #{language_name} code to solve it
    3. The code should be self-contained and directly compute the answer

    Format your response with clear sections for reasoning and code.
    The code should be executable and produce the correct numerical result.

    IMPORTANT: The code section should contain ONLY executable #{language_name} code.
    Do not include any labels like "Execution_result:", "Output:", or "Result:" in the code.
    The last expression in your code should evaluate to the final answer.
    """

    existing_instructions = signature.instructions || ""

    combined_instructions =
      [existing_instructions, pot_instructions]
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

  defp parse_response(pot, response_text) do
    outputs = Dspy.Signature.parse_outputs(pot.signature, response_text)
    {:ok, outputs}
  end

  defp execute_code(pot, outputs) do
    code = Map.get(outputs, :code, "")

    result =
      case pot.executor do
        :elixir -> execute_elixir_code(code)
        :python -> execute_python_code(code)
        _ -> {:error, :unsupported_executor}
      end

    # Ensure the result is always wrapped in a tuple
    case result do
      {:ok, _} -> result
      {:error, _} -> result
      # Wrap bare results
      other -> {:ok, other}
    end
  end

  defp execute_elixir_code(code) do
    # Self-scaffolding allows all Elixir abstractions including deps modification
    execute_code_with_full_access(code)
  end

  defp execute_code_with_full_access(code) do
    try do
      # Clean the code - remove markdown formatting and common LLM artifacts
      clean_code =
        code
        |> String.replace("```elixir", "")
        |> String.replace("```", "")
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(fn line ->
          # Remove lines that are just labels or comments about execution
          String.contains?(line, "Execution_result:") ||
            String.contains?(line, "Execution result:") ||
            String.contains?(line, "Output:") ||
            String.contains?(line, "Result:") ||
            (String.starts_with?(line, "#") && String.contains?(String.downcase(line), "output"))
        end)
        |> Enum.join("\n")
        |> String.trim()

      # Execute with full system access for self-scaffolding
      task =
        Task.async(fn ->
          # Allow full Elixir environment access including:
          # - File operations, System calls, Process management
          # - Dynamic module creation and compilation
          # - Dependency modification via Mix
          # - Network operations, database access
          # - All BEAM abstractions and OTP behaviors

          eval_code = """
          # Import all standard libraries
          import Enum
          import String
          import Process
          import File
          import System
          import Code

          # Allow access to Mix for dependency management
          require Mix

          #{clean_code}
          """

          {result, _binding} = Code.eval_string(eval_code)
          result
        end)

      # Extended timeout for complex self-scaffolding operations
      case Task.yield(task, 30_000) || Task.shutdown(task) do
        {:ok, result} -> {:ok, to_string(result)}
        nil -> {:error, {:execution_timeout, "Code execution timed out after 30 seconds"}}
      end
    rescue
      error -> {:error, {:execution_failed, Exception.message(error)}}
    catch
      :exit, reason -> {:error, {:execution_exit, reason}}
      :throw, value -> {:error, {:execution_throw, value}}
    end
  end

  defp execute_python_code(code) do
    # This would require a Python executor - for now, return a placeholder
    # In a real implementation, you might use a Python subprocess or embedded interpreter
    clean_code =
      code
      |> String.replace("```python", "")
      |> String.replace("```", "")
      |> String.trim()

    # For demo purposes, try to extract simple arithmetic
    case extract_simple_arithmetic(clean_code) do
      {:ok, result} -> {:ok, to_string(result)}
      :error -> {:error, :python_execution_not_implemented}
    end
  end

  defp extract_simple_arithmetic(code) do
    # Very basic arithmetic extraction for demo
    cond do
      String.contains?(code, "+") ->
        parts = String.split(code, "+") |> Enum.map(&String.trim/1)

        case Enum.map(parts, &Integer.parse/1) do
          [{a, ""}, {b, ""}] -> {:ok, a + b}
          _ -> :error
        end

      String.contains?(code, "-") ->
        parts = String.split(code, "-") |> Enum.map(&String.trim/1)

        case Enum.map(parts, &Integer.parse/1) do
          [{a, ""}, {b, ""}] -> {:ok, a - b}
          _ -> :error
        end

      String.contains?(code, "*") ->
        parts = String.split(code, "*") |> Enum.map(&String.trim/1)

        case Enum.map(parts, &Integer.parse/1) do
          [{a, ""}, {b, ""}] -> {:ok, a * b}
          _ -> :error
        end

      true ->
        :error
    end
  end

  defp finalize_outputs(parsed_outputs, execution_result) do
    case execution_result do
      {:ok, result} ->
        final_outputs =
          parsed_outputs
          |> Map.put(:execution_result, result)
          |> Map.put(:execution_status, "success")
          |> update_answer_with_execution(result)

        {:ok, final_outputs}

      {:error, {:unsafe_code, reason}} ->
        error_outputs =
          parsed_outputs
          |> Map.put(:execution_result, "Error: Unsafe code detected - #{reason}")
          |> Map.put(:execution_status, "blocked")
          |> Map.put(:error_type, "safety_violation")

        {:ok, error_outputs}

      {:error, {:execution_timeout, reason}} ->
        error_outputs =
          parsed_outputs
          |> Map.put(:execution_result, "Error: #{reason}")
          |> Map.put(:execution_status, "timeout")
          |> Map.put(:error_type, "timeout")

        {:ok, error_outputs}

      {:error, {:execution_failed, reason}} ->
        error_outputs =
          parsed_outputs
          |> Map.put(:execution_result, "Error: #{reason}")
          |> Map.put(:execution_status, "failed")
          |> Map.put(:error_type, "runtime_error")

        {:ok, error_outputs}

      {:error, reason} ->
        error_message =
          case reason do
            atom when is_atom(atom) -> Atom.to_string(atom)
            binary when is_binary(binary) -> binary
            _ -> inspect(reason)
          end

        error_outputs =
          parsed_outputs
          |> Map.put(:execution_result, "Error: #{error_message}")
          |> Map.put(:execution_status, "failed")
          |> Map.put(:error_type, "unknown_error")

        {:ok, error_outputs}

      result when is_binary(result) ->
        # Handle bare string results (legacy compatibility)
        final_outputs =
          parsed_outputs
          |> Map.put(:execution_result, result)
          |> Map.put(:execution_status, "success")
          |> update_answer_with_execution(result)

        {:ok, final_outputs}
    end
  end

  defp update_answer_with_execution(outputs, execution_result) do
    # Update the main answer field with the execution result if it exists
    answer_field = find_answer_field(outputs)

    if answer_field do
      Map.put(outputs, answer_field, execution_result)
    else
      outputs
    end
  end

  defp find_answer_field(outputs) do
    # Look for common answer field names
    answer_fields = [:answer, :result, :solution, :output]

    Enum.find(answer_fields, fn field ->
      Map.has_key?(outputs, field)
    end)
  end
end
