#!/usr/bin/env elixir

# Example demonstrating streaming structured outputs with deepseek-r1-0528-qwen3-8b-mlx
#
# This example shows how to:
# 1. Configure the LMStudio client for the deepseek model
# 2. Use streaming completions
# 3. Get structured JSON outputs that conform to a schema
#
# Make sure LM Studio is running on localhost:1234 with the deepseek model loaded

# Add dependencies to the code path
Mix.install([
  {:jason, "~> 1.4"},
  {:lmstudio, git: "https://github.com/arthurcolle/lmstudio.ex.git"}
])

# Configure LMStudio for deepseek model
Application.put_env(:lmstudio, :base_url, "http://192.168.1.177:1234")
Application.put_env(:lmstudio, :default_model, "deepseek-r1-0528-qwen3-8b-mlx")
Application.put_env(:lmstudio, :default_temperature, 0.3)
Application.put_env(:lmstudio, :default_max_tokens, -1)

# No need to load DSPy modules for this standalone example

defmodule DeepSeekStreamingExample do
  @moduledoc """
  Example demonstrating streaming structured outputs with deepseek model.
  """

  def run_streaming_structured_example do
    IO.puts("🚀 Starting DeepSeek Streaming Structured Output Example...")
    IO.puts("Model: deepseek-r1-0528-qwen3-8b-mlx")
    IO.puts("Features: stream=true + structured JSON output")
    IO.puts(String.duplicate("=", 60))

    # LMStudio is already configured via Application.put_env above

    # Define a JSON schema for structured output
    json_schema = %{
      type: "object",
      properties: %{
        analysis: %{
          type: "string",
          description: "Brief analysis of the problem"
        },
        solution_steps: %{
          type: "array",
          items: %{type: "string"},
          description: "List of steps to solve the problem"
        },
        confidence: %{
          type: "number",
          minimum: 0,
          maximum: 1,
          description: "Confidence level in the solution (0-1)"
        },
        estimated_time: %{
          type: "string",
          description: "Estimated time to complete"
        }
      },
      required: ["analysis", "solution_steps", "confidence"]
    }

    # Build messages for LMStudio
    messages = [
      %{
        role: "system",
        content: build_schema_prompt(json_schema)
      },
      %{
        role: "user", 
        content: "How can I implement a simple blockchain in Elixir? Please provide a structured analysis."
      }
    ]

    IO.puts("📡 Starting streaming request...")
    IO.puts("User: How can I implement a simple blockchain in Elixir?")
    IO.puts("Expected: Structured JSON response with analysis, steps, confidence")
    IO.puts("")

    # Use Agent to track accumulated content across callback calls
    {:ok, accumulator_pid} = Agent.start_link(fn -> "" end)

    # Define streaming callback
    stream_callback = fn
      {:chunk, content} ->
        IO.write(content)
        Agent.update(accumulator_pid, fn acc -> acc <> content end)
        :ok
      
      {:done, _} ->
        IO.puts("\n")
        IO.puts(String.duplicate("-", 40))
        IO.puts("✅ Streaming completed!")
        
        # Try to parse the accumulated JSON
        accumulated_content = Agent.get(accumulator_pid, & &1)
        
        # Extract JSON content, removing <think> blocks if present
        json_content = extract_json_from_response(accumulated_content)
        
        case Jason.decode(json_content) do
          {:ok, parsed_json} ->
            IO.puts("✅ Valid JSON structure received!")
            IO.puts("📋 Parsed Response:")
            IO.puts(Jason.encode!(parsed_json, pretty: true))
            validate_schema(parsed_json, json_schema)
          
          {:error, _} ->
            IO.puts("❌ Response was not valid JSON")
            IO.puts("Raw response: #{accumulated_content}")
            IO.puts("Extracted JSON content: #{json_content}")
        end
        :ok
    end

    # Execute streaming structured request
    case LMStudio.complete(messages, stream: true, stream_callback: stream_callback) do
      {:ok, _} ->
        IO.puts("🎉 Example completed successfully!")
      
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end

  def run_non_streaming_example do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🔄 Non-streaming structured output for comparison...")

    json_schema = %{
      type: "object",
      properties: %{
        summary: %{type: "string"},
        key_points: %{
          type: "array",
          items: %{type: "string"}
        },
        complexity: %{
          type: "string",
          enum: ["low", "medium", "high"]
        }
      },
      required: ["summary", "key_points", "complexity"]
    }

    messages = [
      %{
        role: "system",
        content: build_schema_prompt(json_schema)
      },
      %{
        role: "user",
        content: "Explain machine learning in simple terms."
      }
    ]

    IO.puts("📡 Making non-streaming request...")
    
    case LMStudio.complete(messages) do
      {:ok, response} ->
        content = get_in(response, ["choices", Access.at(0), "message", "content"])
        IO.puts("📋 Response: #{content}")
        
        # Extract JSON content, removing <think> blocks if present
        json_content = extract_json_from_response(content)
        
        case Jason.decode(json_content) do
          {:ok, parsed} ->
            IO.puts("✅ Valid JSON received!")
            IO.puts(Jason.encode!(parsed, pretty: true))
          {:error, _} ->
            IO.puts("❌ Invalid JSON in response")
            IO.puts("Extracted JSON content: #{json_content}")
        end
      
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end

  defp build_schema_prompt(schema) do
    """
    You must respond with valid JSON that strictly follows this schema:

    #{Jason.encode!(schema, pretty: true)}

    Important requirements:
    - Your response MUST be valid JSON
    - Your response MUST conform exactly to the provided schema
    - Do not include any text before or after the JSON
    - Ensure all required fields are present
    - Follow the specified data types exactly
    """
  end

  defp extract_json_from_response(content) do
    # Remove <think>...</think> blocks from the response
    content
    |> String.replace(~r/<think>.*?<\/think>/s, "")
    |> String.trim()
  end

  defp validate_schema(response, schema) do
    required_fields = Map.get(schema, :required, [])
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(response, field)
    end)

    if Enum.empty?(missing_fields) do
      IO.puts("✅ All required fields present!")
    else
      IO.puts("⚠️  Missing required fields: #{inspect(missing_fields)}")
    end
  end
end

# Run the examples
DeepSeekStreamingExample.run_streaming_structured_example()
DeepSeekStreamingExample.run_non_streaming_example()

IO.puts("\n🎯 Summary:")
IO.puts("- ✅ LMStudio client with deepseek model support")
IO.puts("- ✅ Streaming completions (stream=true)")  
IO.puts("- ✅ Structured JSON outputs via schema prompting")
IO.puts("- ✅ Real-time token streaming with final JSON validation")
IO.puts("\nTo run: mix deps.get && elixir examples/deepseek_streaming_structured.exs")