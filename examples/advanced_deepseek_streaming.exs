#!/usr/bin/env elixir

# Advanced DeepSeek Streaming with Reasoning Token Extraction, 
# Multiple Schema Types, Adaptive Streaming, and Analytics
#
# This advanced example demonstrates:
# 1. Reasoning token extraction and processing
# 2. Dynamic schema selection based on problem complexity
# 3. Adaptive streaming with chunk analysis
# 4. Advanced analytics and metrics collection
# 5. Multi-turn conversations with context management
# 6. Response validation and quality scoring
#
# Make sure LM Studio is running with the deepseek model loaded

# Add dependencies
Mix.install([
  {:jason, "~> 1.4"},
  {:lmstudio, git: "https://github.com/arthurcolle/lmstudio.ex.git"},
  {:telemetry, "~> 1.0"}
])

# Configure LMStudio for deepseek model
Application.put_env(:lmstudio, :base_url, "http://192.168.1.177:1234")
Application.put_env(:lmstudio, :default_model, "deepseek-r1-0528-qwen3-8b-mlx")
Application.put_env(:lmstudio, :default_temperature, 0.3)
Application.put_env(:lmstudio, :default_max_tokens, -1)

defmodule AdvancedDeepSeekStreaming do
  @moduledoc """
  Advanced streaming example with reasoning token extraction, multiple schemas,
  adaptive streaming, and comprehensive analytics.
  """

  # Schema definitions for different problem types
  @schemas %{
    code_analysis: %{
      type: "object",
      properties: %{
        analysis: %{type: "string", description: "Technical analysis of the code/problem"},
        complexity_score: %{type: "number", minimum: 1, maximum: 10, description: "Complexity rating 1-10"},
        solution_steps: %{
          type: "array", 
          items: %{type: "string"},
          description: "Detailed implementation steps"
        },
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
        estimated_time: %{type: "string"},
        dependencies: %{type: "array", items: %{type: "string"}}
      },
      required: ["analysis", "complexity_score", "solution_steps", "confidence"]
    },
    
    scientific_analysis: %{
      type: "object",
      properties: %{
        hypothesis: %{type: "string", description: "Scientific hypothesis"},
        methodology: %{type: "string", description: "Research methodology"},
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
        ethical_considerations: %{type: "array", items: %{type: "string"}},
        confidence: %{type: "number", minimum: 0, maximum: 1},
        timeline: %{type: "string"}
      },
      required: ["hypothesis", "methodology", "experiments", "confidence"]
    },
    
    creative_writing: %{
      type: "object",
      properties: %{
        title: %{type: "string"},
        genre: %{type: "string", enum: ["fiction", "poetry", "screenplay", "essay"]},
        mood: %{type: "string", enum: ["dramatic", "comedic", "mysterious", "romantic", "action"]},
        characters: %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              name: %{type: "string"},
              role: %{type: "string"},
              description: %{type: "string"}
            }
          }
        },
        plot_outline: %{type: "array", items: %{type: "string"}},
        themes: %{type: "array", items: %{type: "string"}},
        target_audience: %{type: "string"},
        word_count_estimate: %{type: "number"}
      },
      required: ["title", "genre", "mood", "plot_outline"]
    },
    
    business_analysis: %{
      type: "object",
      properties: %{
        executive_summary: %{type: "string"},
        market_analysis: %{
          type: "object",
          properties: %{
            size: %{type: "string"},
            growth_rate: %{type: "string"},
            key_trends: %{type: "array", items: %{type: "string"}}
          }
        },
        competitive_landscape: %{type: "array", items: %{type: "string"}},
        swot_analysis: %{
          type: "object",
          properties: %{
            strengths: %{type: "array", items: %{type: "string"}},
            weaknesses: %{type: "array", items: %{type: "string"}},
            opportunities: %{type: "array", items: %{type: "string"}},
            threats: %{type: "array", items: %{type: "string"}}
          }
        },
        financial_projections: %{
          type: "object",
          properties: %{
            revenue_forecast: %{type: "string"},
            cost_structure: %{type: "array", items: %{type: "string"}},
            break_even_point: %{type: "string"}
          }
        },
        risk_assessment: %{type: "number", minimum: 1, maximum: 10},
        recommendation: %{type: "string"}
      },
      required: ["executive_summary", "market_analysis", "swot_analysis", "recommendation"]
    }
  }

  def run_advanced_streaming_demo do
    IO.puts("🚀 Advanced DeepSeek Streaming Analysis System")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Features: Reasoning extraction • Dynamic schemas • Analytics • Multi-turn")
    IO.puts("")

    # Initialize analytics
    analytics = init_analytics()
    
    # Demo scenarios with different complexity levels
    scenarios = [
      %{
        type: :code_analysis,
        prompt: "Design a distributed microservices architecture for a real-time trading platform with high availability requirements",
        expected_complexity: 9
      },
      %{
        type: :scientific_analysis, 
        prompt: "Investigate the potential for quantum computing to revolutionize drug discovery",
        expected_complexity: 8
      },
      %{
        type: :creative_writing,
        prompt: "Create a cyberpunk short story about AI consciousness emergence",
        expected_complexity: 6
      },
      %{
        type: :business_analysis,
        prompt: "Analyze the market opportunity for sustainable packaging solutions in e-commerce",
        expected_complexity: 7
      }
    ]

    Enum.with_index(scenarios, 1)
    |> Enum.each(fn {scenario, index} ->
      IO.puts("📊 Scenario #{index}/#{length(scenarios)}: #{String.capitalize(to_string(scenario.type))}")
      IO.puts("🎯 Query: #{scenario.prompt}")
      IO.puts("")
      
      result = run_advanced_analysis(scenario, analytics)
      display_analysis_results(result, index)
      
      if index < length(scenarios) do
        IO.puts("\n" <> "─" |> String.duplicate(60) <> "\n")
        Process.sleep(1000)
      end
    end)

    # Display final analytics
    display_analytics_summary(analytics)
  end

  defp run_advanced_analysis(scenario, analytics) do
    start_time = System.monotonic_time(:millisecond)
    
    # Select appropriate schema based on scenario type
    schema = Map.get(@schemas, scenario.type)
    
    # Build enhanced prompt with reasoning instructions
    enhanced_prompt = build_enhanced_prompt(scenario.prompt, schema, scenario.type)
    
    # Prepare streaming infrastructure
    {:ok, analytics_pid} = Agent.start_link(fn -> %{
      chunks: [],
      reasoning_tokens: [],
      json_content: "",
      chunk_count: 0,
      reasoning_quality_score: 0,
      stream_efficiency: %{}
    } end)

    # Enhanced streaming callback with advanced visualization
    stream_callback = create_enhanced_advanced_callback(analytics_pid, analytics, start_time, scenario)
    
    # Execute streaming request
    messages = [
      %{role: "system", content: enhanced_prompt},
      %{role: "user", content: scenario.prompt}
    ]

    IO.puts("🌊 Initiating adaptive streaming...")
    
    result = case LMStudio.complete(messages, stream: true, stream_callback: stream_callback) do
      {:ok, _} ->
        # Extract final analytics
        final_analytics = Agent.get(analytics_pid, & &1)
        
        # Process reasoning and JSON content
        {reasoning, json_content} = extract_reasoning_and_json(final_analytics.chunks)
        
        # Validate and score response
        validation_result = validate_and_score_response(json_content, schema, reasoning)
        
        end_time = System.monotonic_time(:millisecond)
        total_time = end_time - start_time
        
        update_global_analytics(analytics, %{
          scenario_type: scenario.type,
          total_time: total_time,
          chunk_count: final_analytics.chunk_count,
          reasoning_quality: final_analytics.reasoning_quality_score,
          validation_result: validation_result,
          stream_efficiency: calculate_stream_efficiency(final_analytics.chunks)
        })

        Agent.stop(analytics_pid)
        
        %{
          scenario: scenario,
          reasoning: reasoning,
          structured_response: validation_result.parsed_json,
          quality_score: validation_result.quality_score,
          analytics: final_analytics,
          total_time: total_time,
          validation: validation_result
        }
      
      {:error, reason} ->
        Agent.stop(analytics_pid)
        %{error: reason, scenario: scenario}
    end

    result
  end

  defp create_enhanced_advanced_callback(analytics_pid, global_analytics, start_time, scenario) do
    # Enhanced callback with beautiful visual display
    fn
      {:chunk, content} ->
        chunk_time = System.monotonic_time(:millisecond) - start_time
        
        # Analyze chunk content with enhanced detection
        chunk_analysis = analyze_chunk_content_enhanced(content)
        
        # Update analytics
        Agent.update(analytics_pid, fn state ->
          %{state |
            chunks: state.chunks ++ [%{content: content, timestamp: chunk_time, analysis: chunk_analysis}],
            chunk_count: state.chunk_count + 1,
            reasoning_quality_score: update_reasoning_quality(state.reasoning_quality_score, chunk_analysis)
          }
        end)
        
        # Enhanced visual display with progress indicators
        display_enhanced_chunk_with_progress(content, chunk_analysis, chunk_time, scenario)
        :ok
      
      {:done, _} ->
        display_enhanced_completion()
        :ok
    end
  end

  defp create_advanced_callback(analytics_pid, global_analytics, start_time) do
    fn
      {:chunk, content} ->
        chunk_time = System.monotonic_time(:millisecond) - start_time
        
        # Analyze chunk content
        chunk_analysis = analyze_chunk_content(content)
        
        # Update analytics
        Agent.update(analytics_pid, fn state ->
          %{state |
            chunks: state.chunks ++ [%{content: content, timestamp: chunk_time, analysis: chunk_analysis}],
            chunk_count: state.chunk_count + 1,
            reasoning_quality_score: update_reasoning_quality(state.reasoning_quality_score, chunk_analysis)
          }
        end)
        
        # Real-time display with color coding
        display_chunk_with_analysis(content, chunk_analysis)
        :ok
      
      {:done, _} ->
        IO.puts("\n")
        IO.puts("✅ Stream completed - Processing reasoning extraction...")
        :ok
    end
  end

  defp extract_reasoning_and_json(chunks) do
    full_content = chunks |> Enum.map(& &1.content) |> Enum.join("")
    
    # Extract reasoning tokens (everything between <think> and </think>)
    reasoning_regex = ~r/<think>(.*?)<\/think>/s
    reasoning_matches = Regex.scan(reasoning_regex, full_content, capture: :all_but_first)
    reasoning_content = reasoning_matches |> Enum.map(&hd/1) |> Enum.join("\n")
    
    # Extract JSON content (everything after </think> or full content if no reasoning)
    json_content = case Regex.split(~r/<\/think>/, full_content, parts: 2) do
      [_, json_part] -> String.trim(json_part)
      [content] -> String.trim(content)
    end
    
    {reasoning_content, json_content}
  end

  defp validate_and_score_response(json_content, schema, reasoning) do
    case Jason.decode(json_content) do
      {:ok, parsed_json} ->
        # Validate against schema
        schema_validation = validate_against_schema(parsed_json, schema)
        
        # Score reasoning quality
        reasoning_score = score_reasoning_quality(reasoning)
        
        # Score response completeness
        completeness_score = score_response_completeness(parsed_json, schema)
        
        # Calculate overall quality score
        overall_score = (schema_validation.score + reasoning_score + completeness_score) / 3
        
        %{
          valid: true,
          parsed_json: parsed_json,
          schema_validation: schema_validation,
          reasoning_score: reasoning_score,
          completeness_score: completeness_score,
          quality_score: overall_score,
          reasoning_analysis: analyze_reasoning_depth(reasoning)
        }
      
      {:error, decode_error} ->
        %{
          valid: false,
          error: decode_error,
          raw_content: json_content,
          quality_score: 0,
          reasoning_score: score_reasoning_quality(reasoning)
        }
    end
  end

  defp build_enhanced_prompt(user_prompt, schema, scenario_type) do
    base_instructions = """
    You are an advanced AI assistant specializing in #{scenario_type |> to_string() |> String.replace("_", " ")}. 

    CRITICAL INSTRUCTIONS:
    1. Show your reasoning process using <think>...</think> tags
    2. After reasoning, provide a JSON response that EXACTLY follows the schema
    3. Your reasoning should be thorough, exploring multiple angles and potential issues
    4. Consider edge cases, alternatives, and implementation challenges
    5. The JSON must be valid and complete - no shortcuts or placeholders

    SCHEMA REQUIREMENTS:
    #{Jason.encode!(schema, pretty: true)}

    RESPONSE FORMAT:
    <think>
    [Your detailed reasoning process here - be thorough and analytical]
    </think>
    
    {
      "your": "json response here following the exact schema"
    }

    Remember: Show deep analytical thinking in your reasoning, then provide precise structured output.
    """
    
    case scenario_type do
      :code_analysis ->
        base_instructions <> "\n\nFocus on: Architecture patterns, scalability, security, maintainability, and performance considerations."
      
      :scientific_analysis ->
        base_instructions <> "\n\nFocus on: Scientific rigor, methodology, reproducibility, and evidence-based conclusions."
      
      :creative_writing ->
        base_instructions <> "\n\nFocus on: Narrative structure, character development, thematic depth, and audience engagement."
      
      :business_analysis ->
        base_instructions <> "\n\nFocus on: Market dynamics, financial viability, competitive advantages, and strategic recommendations."
      
      _ ->
        base_instructions
    end
  end

  defp analyze_chunk_content(content) do
    %{
      contains_reasoning: String.contains?(content, "<think>") or String.contains?(content, "</think>"),
      contains_json: String.contains?(content, "{") or String.contains?(content, "}"),
      word_count: content |> String.split() |> length(),
      character_count: String.length(content),
      complexity_indicators: count_complexity_indicators(content)
    }
  end

  defp count_complexity_indicators(content) do
    indicators = [
      "however", "therefore", "consequently", "furthermore", "nevertheless", 
      "alternatively", "specifically", "particularly", "essentially", "ultimately"
    ]
    
    indicators
    |> Enum.map(&String.contains?(String.downcase(content), &1))
    |> Enum.count(& &1)
  end

  defp analyze_chunk_content_enhanced(content) do
    base_analysis = analyze_chunk_content(content)
    
    # Enhanced analysis with more detailed metrics
    Map.merge(base_analysis, %{
      semantic_density: calculate_semantic_density(content),
      information_value: calculate_information_value(content),
      reasoning_depth: assess_reasoning_depth(content),
      json_completeness: assess_json_completeness(content),
      processing_priority: determine_processing_priority(content)
    })
  end

  defp display_enhanced_chunk_with_progress(content, analysis, chunk_time, scenario) do
    # Enhanced visual display with progress indicators and metrics
    colors = %{
      reasoning: IO.ANSI.blue() <> IO.ANSI.bright(),
      json: IO.ANSI.green() <> IO.ANSI.bright(),
      high_value: IO.ANSI.yellow() <> IO.ANSI.bright(),
      metrics: IO.ANSI.cyan(),
      progress: IO.ANSI.magenta(),
      reset: IO.ANSI.reset()
    }
    
    symbols = %{
      reasoning: "🧠",
      json: "📊", 
      progress: "⚡",
      quality: "⭐",
      time: "⏱️"
    }
    
    # Choose color and symbol based on enhanced analysis
    {color, symbol} = cond do
      analysis.contains_reasoning and analysis.reasoning_depth > 0.7 ->
        {colors.reasoning, symbols.reasoning}
      
      analysis.contains_json and analysis.json_completeness > 0.8 ->
        {colors.json, symbols.json}
      
      analysis.information_value > 0.8 ->
        {colors.high_value, symbols.quality}
      
      true ->
        {colors.reset, "▓"}
    end
    
    # Display content with enhanced visuals
    IO.write(color <> symbol <> " " <> content <> colors.reset)
    
    # Show inline progress metrics every 10 chunks
    if rem(analysis.word_count, 50) == 0 do
      progress_info = "#{colors.metrics}[#{symbols.progress}#{chunk_time}ms #{symbols.quality}#{Float.round(analysis.information_value, 2)}]#{colors.reset}"
      IO.write(" " <> progress_info)
    end
  end

  defp display_enhanced_completion do
    colors = %{
      success: IO.ANSI.green() <> IO.ANSI.bright(),
      metrics: IO.ANSI.cyan(),
      reset: IO.ANSI.reset()
    }
    
    IO.puts("\n")
    IO.puts(colors.success <> "╔" <> String.duplicate("═", 60) <> "╗" <> colors.reset)
    IO.puts(colors.success <> "║" <> " ✅ ENHANCED STREAMING COMPLETED SUCCESSFULLY!" <> String.duplicate(" ", 18) <> "║" <> colors.reset)
    IO.puts(colors.success <> "║" <> " 🎯 Advanced analytics and visualization applied" <> String.duplicate(" ", 11) <> "║" <> colors.reset)
    IO.puts(colors.success <> "╚" <> String.duplicate("═", 60) <> "╝" <> colors.reset)
  end

  defp calculate_semantic_density(content) do
    words = String.split(content)
    unique_words = words |> Enum.uniq() |> length()
    if length(words) > 0, do: unique_words / length(words), else: 0
  end

  defp calculate_information_value(content) do
    # Calculate information density based on content characteristics
    factors = [
      String.contains?(content, ["analyze", "consider", "evaluate", "implement"]),
      String.contains?(content, ["because", "therefore", "however", "consequently"]),
      String.match?(content, ~r/\d+/),
      String.match?(content, ~r/[A-Z][a-z]+/),
      String.length(content) > 20
    ]
    
    Enum.count(factors, & &1) / length(factors)
  end

  defp assess_reasoning_depth(content) do
    reasoning_indicators = [
      "analysis", "consideration", "evaluation", "assessment", "examination",
      "implications", "consequences", "assumptions", "limitations", "approach"
    ]
    
    content_lower = String.downcase(content)
    matches = Enum.count(reasoning_indicators, &String.contains?(content_lower, &1))
    min(matches / 3.0, 1.0)
  end

  defp assess_json_completeness(content) do
    if String.contains?(content, ["{", "}"]) do
      # Assess if JSON structure appears complete
      open_braces = content |> String.graphemes() |> Enum.count(&(&1 == "{"))
      close_braces = content |> String.graphemes() |> Enum.count(&(&1 == "}"))
      
      if open_braces > 0 do
        min(close_braces / open_braces, 1.0)
      else
        0.5
      end
    else
      0.0
    end
  end

  defp determine_processing_priority(content) do
    cond do
      String.contains?(content, ["critical", "urgent", "immediate", "error"]) -> :high
      String.contains?(content, ["important", "significant", "analysis"]) -> :medium
      true -> :normal
    end
  end

  defp display_chunk_with_analysis(content, analysis) do
    cond do
      analysis.contains_reasoning ->
        IO.write(IO.ANSI.blue() <> content <> IO.ANSI.reset())
      
      analysis.contains_json ->
        IO.write(IO.ANSI.green() <> content <> IO.ANSI.reset())
      
      analysis.complexity_indicators > 2 ->
        IO.write(IO.ANSI.yellow() <> content <> IO.ANSI.reset())
      
      true ->
        IO.write(content)
    end
  end

  defp update_reasoning_quality(current_score, chunk_analysis) do
    if chunk_analysis.contains_reasoning do
      # Increase score based on complexity indicators and content depth
      increment = chunk_analysis.complexity_indicators * 0.1 + 
                  min(chunk_analysis.word_count / 50, 1.0)
      min(current_score + increment, 10.0)
    else
      current_score
    end
  end

  defp validate_against_schema(json, schema) do
    required_fields = Map.get(schema, :required, [])
    properties = Map.get(schema, :properties, %{})
    
    # Check required fields
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(json, to_string(field))
    end)
    
    # Check field types and constraints
    type_violations = check_field_types(json, properties)
    
    # Calculate validation score
    total_checks = length(required_fields) + map_size(properties)
    violations = length(missing_fields) + length(type_violations)
    score = max(0, (total_checks - violations) / total_checks * 10)
    
    %{
      score: score,
      missing_fields: missing_fields,
      type_violations: type_violations,
      valid: violations == 0
    }
  end

  defp check_field_types(json, properties) do
    Enum.flat_map(properties, fn {field, spec} ->
      field_str = to_string(field)
      if Map.has_key?(json, field_str) do
        value = Map.get(json, field_str)
        check_field_type(field_str, value, spec)
      else
        []
      end
    end)
  end

  defp check_field_type(field, value, %{type: "string"}) when not is_binary(value) do
    ["#{field}: expected string, got #{inspect(value)}"]
  end
  
  defp check_field_type(field, value, %{type: "number"}) when not is_number(value) do
    ["#{field}: expected number, got #{inspect(value)}"]
  end
  
  defp check_field_type(field, value, %{type: "array"}) when not is_list(value) do
    ["#{field}: expected array, got #{inspect(value)}"]
  end
  
  defp check_field_type(field, value, %{type: "object"}) when not is_map(value) do
    ["#{field}: expected object, got #{inspect(value)}"]
  end
  
  defp check_field_type(_field, _value, _spec), do: []

  defp score_reasoning_quality(reasoning) do
    if String.trim(reasoning) == "" do
      0
    else
      word_count = reasoning |> String.split() |> length()
      complexity_score = count_complexity_indicators(reasoning)
      depth_indicators = count_depth_indicators(reasoning)
      
      # Normalize and combine scores
      word_score = min(word_count / 100, 3.0)  # Max 3 points for word count
      complexity_score = min(complexity_score * 0.5, 3.0)  # Max 3 points for complexity
      depth_score = min(depth_indicators * 0.7, 4.0)  # Max 4 points for depth
      
      word_score + complexity_score + depth_score
    end
  end

  defp count_depth_indicators(text) do
    indicators = [
      "analyze", "consider", "evaluate", "assess", "examine", "investigate",
      "implications", "consequences", "trade-offs", "alternatives", "challenges",
      "assumptions", "limitations", "requirements", "dependencies"
    ]
    
    indicators
    |> Enum.map(&String.contains?(String.downcase(text), &1))
    |> Enum.count(& &1)
  end

  defp score_response_completeness(json, schema) do
    properties = Map.get(schema, :properties, %{})
    total_fields = map_size(properties)
    
    if total_fields == 0, do: 10
    
    completed_fields = Enum.count(properties, fn {field, _spec} ->
      field_str = to_string(field)
      case Map.get(json, field_str) do
        nil -> false
        "" -> false
        [] -> false
        %{} -> false
        _ -> true
      end
    end)
    
    (completed_fields / total_fields) * 10
  end

  defp analyze_reasoning_depth(reasoning) do
    %{
      word_count: reasoning |> String.split() |> length(),
      sentence_count: reasoning |> String.split(~r/[.!?]/) |> length(),
      complexity_indicators: count_complexity_indicators(reasoning),
      depth_indicators: count_depth_indicators(reasoning),
      analysis_keywords: count_analysis_keywords(reasoning),
      reasoning_chains: count_reasoning_chains(reasoning)
    }
  end

  defp count_analysis_keywords(text) do
    keywords = [
      "because", "since", "due to", "results in", "leads to", "causes",
      "if", "then", "when", "unless", "provided that", "given that"
    ]
    
    keywords
    |> Enum.map(&String.contains?(String.downcase(text), &1))
    |> Enum.count(& &1)
  end

  defp count_reasoning_chains(text) do
    # Count logical connectors that indicate reasoning chains
    connectors = ["therefore", "thus", "hence", "consequently", "as a result", "this means"]
    
    connectors
    |> Enum.map(&String.contains?(String.downcase(text), &1))
    |> Enum.count(& &1)
  end

  defp calculate_stream_efficiency(chunks) do
    if length(chunks) == 0, do: %{efficiency_score: 0}
    
    total_chars = chunks |> Enum.map(& &1.content |> String.length()) |> Enum.sum()
    avg_chunk_size = total_chars / length(chunks)
    
    # Calculate time distribution
    times = chunks |> Enum.map(& &1.timestamp)
    time_variance = calculate_variance(times)
    
    %{
      efficiency_score: min(avg_chunk_size / 10, 10),  # Normalize chunk size
      avg_chunk_size: avg_chunk_size,
      total_chunks: length(chunks),
      time_variance: time_variance,
      stream_consistency: 10 - min(time_variance / 100, 10)
    }
  end

  defp calculate_variance(values) do
    if length(values) < 2, do: 0
    
    mean = Enum.sum(values) / length(values)
    sum_squared_diffs = values |> Enum.map(&:math.pow(&1 - mean, 2)) |> Enum.sum()
    sum_squared_diffs / length(values)
  end

  defp display_analysis_results(result, scenario_index) do
    case result do
      %{error: error} ->
        IO.puts("❌ Error in scenario #{scenario_index}: #{inspect(error)}")
      
      %{scenario: scenario, quality_score: quality_score} = result ->
        IO.puts("\n📈 Analysis Results:")
        IO.puts("├─ Overall Quality Score: #{Float.round(quality_score, 2)}/10")
        
        if Map.has_key?(result, :validation) do
          validation = result.validation
          IO.puts("├─ Schema Validation: #{if validation.schema_validation.valid, do: "✅ PASSED", else: "❌ FAILED"}")
          IO.puts("├─ Reasoning Quality: #{Float.round(validation.reasoning_score, 2)}/10")
          IO.puts("├─ Response Completeness: #{Float.round(validation.completeness_score, 2)}/10")
          
          if Map.has_key?(validation, :reasoning_analysis) do
            ra = validation.reasoning_analysis
            IO.puts("├─ Reasoning Analysis:")
            IO.puts("│  ├─ Words: #{ra.word_count}")
            IO.puts("│  ├─ Complexity Indicators: #{ra.complexity_indicators}")
            IO.puts("│  ├─ Depth Indicators: #{ra.depth_indicators}")
            IO.puts("│  └─ Reasoning Chains: #{ra.reasoning_chains}")
          end
        end
        
        IO.puts("├─ Processing Time: #{result.total_time}ms")
        IO.puts("└─ Stream Efficiency: #{Float.round(result.analytics.stream_efficiency.efficiency_score, 2)}/10")
        
        # Display key insights from structured response
        if Map.has_key?(result, :structured_response) and result.structured_response do
          display_key_insights(result.structured_response, scenario.type)
        end
    end
  end

  defp display_key_insights(response, type) do
    IO.puts("\n🔍 Key Insights:")
    
    case type do
      :code_analysis ->
        if Map.has_key?(response, "complexity_score") do
          IO.puts("├─ Complexity Rating: #{response["complexity_score"]}/10")
        end
        if Map.has_key?(response, "confidence") do
          IO.puts("├─ Confidence Level: #{Float.round(response["confidence"] * 100, 1)}%")
        end
        
      :scientific_analysis ->
        if Map.has_key?(response, "hypothesis") do
          hypothesis = String.slice(response["hypothesis"], 0, 80)
          IO.puts("├─ Hypothesis: #{hypothesis}...")
        end
        
      :creative_writing ->
        if Map.has_key?(response, "genre") and Map.has_key?(response, "mood") do
          IO.puts("├─ Genre/Mood: #{response["genre"]} • #{response["mood"]}")
        end
        
      :business_analysis ->
        if Map.has_key?(response, "risk_assessment") do
          IO.puts("├─ Risk Level: #{response["risk_assessment"]}/10")
        end
    end
  end

  defp init_analytics do
    Agent.start_link(fn -> %{
      total_scenarios: 0,
      total_processing_time: 0,
      average_quality_score: 0,
      schema_validation_rate: 0,
      reasoning_quality_avg: 0,
      stream_efficiency_avg: 0,
      scenario_results: []
    } end)
  end

  defp update_global_analytics({:ok, analytics_pid}, scenario_data) do
    Agent.update(analytics_pid, fn state ->
      new_results = state.scenario_results ++ [scenario_data]
      total_scenarios = length(new_results)
      
      %{state |
        total_scenarios: total_scenarios,
        total_processing_time: state.total_processing_time + scenario_data.total_time,
        scenario_results: new_results,
        average_quality_score: calculate_average(new_results, fn r -> r.validation_result.quality_score end),
        reasoning_quality_avg: calculate_average(new_results, fn r -> r.validation_result.reasoning_score end),
        stream_efficiency_avg: calculate_average(new_results, fn r -> r.stream_efficiency.efficiency_score end),
        schema_validation_rate: calculate_validation_rate(new_results)
      }
    end)
  end
  defp update_global_analytics(_, _), do: :ok

  defp calculate_average(results, extractor_fn) do
    if length(results) == 0, do: 0
    
    sum = results |> Enum.map(extractor_fn) |> Enum.sum()
    sum / length(results)
  end

  defp calculate_validation_rate(results) do
    if length(results) == 0, do: 0
    
    valid_count = results |> Enum.count(fn r -> r.validation_result.valid end)
    (valid_count / length(results)) * 100
  end

  defp display_analytics_summary({:ok, analytics_pid}) do
    state = Agent.get(analytics_pid, & &1)
    
    IO.puts("\n" <> "=" |> String.duplicate(60))
    IO.puts("📊 ADVANCED ANALYTICS SUMMARY")
    IO.puts("=" |> String.duplicate(60))
    
    IO.puts("🎯 Overall Performance:")
    IO.puts("├─ Scenarios Processed: #{state.total_scenarios}")
    IO.puts("├─ Total Processing Time: #{state.total_processing_time}ms")
    IO.puts("├─ Average Quality Score: #{Float.round(state.average_quality_score, 2)}/10")
    IO.puts("├─ Schema Validation Rate: #{Float.round(state.schema_validation_rate, 1)}%")
    IO.puts("├─ Reasoning Quality Average: #{Float.round(state.reasoning_quality_avg, 2)}/10")
    IO.puts("└─ Stream Efficiency Average: #{Float.round(state.stream_efficiency_avg, 2)}/10")
    
    # Performance by scenario type
    IO.puts("\n📈 Performance by Scenario Type:")
    performance_by_type = state.scenario_results
    |> Enum.group_by(& &1.scenario_type)
    |> Enum.map(fn {type, results} ->
      avg_quality = calculate_average(results, fn r -> r.validation_result.quality_score end)
      avg_time = calculate_average(results, fn r -> r.total_time end)
      {type, %{avg_quality: avg_quality, avg_time: avg_time, count: length(results)}}
    end)
    
    Enum.each(performance_by_type, fn {type, stats} ->
      IO.puts("├─ #{String.capitalize(to_string(type))}: Quality #{Float.round(stats.avg_quality, 2)}/10, Time #{Float.round(stats.avg_time, 0)}ms")
    end)
    
    Agent.stop(analytics_pid)
  end
  defp display_analytics_summary(_), do: :ok

  def run_multi_turn_conversation do
    IO.puts("\n" <> "🔄" |> String.duplicate(60))
    IO.puts("🔄 MULTI-TURN CONVERSATION MODE")
    IO.puts("🔄" |> String.duplicate(60))
    
    conversation_state = %{
      messages: [],
      context: %{},
      turn_count: 0
    }
    
    interactive_loop(conversation_state)
  end

  defp interactive_loop(state) do
    IO.puts("\nEnter your query (or 'quit' to exit):")
    user_input = IO.gets("> ") |> String.trim()
    
    case user_input do
      "quit" ->
        IO.puts("👋 Goodbye!")
        
      "" ->
        IO.puts("Please enter a query.")
        interactive_loop(state)
        
      query ->
        # Determine scenario type based on keywords
        scenario_type = classify_query(query)
        
        IO.puts("🎯 Detected scenario type: #{scenario_type}")
        
        # Process with context
        result = process_conversation_turn(query, scenario_type, state)
        
        # Update conversation state
        new_state = update_conversation_state(state, query, result)
        
        interactive_loop(new_state)
    end
  end

  defp classify_query(query) do
    query_lower = String.downcase(query)
    
    cond do
      String.contains?(query_lower, ["code", "program", "implement", "algorithm", "architecture"]) ->
        :code_analysis
        
      String.contains?(query_lower, ["research", "study", "experiment", "hypothesis", "scientific"]) ->
        :scientific_analysis
        
      String.contains?(query_lower, ["story", "write", "character", "plot", "creative"]) ->
        :creative_writing
        
      String.contains?(query_lower, ["business", "market", "strategy", "revenue", "profit"]) ->
        :business_analysis
        
      true ->
        :code_analysis  # Default fallback
    end
  end

  defp process_conversation_turn(query, scenario_type, conversation_state) do
    schema = Map.get(@schemas, scenario_type)
    
    # Build context-aware prompt
    context_prompt = build_conversation_prompt(query, scenario_type, conversation_state)
    
    messages = [
      %{role: "system", content: context_prompt},
      %{role: "user", content: query}
    ]
    
    # Simple streaming for conversation mode
    IO.puts("🌊 Processing with context awareness...")
    
    case LMStudio.complete(messages) do
      {:ok, response} ->
        content = get_in(response, ["choices", Access.at(0), "message", "content"])
        
        # Extract and display reasoning + JSON
        {reasoning, json_content} = extract_reasoning_and_json([%{content: content}])
        
        if reasoning != "" do
          IO.puts("\n🧠 Reasoning:")
          IO.puts(IO.ANSI.blue() <> reasoning <> IO.ANSI.reset())
        end
        
        case Jason.decode(json_content) do
          {:ok, parsed} ->
            IO.puts("\n📋 Structured Response:")
            IO.puts(IO.ANSI.green() <> Jason.encode!(parsed, pretty: true) <> IO.ANSI.reset())
            %{success: true, reasoning: reasoning, response: parsed}
            
          {:error, _} ->
            IO.puts("\n📝 Response:")
            IO.puts(json_content)
            %{success: false, raw_response: json_content}
        end
        
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
        %{success: false, error: reason}
    end
  end

  defp build_conversation_prompt(query, scenario_type, conversation_state) do
    base_prompt = build_enhanced_prompt(query, Map.get(@schemas, scenario_type), scenario_type)
    
    if conversation_state.turn_count > 0 do
      context_info = """
      
      CONVERSATION CONTEXT:
      - Turn #{conversation_state.turn_count + 1} of ongoing conversation
      - Previous context: #{inspect(conversation_state.context)}
      - Consider previous discussion when formulating your response
      - Build upon or refine previous insights where relevant
      """
      
      base_prompt <> context_info
    else
      base_prompt
    end
  end

  defp update_conversation_state(state, query, result) do
    new_context = case result do
      %{success: true, response: response} ->
        Map.merge(state.context, %{
          last_query: query,
          last_response_summary: extract_summary(response),
          scenario_progression: (state.context[:scenario_progression] || []) ++ [query]
        })
        
      _ ->
        Map.put(state.context, :last_query, query)
    end
    
    %{state |
      turn_count: state.turn_count + 1,
      context: new_context,
      messages: state.messages ++ [%{role: "user", content: query}]
    }
  end

  defp extract_summary(response) when is_map(response) do
    # Extract key fields for context
    summary_fields = ["analysis", "summary", "title", "executive_summary", "hypothesis"]
    
    Enum.find_value(summary_fields, fn field ->
      case Map.get(response, field) do
        nil -> nil
        value when is_binary(value) -> String.slice(value, 0, 100)
        _ -> nil
      end
    end) || "Complex structured response"
  end
  defp extract_summary(_), do: "Previous response"
end

# Run the advanced demo
AdvancedDeepSeekStreaming.run_advanced_streaming_demo()

# Optionally run multi-turn conversation
IO.puts("\n" <> "🎮" |> String.duplicate(60))
IO.puts("Would you like to try the multi-turn conversation mode? (y/n)")

case IO.gets("> ") |> String.trim() |> String.downcase() do
  "y" -> AdvancedDeepSeekStreaming.run_multi_turn_conversation()
  _ -> IO.puts("👋 Demo completed!")
end

IO.puts("\n🎯 Advanced Features Demonstrated:")
IO.puts("- ✅ Reasoning token extraction and analysis")
IO.puts("- ✅ Multiple schema types with dynamic selection")
IO.puts("- ✅ Adaptive streaming with real-time chunk analysis")
IO.puts("- ✅ Comprehensive analytics and metrics collection")
IO.puts("- ✅ Multi-turn conversation with context awareness")
IO.puts("- ✅ Response validation and quality scoring")
IO.puts("- ✅ Performance analytics across scenario types")