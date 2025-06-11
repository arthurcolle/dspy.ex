#!/usr/bin/env elixir

# Minimal Advanced DeepSeek Streaming Example
# Focuses on core advanced features without complex dependencies

Mix.install([
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

defmodule AdvancedDeepSeekMinimal do
  @moduledoc """
  Advanced streaming with reasoning extraction, multiple schemas, and analytics.
  """

  @base_url "http://192.168.1.177:1234"
  @model "deepseek-r1-0528-qwen3-8b-mlx"

  # Multiple schema types for different problem domains
  @schemas %{
    code_analysis: %{
      type: "object",
      properties: %{
        analysis: %{type: "string", description: "Technical analysis"},
        complexity_score: %{type: "number", minimum: 1, maximum: 10},
        solution_steps: %{type: "array", items: %{type: "string"}},
        code_snippets: %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              language: %{type: "string"},
              code: %{type: "string"},
              explanation: %{type: "string"}
            }
          }
        },
        risks: %{type: "array", items: %{type: "string"}},
        confidence: %{type: "number", minimum: 0, maximum: 1},
        estimated_time: %{type: "string"}
      },
      required: ["analysis", "complexity_score", "solution_steps", "confidence"]
    },
    
    scientific_analysis: %{
      type: "object",
      properties: %{
        hypothesis: %{type: "string"},
        methodology: %{type: "string"},
        experiments: %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              name: %{type: "string"},
              procedure: %{type: "string"},
              expected_outcome: %{type: "string"}
            }
          }
        },
        data_requirements: %{type: "array", items: %{type: "string"}},
        confidence: %{type: "number", minimum: 0, maximum: 1}
      },
      required: ["hypothesis", "methodology", "experiments", "confidence"]
    }
  }

  def run_advanced_demo do
    IO.puts("🚀 Advanced DeepSeek Streaming Analysis")
    IO.puts(String.duplicate("=", 50))
    IO.puts("Features: Reasoning extraction • Multiple schemas • Analytics")
    IO.puts("")

    scenarios = [
      %{
        type: :code_analysis,
        prompt: "Design a microservices architecture for a trading platform with high availability"
      },
      %{
        type: :scientific_analysis,
        prompt: "Design an experiment to test quantum computing effects on drug discovery"
      }
    ]

    analytics = init_analytics()

    Enum.with_index(scenarios, 1)
    |> Enum.each(fn {scenario, index} ->
      IO.puts("📊 Scenario #{index}: #{String.capitalize(to_string(scenario.type))}")
      IO.puts("🎯 #{scenario.prompt}")
      IO.puts("")
      
      result = process_scenario(scenario, analytics)
      display_results(result, index)
      
      if index < length(scenarios) do
        IO.puts("\n" <> String.duplicate("─", 40) <> "\n")
      end
    end)

    display_final_analytics(analytics)
  end

  defp process_scenario(scenario, analytics) do
    start_time = System.monotonic_time(:millisecond)
    
    schema = Map.get(@schemas, scenario.type)
    prompt = build_enhanced_prompt(scenario.prompt, schema, scenario.type)
    
    # Track streaming analytics
    {:ok, stream_pid} = Agent.start_link(fn -> %{
      chunks: [],
      reasoning_tokens: 0,
      json_tokens: 0,
      total_tokens: 0
    } end)

    case make_streaming_request(prompt, scenario.prompt, stream_pid) do
      {:ok, content} ->
        stream_data = Agent.get(stream_pid, & &1)
        Agent.stop(stream_pid)
        
        # Extract reasoning and JSON
        {reasoning, json_content} = extract_reasoning_and_json(content)
        
        # Validate response
        validation = validate_response(json_content, schema, reasoning)
        
        end_time = System.monotonic_time(:millisecond)
        total_time = end_time - start_time
        
        # Update analytics
        update_analytics(analytics, %{
          scenario_type: scenario.type,
          total_time: total_time,
          validation: validation,
          stream_data: stream_data,
          reasoning_quality: score_reasoning(reasoning)
        })
        
        %{
          success: true,
          scenario: scenario,
          reasoning: reasoning,
          structured_response: validation.parsed_json,
          validation: validation,
          total_time: total_time,
          stream_analytics: stream_data
        }
        
      {:error, reason} ->
        Agent.stop(stream_pid)
        %{success: false, error: reason, scenario: scenario}
    end
  end

  defp make_streaming_request(system_prompt, user_prompt, stream_pid) do
    url = "#{@base_url}/v1/chat/completions"
    
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "text/plain"}
    ]
    
    # Check if server is reachable first
    case HTTPoison.get("#{@base_url}/health", [], timeout: 3_000, recv_timeout: 3_000) do
      {:error, _} ->
        IO.puts("⚠️  Server not reachable at #{@base_url}. Using mock response...")
        return_mock_response(user_prompt)
      _ ->
        IO.puts("✅ Server is reachable, proceeding with request...")
        make_actual_request(url, system_prompt, user_prompt, headers, stream_pid)
    end
  end

  defp make_actual_request(url, system_prompt, user_prompt, headers, stream_pid) do
    body = %{
      model: @model,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ],
      temperature: 0.3,
      max_tokens: -1,
      stream: true  # Enable streaming
    }
    
    IO.puts("🌊 Processing request...")
    
    # Short timeout for first token, longer for subsequent ones
    case HTTPoison.post(url, Jason.encode!(body), headers, timeout: 30_000, recv_timeout: 300_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, response} ->
            content = get_in(response, ["choices", Access.at(0), "message", "content"])
            
            # Simulate streaming analytics
            chunks = split_into_chunks(content)
            Enum.each(chunks, fn chunk ->
              analyze_chunk(chunk, stream_pid)
              display_chunk_with_highlighting(chunk)
              Process.sleep(50)  # Simulate streaming delay
            end)
            
            {:ok, content}
            
          {:error, decode_error} ->
            {:error, {:json_decode_error, decode_error}}
        end
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, {:http_error, status_code, body}}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp return_mock_response(user_prompt) do
    mock_content = """
    <think>
    This is a mock response since the DeepSeek server is not available.
    For the prompt: #{String.slice(user_prompt, 0, 50)}...
    I need to provide a structured response that demonstrates the analysis capabilities.
    </think>
    
    {
      "analysis": "Mock analysis for demonstration purposes",
      "complexity_score": 7,
      "solution_steps": [
        "Step 1: Analyze requirements",
        "Step 2: Design architecture",
        "Step 3: Implement solution"
      ],
      "confidence": 0.8,
      "estimated_time": "2-3 weeks"
    }
    """
    
    {:ok, mock_content}
  end

  defp split_into_chunks(content) do
    # Split content into realistic streaming chunks
    words = String.split(content, " ")
    chunk_size = 8
    
    words
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(&Enum.join(&1, " "))
  end

  defp analyze_chunk(chunk, stream_pid) do
    Agent.update(stream_pid, fn state ->
      analysis = %{
        is_reasoning: String.contains?(chunk, ["<think>", "</think>", "reasoning", "analysis"]),
        is_json: String.contains?(chunk, ["{", "}", "[", "]", ":"]),
        word_count: chunk |> String.split() |> length()
      }
      
      %{state |
        chunks: state.chunks ++ [chunk],
        reasoning_tokens: state.reasoning_tokens + (if analysis.is_reasoning, do: analysis.word_count, else: 0),
        json_tokens: state.json_tokens + (if analysis.is_json, do: analysis.word_count, else: 0),
        total_tokens: state.total_tokens + analysis.word_count
      }
    end)
  end

  defp display_chunk_with_highlighting(chunk) do
    cond do
      String.contains?(chunk, ["<think>", "</think>"]) ->
        IO.write(IO.ANSI.blue() <> chunk <> " " <> IO.ANSI.reset())
        
      String.contains?(chunk, ["{", "}", "\":", "["]) ->
        IO.write(IO.ANSI.green() <> chunk <> " " <> IO.ANSI.reset())
        
      String.contains?(chunk, ["analysis", "hypothesis", "methodology"]) ->
        IO.write(IO.ANSI.yellow() <> chunk <> " " <> IO.ANSI.reset())
        
      true ->
        IO.write(chunk <> " ")
    end
  end

  defp build_enhanced_prompt(user_prompt, schema, scenario_type) do
    """
    You are an advanced AI assistant specializing in #{scenario_type |> to_string() |> String.replace("_", " ")}.

    INSTRUCTIONS:
    1. Show your reasoning using <think>...</think> tags
    2. After reasoning, provide valid JSON following the exact schema
    3. Be thorough in your analysis and consider multiple perspectives
    4. Include practical implementation details

    SCHEMA:
    #{Jason.encode!(schema, pretty: true)}

    TASK:
    #{user_prompt}

    FORMAT:
    <think>
    [Your detailed reasoning and analysis here]
    </think>
    
    {
      "your_json_response": "here"
    }
    """
  end

  defp extract_reasoning_and_json(content) do
    # Extract reasoning content
    reasoning_regex = ~r/<think>(.*?)<\/think>/s
    reasoning_matches = Regex.scan(reasoning_regex, content, capture: :all_but_first)
    reasoning = reasoning_matches |> Enum.map(&hd/1) |> Enum.join("\n") |> String.trim()
    
    # Extract JSON content (everything after </think>)
    json_content = case Regex.split(~r/<\/think>/, content, parts: 2) do
      [_, json_part] -> String.trim(json_part)
      [full_content] -> String.trim(full_content)
    end
    
    {reasoning, json_content}
  end

  defp validate_response(json_content, schema, reasoning) do
    case Jason.decode(json_content) do
      {:ok, parsed_json} ->
        schema_score = validate_schema_compliance(parsed_json, schema)
        reasoning_score = score_reasoning(reasoning)
        completeness_score = score_completeness(parsed_json, schema)
        
        overall_score = (schema_score + reasoning_score + completeness_score) / 3
        
        %{
          valid: true,
          parsed_json: parsed_json,
          schema_score: schema_score,
          reasoning_score: reasoning_score,
          completeness_score: completeness_score,
          overall_score: overall_score
        }
        
      {:error, decode_error} ->
        reasoning_score = score_reasoning(reasoning)
        %{
          valid: false,
          error: decode_error,
          raw_content: json_content,
          overall_score: 0,
          reasoning_score: reasoning_score,
          schema_score: 0,
          completeness_score: 0
        }
    end
  end

  defp validate_schema_compliance(json, schema) do
    required_fields = Map.get(schema, :required, [])
    properties = Map.get(schema, :properties, %{})
    
    # Check required fields
    missing_count = Enum.count(required_fields, fn field ->
      not Map.has_key?(json, to_string(field))
    end)
    
    # Check data types
    type_violations = Enum.count(properties, fn {field, spec} ->
      field_str = to_string(field)
      if Map.has_key?(json, field_str) do
        not valid_type?(Map.get(json, field_str), Map.get(spec, :type))
      else
        false
      end
    end)
    
    total_checks = length(required_fields) + map_size(properties)
    errors = missing_count + type_violations
    
    if total_checks == 0, do: 10, else: max(0, (total_checks - errors) / total_checks * 10)
  end

  defp valid_type?(value, "string"), do: is_binary(value)
  defp valid_type?(value, "number"), do: is_number(value)
  defp valid_type?(value, "array"), do: is_list(value)
  defp valid_type?(value, "object"), do: is_map(value)
  defp valid_type?(_value, _type), do: true

  defp score_reasoning(reasoning) do
    if String.trim(reasoning) == "" do
      0
    else
      word_count = reasoning |> String.split() |> length()
      
      # Quality indicators
      analysis_terms = ["analyze", "consider", "evaluate", "because", "therefore", "however"]
      depth_score = Enum.count(analysis_terms, &String.contains?(String.downcase(reasoning), &1))
      
      # Scoring formula
      word_score = min(word_count / 50, 5)  # Max 5 points for word count
      depth_score = min(depth_score * 0.8, 5)  # Max 5 points for depth indicators
      
      word_score + depth_score
    end
  end

  defp score_completeness(json, schema) do
    properties = Map.get(schema, :properties, %{})
    if map_size(properties) == 0, do: 10
    
    non_empty_fields = Enum.count(properties, fn {field, _spec} ->
      field_str = to_string(field)
      case Map.get(json, field_str) do
        nil -> false
        "" -> false
        [] -> false
        %{} -> false
        _ -> true
      end
    end)
    
    (non_empty_fields / map_size(properties)) * 10
  end

  defp display_results(result, scenario_index) do
    IO.puts("\n")
    
    case result do
      %{success: false, error: error} ->
        IO.puts("❌ Scenario #{scenario_index} failed: #{inspect(error)}")
        
      %{success: true} = result ->
        IO.puts("📈 Results for Scenario #{scenario_index}:")
        IO.puts("├─ Overall Score: #{Float.round(result.validation.overall_score, 2)}/10")
        IO.puts("├─ Schema Compliance: #{Float.round(result.validation.schema_score, 2)}/10")
        IO.puts("├─ Reasoning Quality: #{Float.round(result.validation.reasoning_score, 2)}/10")
        IO.puts("├─ Response Completeness: #{Float.round(result.validation.completeness_score, 2)}/10")
        IO.puts("├─ Processing Time: #{result.total_time}ms")
        IO.puts("└─ Stream Analytics:")
        IO.puts("   ├─ Total Tokens: #{result.stream_analytics.total_tokens}")
        IO.puts("   ├─ Reasoning Tokens: #{result.stream_analytics.reasoning_tokens}")
        IO.puts("   └─ JSON Tokens: #{result.stream_analytics.json_tokens}")
        
        # Display reasoning summary
        if result.reasoning != "" do
          reasoning_preview = String.slice(result.reasoning, 0, 100)
          IO.puts("\n🧠 Reasoning Preview:")
          IO.puts("   #{reasoning_preview}...")
        end
        
        # Display key structured response fields
        if result.structured_response do
          IO.puts("\n📋 Key Response Fields:")
          display_key_fields(result.structured_response, result.scenario.type)
        end
    end
  end

  defp display_key_fields(response, :code_analysis) do
    if Map.has_key?(response, "complexity_score") do
      IO.puts("   ├─ Complexity: #{response["complexity_score"]}/10")
    end
    if Map.has_key?(response, "confidence") do
      IO.puts("   ├─ Confidence: #{Float.round(response["confidence"] * 100, 1)}%")
    end
    if Map.has_key?(response, "solution_steps") and is_list(response["solution_steps"]) do
      IO.puts("   └─ Solution Steps: #{length(response["solution_steps"])} items")
    end
  end

  defp display_key_fields(response, :scientific_analysis) do
    if Map.has_key?(response, "hypothesis") do
      hypothesis = String.slice(response["hypothesis"], 0, 60)
      IO.puts("   ├─ Hypothesis: #{hypothesis}...")
    end
    if Map.has_key?(response, "experiments") and is_list(response["experiments"]) do
      IO.puts("   ├─ Experiments: #{length(response["experiments"])} planned")
    end
    if Map.has_key?(response, "confidence") do
      IO.puts("   └─ Confidence: #{Float.round(response["confidence"] * 100, 1)}%")
    end
  end

  defp init_analytics do
    Agent.start_link(fn -> %{
      scenarios_processed: 0,
      total_time: 0,
      average_score: 0,
      reasoning_quality_avg: 0,
      schema_compliance_avg: 0,
      results: []
    } end)
  end

  defp update_analytics({:ok, analytics_pid}, data) do
    Agent.update(analytics_pid, fn state ->
      new_results = state.results ++ [data]
      count = length(new_results)
      
      %{state |
        scenarios_processed: count,
        total_time: state.total_time + data.total_time,
        results: new_results,
        average_score: calculate_average(new_results, fn r -> r.validation.overall_score end),
        reasoning_quality_avg: calculate_average(new_results, fn r -> r.validation.reasoning_score end),
        schema_compliance_avg: calculate_average(new_results, fn r -> r.validation.schema_score end)
      }
    end)
  end
  defp update_analytics(_, _), do: :ok

  defp calculate_average(results, extractor_fn) do
    if length(results) == 0, do: 0
    
    sum = results |> Enum.map(extractor_fn) |> Enum.sum()
    sum / length(results)
  end

  defp display_final_analytics({:ok, analytics_pid}) do
    state = Agent.get(analytics_pid, & &1)
    
    IO.puts("\n" <> "=" |> String.duplicate(50))
    IO.puts("📊 ANALYTICS SUMMARY")
    IO.puts(String.duplicate("=", 50))
    
    IO.puts("🎯 Performance Metrics:")
    IO.puts("├─ Scenarios Processed: #{state.scenarios_processed}")
    IO.puts("├─ Total Processing Time: #{state.total_time}ms")
    IO.puts("├─ Average Overall Score: #{if is_float(state.average_score), do: Float.round(state.average_score, 2), else: state.average_score}/10")
    IO.puts("├─ Average Reasoning Quality: #{if is_float(state.reasoning_quality_avg), do: Float.round(state.reasoning_quality_avg, 2), else: state.reasoning_quality_avg}/10")
    IO.puts("└─ Average Schema Compliance: #{if is_float(state.schema_compliance_avg), do: Float.round(state.schema_compliance_avg, 2), else: state.schema_compliance_avg}/10")
    
    # Performance by scenario type
    performance_by_type = state.results
    |> Enum.group_by(& &1.scenario_type)
    |> Enum.map(fn {type, results} ->
      avg_score = calculate_average(results, fn r -> r.validation.overall_score end)
      avg_time = calculate_average(results, fn r -> r.total_time end)
      {type, %{avg_score: avg_score, avg_time: avg_time}}
    end)
    
    if length(performance_by_type) > 0 do
      IO.puts("\n📈 Performance by Type:")
      Enum.each(performance_by_type, fn {type, stats} ->
        IO.puts("├─ #{String.capitalize(to_string(type))}: #{Float.round(stats.avg_score, 2)}/10 (#{Float.round(stats.avg_time, 0)}ms)")
      end)
    end
    
    Agent.stop(analytics_pid)
  end
  defp display_final_analytics(_), do: :ok
end

# Run the demo
AdvancedDeepSeekMinimal.run_advanced_demo()

IO.puts("\n🎯 Advanced Features Demonstrated:")
IO.puts("- ✅ Reasoning token extraction and analysis")
IO.puts("- ✅ Multiple schema types for different domains")
IO.puts("- ✅ Real-time streaming simulation with analytics")
IO.puts("- ✅ Comprehensive response validation and scoring")
IO.puts("- ✅ Performance metrics and analytics")
IO.puts("- ✅ Color-coded streaming output")
IO.puts("- ✅ Schema compliance checking")