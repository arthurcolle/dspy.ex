defmodule Dspy.StructuredReasoning do
  @moduledoc """
  Structured reasoning extraction for OpenAI models.

  Enables extraction of chain-of-thought reasoning steps and final results
  using OpenAI's structured output feature.
  """

  @doc """
  Define a reasoning schema for structured output.
  """
  def reasoning_schema do
    %{
      type: "object",
      properties: %{
        reasoning_steps: %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              step_number: %{type: "integer"},
              thought: %{type: "string"},
              observation: %{type: "string"}
            },
            required: ["step_number", "thought"]
          }
        },
        final_answer: %{
          type: "string",
          description: "The final answer or conclusion"
        },
        confidence: %{
          type: "number",
          minimum: 0,
          maximum: 1,
          description: "Confidence level in the answer (0-1)"
        }
      },
      required: ["reasoning_steps", "final_answer"]
    }
  end

  @doc """
  Create a structured reasoning request for GPT models.
  """
  def create_reasoning_request(prompt, opts \\ []) do
    system_prompt =
      Keyword.get(opts, :system_prompt, """
      You are a helpful assistant that provides step-by-step reasoning.
      For each query, break down your thinking process into clear steps,
      make observations when relevant, and provide a final answer with confidence level.
      """)

    %{
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: prompt}
      ],
      response_format: %{
        type: "json_schema",
        json_schema: %{
          name: "reasoning_response",
          schema: reasoning_schema()
        }
      }
    }
  end

  @doc """
  Extract reasoning from a model response.
  """
  def extract_reasoning(response) do
    case response do
      {:ok, %{choices: [%{message: %{"content" => content}} | _]}} ->
        case Jason.decode(content) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, reason} -> {:error, {:json_parse_error, reason}}
        end

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :invalid_response_format}
    end
  end

  @doc """
  Format reasoning steps for display.
  """
  def format_reasoning(reasoning_data) do
    steps = reasoning_data["reasoning_steps"] || []
    final_answer = reasoning_data["final_answer"] || "No answer provided"
    confidence = reasoning_data["confidence"]

    formatted_steps =
      steps
      |> Enum.map(fn step ->
        observation =
          if step["observation"], do: "\n   Observation: #{step["observation"]}", else: ""

        "#{step["step_number"]}. #{step["thought"]}#{observation}"
      end)
      |> Enum.join("\n")

    confidence_str =
      if confidence, do: " (Confidence: #{Float.round(confidence * 1.0, 2)})", else: ""

    """
    Reasoning Steps:
    #{formatted_steps}

    Final Answer: #{final_answer}#{confidence_str}
    """
  end
end
