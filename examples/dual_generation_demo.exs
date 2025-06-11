# Dual Generation Demo
# Shows how to use both streaming and non-streaming generations for structured outputs

Mix.install([
  {:jason, "~> 1.4"},
  {:req, "~> 0.4"}
])

# Add the DSPy lib directory to the code path
Code.prepend_path("lib")

# Compile required modules in order
Code.compile_file("lib/dspy/settings.ex")
Code.compile_file("lib/dspy/signature.ex") 
Code.compile_file("lib/dspy/multi_agent_logger.ex")
Code.compile_file("lib/dspy/lm.ex")
Code.compile_file("lib/dspy/lm/lmstudio.ex")
Code.compile_file("lib/dspy/application.ex")

# Start the necessary applications
Application.ensure_all_started(:logger)
Application.ensure_all_started(:inets)

# Start the Dspy application
{:ok, _} = Dspy.Application.start(:normal, [])

defmodule DualGenerationDemo do
  alias Dspy.LM.LMStudio

  @doc """
  Example schema for structured output (like the reasoning patterns in your logs)
  """
  def get_reasoning_schema do
    %{
      "type" => "object",
      "properties" => %{
        "analysis" => %{
          "type" => "string",
          "description" => "Technical analysis of the problem"
        },
        "complexity_score" => %{
          "type" => "number",
          "minimum" => 1,
          "maximum" => 10,
          "description" => "Complexity rating from 1-10"
        },
        "solution_steps" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Step-by-step solution approach"
        },
        "code_snippets" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "code" => %{"type" => "string"},
              "language" => %{"type" => "string"},
              "explanation" => %{"type" => "string"}
            },
            "required" => ["code", "language", "explanation"]
          }
        },
        "risks" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Potential risks or challenges"
        },
        "confidence" => %{
          "type" => "number",
          "minimum" => 0,
          "maximum" => 1,
          "description" => "Confidence level in the solution"
        },
        "estimated_time" => %{
          "type" => "string",
          "description" => "Estimated implementation time"
        }
      },
      "required" => ["analysis", "complexity_score", "solution_steps", "risks", "confidence", "estimated_time"]
    }
  end

  def run_demo do
    IO.puts("🚀 Starting True Dual Model Generation Demo with LM Studio")
    
    # Initialize two LM Studio clients for different models
    streaming_client = Dspy.LM.LMStudio.new(
      base_url: "http://192.168.1.177:1234",
      model: "deepseek-r1-0528-qwen3-8b-mlx",
      temperature: 0.7,
      max_tokens: 2048
    )
    
    final_client = Dspy.LM.LMStudio.new(
      base_url: "http://192.168.1.177:1234",
      model: "deepseek-r1-0528-qwen3-8b-mlx:2",
      temperature: 0.7,
      max_tokens: 2048
    )

    # Test request for microservices architecture design
    request = %{
      messages: [
        %{
          role: "user",
          content: "Design a microservices architecture for a trading platform with high availability."
        }
      ],
      response_format: %{
        type: "json_schema",
        json_schema: get_reasoning_schema()
      },
      n: 4,  # Generate 4 different responses
      logprobs: true  # Include logprobs for analysis
    }

    # Define streaming callback for real-time output
    stream_callback = fn
      {:chunk, content} ->
        # Filter out raw SSE data and only show actual content
        if String.printable?(content) and not String.contains?(content, "data: ") do
          IO.write(content)
        end
      
      {:done, final_response} ->
        IO.puts("\n✅ Streaming complete!")
        if final_response do
          choices_count = length(final_response["choices"] || [])
          IO.puts("   Generated #{choices_count} choice(s)")
        end
    end

    IO.puts("\n🔄 Starting true dual model generation...")
    IO.puts("   - Streaming from model: #{streaming_client.model}")
    IO.puts("   - Final structured output from model: #{final_client.model}")
    IO.puts("   - Both running in parallel!\n")

    case LMStudio.generate_dual_models(streaming_client, final_client, request, stream_callback) do
      {:ok, %{streaming: streaming_result, final: final_result}} ->
        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("📊 DUAL GENERATION RESULTS")
        IO.puts(String.duplicate("=", 80))
        
        # Show streaming results
        IO.puts("\n🌊 STREAMING RESULTS (Model: #{streaming_result.model}):")
        case streaming_result.result do
          {:ok, %{streaming: true}} ->
            IO.puts("   ✅ Streaming completed successfully")
          {:error, reason} ->
            IO.puts("   ❌ Streaming failed: #{inspect(reason)}")
        end

        # Show final structured results
        IO.puts("\n🎯 FINAL STRUCTURED RESULTS (Model: #{final_result.model}):")
        case final_result.result do
          {:ok, %{choices: choices, usage: usage} = _response} ->
            IO.puts("   ✅ Generated #{length(choices)} structured response(s)")
            IO.puts("   📈 Usage: #{inspect(usage)}")
            
            # Show each choice with reasoning
            Enum.with_index(choices, 1)
            |> Enum.each(fn {choice, index} ->
              IO.puts("\n   📋 CHOICE #{index}:")
              IO.puts("      Finish reason: #{choice.finish_reason}")
              
              # Try to parse the JSON content for structured analysis
              content = choice.message["content"]
              case Jason.decode(content) do
                {:ok, parsed_json} ->
                  IO.puts("      ✅ Valid JSON structure:")
                  IO.puts("         Analysis: #{String.slice(parsed_json["analysis"] || "", 0, 100)}...")
                  IO.puts("         Complexity: #{parsed_json["complexity_score"]}/10")
                  IO.puts("         Steps: #{length(parsed_json["solution_steps"] || [])}")
                  IO.puts("         Confidence: #{parsed_json["confidence"]}")
                  
                  # Show reasoning from <think> tags if present
                  if String.contains?(content, "<think>") do
                    IO.puts("         🧠 Contains reasoning traces")
                  end
                  
                {:error, _} ->
                  IO.puts("      ⚠️  Non-JSON response (length: #{String.length(content)})")
                  IO.puts("         Preview: #{String.slice(content, 0, 200)}...")
              end
              
              # Show logprobs if available
              if choice[:logprobs] do
                IO.puts("      📊 Logprobs available for analysis")
              end
            end)
            
          {:error, reason} ->
            IO.puts("   ❌ Final generation failed: #{inspect(reason)}")
        end

        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("🎉 Demo completed! You can see results from both models running in parallel.")
        
      {:error, reason} ->
        IO.puts("❌ Dual model generation failed: #{inspect(reason)}")
    end
  end

  def run_simple_streaming_demo do
    IO.puts("\n🔄 Running Simple Streaming Demo...")
    
    client = LMStudio.new(
      base_url: "http://192.168.1.177:1234",
      model: "deepseek-r1-0528-qwen3-8b-mlx"
    )

    request = %{
      messages: [
        %{role: "user", content: "Explain machine learning in simple terms."}
      ],
      n: 2,
      logprobs: true
    }

    stream_callback = fn
      {:chunk, content} -> 
        # Only output clean content, not raw SSE data
        if String.printable?(content) and not String.contains?(content, "data: ") do
          IO.write(content)
        end
      {:done, _} -> IO.puts("\n✅ Stream done!")
    end

    LMStudio.generate_stream(client, request, stream_callback)
  end
end

# Run the demo
DualGenerationDemo.run_demo()

# Also run a simple streaming demo
DualGenerationDemo.run_simple_streaming_demo()