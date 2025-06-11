defmodule Dspy.EnhancedStreamingVisualization do
  @moduledoc """
  Enhanced streaming stats visualization with real-time co-current processing display,
  progressive charts, and attractive UI elements for visual streaming feedback.
  
  Features:
  - Real-time streaming metrics with visual progress bars
  - Co-current processing visualization with multiple streams
  - Live performance analytics and charts
  - Attractive color-coded displays with animations
  - Token-by-token streaming analysis
  - Multi-dimensional stats tracking
  """

  use GenServer
  require Logger

  defstruct [
    :stream_id,
    :start_time,
    :metrics,
    :visual_config,
    :concurrent_streams,
    :performance_history,
    :chart_data,
    :display_mode,
    :animation_state
  ]

  @doc """
  Start enhanced streaming visualization for a single stream
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %__MODULE__{
      stream_id: Keyword.get(opts, :stream_id, generate_stream_id()),
      start_time: System.monotonic_time(:millisecond),
      metrics: initialize_metrics(),
      visual_config: initialize_visual_config(opts),
      concurrent_streams: %{},
      performance_history: [],
      chart_data: initialize_chart_data(),
      display_mode: Keyword.get(opts, :display_mode, :full),
      animation_state: %{frame: 0, direction: 1}
    }

    # Start the visual update loop
    schedule_visual_update()
    
    {:ok, state}
  end

  @doc """
  Create streaming callback with enhanced visualization
  """
  def create_enhanced_callback(opts \\ []) do
    stream_id = Keyword.get(opts, :stream_id, generate_stream_id())
    _display_mode = Keyword.get(opts, :display_mode, :full)
    _enable_charts = Keyword.get(opts, :enable_charts, true)
    
    # Initialize stream tracking
    GenServer.cast(__MODULE__, {:init_stream, stream_id, opts})
    
    fn
      {:chunk, content} ->
        GenServer.cast(__MODULE__, {:chunk_received, stream_id, content})
        :ok
      
      {:done, final_data} ->
        GenServer.cast(__MODULE__, {:stream_completed, stream_id, final_data})
        :ok
        
      {:error, error} ->
        GenServer.cast(__MODULE__, {:stream_error, stream_id, error})
        :ok
    end
  end

  @doc """
  Start concurrent streaming visualization for multiple streams
  """
  def start_concurrent_visualization(stream_configs) do
    GenServer.cast(__MODULE__, {:start_concurrent, stream_configs})
  end

  @doc """
  Get current streaming statistics
  """
  def get_streaming_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Enable live performance charts
  """
  def enable_live_charts(chart_types \\ [:throughput, :latency, :quality]) do
    GenServer.cast(__MODULE__, {:enable_charts, chart_types})
  end

  # GenServer Callbacks

  def handle_cast({:init_stream, stream_id, opts}, state) do
    display_stream_header(stream_id, opts)
    
    new_stream = %{
      id: stream_id,
      start_time: System.monotonic_time(:millisecond),
      chunks: [],
      total_chars: 0,
      metrics: initialize_stream_metrics(),
      visual_state: initialize_visual_state(),
      opts: opts
    }
    
    updated_concurrent = Map.put(state.concurrent_streams, stream_id, new_stream)
    {:noreply, %{state | concurrent_streams: updated_concurrent}}
  end

  def handle_cast({:chunk_received, stream_id, content}, state) do
    current_time = System.monotonic_time(:millisecond)
    
    # Update stream metrics
    updated_concurrent = update_stream_metrics(state.concurrent_streams, stream_id, content, current_time)
    
    # Display the chunk with enhanced visualization
    if stream = Map.get(updated_concurrent, stream_id) do
      display_enhanced_chunk(content, stream, state.visual_config)
      update_live_metrics_display(stream, state.visual_config)
    end
    
    {:noreply, %{state | concurrent_streams: updated_concurrent}}
  end

  def handle_cast({:stream_completed, stream_id, _final_data}, state) do
    if stream = Map.get(state.concurrent_streams, stream_id) do
      display_stream_completion(stream, state.visual_config)
      display_final_analytics(stream)
    end
    
    {:noreply, state}
  end

  def handle_cast({:stream_error, stream_id, error}, state) do
    display_stream_error(stream_id, error, state.visual_config)
    {:noreply, state}
  end

  def handle_cast({:start_concurrent, stream_configs}, state) do
    display_concurrent_header(stream_configs)
    {:noreply, state}
  end

  def handle_cast({:enable_charts, chart_types}, state) do
    updated_visual_config = Map.put(state.visual_config, :enabled_charts, chart_types)
    {:noreply, %{state | visual_config: updated_visual_config}}
  end

  def handle_call(:get_stats, _from, state) do
    stats = compile_comprehensive_stats(state)
    {:reply, stats, state}
  end

  def handle_info(:visual_update, state) do
    # Update animations and live displays
    updated_state = update_visual_animations(state)
    refresh_concurrent_displays(updated_state)
    
    schedule_visual_update()
    {:noreply, updated_state}
  end

  # Private Functions

  defp initialize_metrics do
    %{
      total_chunks: 0,
      total_characters: 0,
      average_chunk_size: 0,
      peak_chunk_size: 0,
      processing_rate: 0,
      quality_score: 0,
      reasoning_detection: %{},
      json_detection: %{},
      latency_stats: %{min: nil, max: nil, avg: nil},
      throughput_history: []
    }
  end

  defp initialize_visual_config(opts) do
    %{
      colors: %{
        reasoning: IO.ANSI.blue(),
        json: IO.ANSI.green(),
        metrics: IO.ANSI.cyan(),
        progress: IO.ANSI.yellow(),
        success: IO.ANSI.bright() <> IO.ANSI.green(),
        error: IO.ANSI.red(),
        reset: IO.ANSI.reset()
      },
      symbols: %{
        chunk: "▓",
        progress: "█",
        reasoning: "🧠",
        json: "📊",
        speed: "⚡",
        quality: "⭐",
        concurrent: "🔄",
        completion: "✅",
        error: "❌"
      },
      animations: %{
        enabled: Keyword.get(opts, :animations, true),
        speed: Keyword.get(opts, :animation_speed, 200)
      },
      charts: %{
        enabled: Keyword.get(opts, :enable_charts, true),
        width: Keyword.get(opts, :chart_width, 40),
        height: Keyword.get(opts, :chart_height, 8)
      },
      display_mode: Keyword.get(opts, :display_mode, :full)
    }
  end

  defp initialize_chart_data do
    %{
      throughput: [],
      latency: [],
      quality: [],
      chunk_size: [],
      reasoning_ratio: []
    }
  end

  defp initialize_stream_metrics do
    %{
      chunks_received: 0,
      total_characters: 0,
      start_time: System.monotonic_time(:millisecond),
      last_chunk_time: System.monotonic_time(:millisecond),
      reasoning_chunks: 0,
      json_chunks: 0,
      chunk_intervals: [],
      quality_indicators: []
    }
  end

  defp initialize_visual_state do
    %{
      progress_bar: "",
      current_animation_frame: 0,
      last_display_update: System.monotonic_time(:millisecond)
    }
  end

  defp display_stream_header(stream_id, opts) do
    colors = get_colors()
    symbols = get_symbols()
    
    IO.puts("\n" <> colors.metrics <> "╔" <> String.duplicate("═", 78) <> "╗" <> colors.reset)
    IO.puts(colors.metrics <> "║" <> colors.success <> " #{symbols.concurrent} ENHANCED STREAMING VISUALIZATION " <> 
            colors.metrics <> String.duplicate(" ", 42) <> "║" <> colors.reset)
    IO.puts(colors.metrics <> "║ Stream ID: #{stream_id}" <> String.duplicate(" ", 78 - String.length("Stream ID: #{stream_id}") - 1) <> "║" <> colors.reset)
    
    if opts[:model] do
      IO.puts(colors.metrics <> "║ Model: #{opts[:model]}" <> String.duplicate(" ", 78 - String.length("Model: #{opts[:model]}") - 1) <> "║" <> colors.reset)
    end
    
    IO.puts(colors.metrics <> "╠" <> String.duplicate("═", 78) <> "╣" <> colors.reset)
    IO.puts(colors.metrics <> "║ Metrics: " <> colors.progress <> "Speed " <> colors.success <> "Quality " <> 
            colors.progress <> "Progress " <> colors.reasoning <> "Reasoning " <> colors.json <> "JSON" <> 
            String.duplicate(" ", 35) <> colors.metrics <> "║" <> colors.reset)
    IO.puts(colors.metrics <> "╚" <> String.duplicate("═", 78) <> "╝" <> colors.reset)
    IO.puts("")
  end

  defp display_enhanced_chunk(content, stream, visual_config) do
    colors = visual_config.colors
    symbols = visual_config.symbols
    
    # Analyze chunk content for visualization
    chunk_analysis = analyze_chunk_content(content)
    
    # Choose visualization based on content type
    color = cond do
      chunk_analysis.contains_reasoning -> colors.reasoning
      chunk_analysis.contains_json -> colors.json
      chunk_analysis.complexity_score > 0.7 -> colors.progress
      true -> colors.reset
    end
    
    # Display with type indicators
    type_indicator = cond do
      chunk_analysis.contains_reasoning -> symbols.reasoning
      chunk_analysis.contains_json -> symbols.json
      true -> symbols.chunk
    end
    
    # Print the content with visual enhancements
    IO.write(color <> type_indicator <> " " <> content <> colors.reset)
    
    # Update inline metrics if enabled
    if visual_config.display_mode == :full do
      display_inline_metrics(stream, chunk_analysis, visual_config)
    end
  end

  defp display_inline_metrics(stream, chunk_analysis, visual_config) do
    colors = visual_config.colors
    symbols = visual_config.symbols
    
    # Calculate real-time metrics
    current_time = System.monotonic_time(:millisecond)
    elapsed = current_time - stream.start_time
    chars_per_second = if elapsed > 0, do: (stream.total_chars / elapsed) * 1000, else: 0
    
    # Create compact metrics display
    metrics_line = "#{colors.metrics}[#{symbols.speed}#{Float.round(chars_per_second, 1)} c/s " <>
                   "#{symbols.quality}#{chunk_analysis.complexity_score} " <>
                   "#{symbols.progress}#{stream.chunks |> length()}]#{colors.reset}"
    
    # Position cursor and display metrics (non-intrusive)
    if rem(stream.metrics.chunks_received, 5) == 0 do
      IO.write("\r" <> metrics_line)
      Process.sleep(50)
      IO.write("\r" <> String.duplicate(" ", String.length(metrics_line)) <> "\r")
    end
  end

  defp update_live_metrics_display(stream, visual_config) do
    if visual_config.display_mode == :full and rem(stream.metrics.chunks_received, 10) == 0 do
      display_progress_bar(stream, visual_config)
      display_live_chart(stream, visual_config)
    end
  end

  defp display_progress_bar(stream, visual_config) do
    colors = visual_config.colors
    symbols = visual_config.symbols
    
    # Calculate progress metrics
    elapsed_time = System.monotonic_time(:millisecond) - stream.start_time
    chunks_count = stream.metrics.chunks_received
    chars_count = stream.total_chars
    
    # Create animated progress bar
    bar_width = 40
    progress_ratio = min(1.0, chunks_count / 100.0)  # Normalize to expected chunks
    filled_width = round(progress_ratio * bar_width)
    
    progress_bar = colors.progress <> 
                   String.duplicate(symbols.progress, filled_width) <>
                   colors.metrics <>
                   String.duplicate("▒", bar_width - filled_width) <>
                   colors.reset
    
    # Display comprehensive metrics bar
    IO.puts("\n#{colors.metrics}╭─ Live Metrics ─────────────────────────────────────────────────────╮#{colors.reset}")
    IO.puts("#{colors.metrics}│ Progress: #{progress_bar} #{Float.round(progress_ratio * 100, 1)}% │#{colors.reset}")
    IO.puts("#{colors.metrics}│ #{symbols.speed} Rate: #{chars_count}/#{elapsed_time}ms " <>
            "#{symbols.chunk} Chunks: #{chunks_count} " <>
            "#{symbols.quality} Quality: #{Float.round(calculate_quality_score(stream), 2)} │#{colors.reset}")
    IO.puts("#{colors.metrics}╰────────────────────────────────────────────────────────────────────╯#{colors.reset}")
    
    # Move cursor back up to continue streaming display
    IO.write("\e[4A\e[K")
  end

  defp display_live_chart(stream, visual_config) do
    if visual_config.charts.enabled and length(stream.metrics.chunk_intervals) > 5 do
      create_throughput_chart(stream, visual_config)
    end
  end

  defp create_throughput_chart(stream, visual_config) do
    colors = visual_config.colors
    chart_width = visual_config.charts.width
    chart_height = visual_config.charts.height
    
    # Get recent throughput data
    recent_intervals = Enum.take(stream.metrics.chunk_intervals, -chart_width)
    
    if length(recent_intervals) > 1 do
      # Normalize data for chart display
      max_interval = Enum.max(recent_intervals)
      min_interval = Enum.min(recent_intervals)
      range = max(max_interval - min_interval, 1)
      
      # Create ASCII chart
      IO.puts("\n#{colors.metrics}│ Throughput Chart (last #{length(recent_intervals)} chunks)#{colors.reset}")
      
      for y <- chart_height..1 do
        line = Enum.map(recent_intervals, fn interval ->
          normalized = (interval - min_interval) / range
          threshold = y / chart_height
          if normalized >= threshold, do: "█", else: " "
        end)
        
        IO.puts("#{colors.metrics}│#{colors.progress}#{Enum.join(line)}#{colors.reset}")
      end
      
      IO.puts("#{colors.metrics}└#{String.duplicate("─", chart_width)}#{colors.reset}")
    end
  end

  defp display_concurrent_header(stream_configs) do
    colors = get_colors()
    symbols = get_symbols()
    
    IO.puts("\n" <> colors.success <> "╔" <> String.duplicate("═", 78) <> "╗" <> colors.reset)
    IO.puts(colors.success <> "║" <> " #{symbols.concurrent} CONCURRENT STREAMING VISUALIZATION - #{length(stream_configs)} STREAMS " <> 
            String.duplicate(" ", 78 - String.length(" CONCURRENT STREAMING VISUALIZATION - #{length(stream_configs)} STREAMS ") - 1) <> "║" <> colors.reset)
    IO.puts(colors.success <> "╚" <> String.duplicate("═", 78) <> "╝" <> colors.reset)
    
    # Display stream configuration matrix
    display_stream_matrix(stream_configs)
  end

  defp display_stream_matrix(stream_configs) do
    colors = get_colors()
    symbols = get_symbols()
    
    IO.puts("\n#{colors.metrics}Stream Configuration Matrix:#{colors.reset}")
    IO.puts("#{colors.metrics}┌────────────┬──────────────┬──────────────┬──────────────┐#{colors.reset}")
    IO.puts("#{colors.metrics}│ Stream ID  │ Model        │ Mode         │ Status       │#{colors.reset}")
    IO.puts("#{colors.metrics}├────────────┼──────────────┼──────────────┼──────────────┤#{colors.reset}")
    
    Enum.each(stream_configs, fn config ->
      stream_id = String.slice(to_string(config[:id] || "unknown"), 0, 10)
      model = String.slice(to_string(config[:model] || "default"), 0, 12)
      mode = String.slice(to_string(config[:mode] || "stream"), 0, 12)
      status = "#{symbols.concurrent} Active"
      
      IO.puts("#{colors.metrics}│ #{String.pad_trailing(stream_id, 10)} │ #{String.pad_trailing(model, 12)} │ #{String.pad_trailing(mode, 12)} │ #{colors.success}#{String.pad_trailing(status, 12)}#{colors.metrics} │#{colors.reset}")
    end)
    
    IO.puts("#{colors.metrics}└────────────┴──────────────┴──────────────┴──────────────┘#{colors.reset}")
  end

  defp display_stream_completion(stream, visual_config) do
    colors = visual_config.colors
    symbols = visual_config.symbols
    
    elapsed_time = System.monotonic_time(:millisecond) - stream.start_time
    total_chars = stream.total_chars
    chunks_count = stream.metrics.chunks_received
    avg_chunk_size = if chunks_count > 0, do: total_chars / chunks_count, else: 0
    chars_per_second = if elapsed_time > 0, do: (total_chars / elapsed_time) * 1000, else: 0
    
    IO.puts("\n" <> colors.success <> "╔" <> String.duplicate("═", 78) <> "╗" <> colors.reset)
    IO.puts(colors.success <> "║ #{symbols.completion} STREAM COMPLETED SUCCESSFULLY" <> String.duplicate(" ", 46) <> "║" <> colors.reset)
    IO.puts(colors.success <> "╠" <> String.duplicate("═", 78) <> "╣" <> colors.reset)
    IO.puts(colors.success <> "║ Final Statistics:" <> String.duplicate(" ", 60) <> "║" <> colors.reset)
    IO.puts(colors.success <> "║   #{symbols.speed} Processing Rate: #{Float.round(chars_per_second, 2)} chars/sec" <> 
            String.duplicate(" ", 78 - String.length("   Processing Rate: #{Float.round(chars_per_second, 2)} chars/sec") - 1) <> "║" <> colors.reset)
    IO.puts(colors.success <> "║   #{symbols.chunk} Total Chunks: #{chunks_count}" <> 
            String.duplicate(" ", 78 - String.length("   Total Chunks: #{chunks_count}") - 1) <> "║" <> colors.reset)
    IO.puts(colors.success <> "║   #{symbols.progress} Total Characters: #{total_chars}" <> 
            String.duplicate(" ", 78 - String.length("   Total Characters: #{total_chars}") - 1) <> "║" <> colors.reset)
    IO.puts(colors.success <> "║   #{symbols.quality} Avg Chunk Size: #{Float.round(avg_chunk_size, 1)}" <> 
            String.duplicate(" ", 78 - String.length("   Avg Chunk Size: #{Float.round(avg_chunk_size, 1)}") - 1) <> "║" <> colors.reset)
    IO.puts(colors.success <> "║   ⏱️  Total Time: #{elapsed_time}ms" <> 
            String.duplicate(" ", 78 - String.length("   Total Time: #{elapsed_time}ms") - 1) <> "║" <> colors.reset)
    IO.puts(colors.success <> "╚" <> String.duplicate("═", 78) <> "╝" <> colors.reset)
  end

  defp display_final_analytics(stream) do
    colors = get_colors()
    
    # Advanced analytics display
    reasoning_ratio = if stream.metrics.chunks_received > 0, 
      do: stream.metrics.reasoning_chunks / stream.metrics.chunks_received * 100, 
      else: 0
    
    json_ratio = if stream.metrics.chunks_received > 0,
      do: stream.metrics.json_chunks / stream.metrics.chunks_received * 100,
      else: 0
    
    IO.puts("\n#{colors.metrics}📊 Advanced Analytics:#{colors.reset}")
    IO.puts("#{colors.reasoning}   🧠 Reasoning Content: #{Float.round(reasoning_ratio, 1)}%#{colors.reset}")
    IO.puts("#{colors.json}   📊 JSON Content: #{Float.round(json_ratio, 1)}%#{colors.reset}")
    IO.puts("#{colors.progress}   📈 Quality Score: #{Float.round(calculate_quality_score(stream), 2)}/10#{colors.reset}")
    
    if length(stream.metrics.chunk_intervals) > 1 do
      avg_interval = Enum.sum(stream.metrics.chunk_intervals) / length(stream.metrics.chunk_intervals)
      IO.puts("#{colors.metrics}   ⚡ Avg Chunk Interval: #{Float.round(avg_interval, 1)}ms#{colors.reset}")
    end
  end

  defp display_stream_error(stream_id, error, visual_config) do
    colors = visual_config.colors
    symbols = visual_config.symbols
    
    IO.puts("\n" <> colors.error <> "╔" <> String.duplicate("═", 78) <> "╗" <> colors.reset)
    IO.puts(colors.error <> "║ #{symbols.error} STREAM ERROR - #{stream_id}" <> 
            String.duplicate(" ", 78 - String.length(" STREAM ERROR - #{stream_id}") - 1) <> "║" <> colors.reset)
    IO.puts(colors.error <> "║ Error: #{inspect(error)}" <> 
            String.duplicate(" ", 78 - String.length("Error: #{inspect(error)}") - 1) <> "║" <> colors.reset)
    IO.puts(colors.error <> "╚" <> String.duplicate("═", 78) <> "╝" <> colors.reset)
  end

  defp update_stream_metrics(concurrent_streams, stream_id, content, current_time) do
    Map.update(concurrent_streams, stream_id, nil, fn stream ->
      if stream do
        chunk_analysis = analyze_chunk_content(content)
        
        # Calculate interval since last chunk
        interval = current_time - stream.metrics.last_chunk_time
        
        updated_metrics = stream.metrics
        |> Map.update!(:chunks_received, &(&1 + 1))
        |> Map.update!(:total_characters, &(&1 + String.length(content)))
        |> Map.put(:last_chunk_time, current_time)
        |> Map.update!(:chunk_intervals, &([interval | &1] |> Enum.take(50)))
        |> Map.update!(:reasoning_chunks, &(&1 + if(chunk_analysis.contains_reasoning, do: 1, else: 0)))
        |> Map.update!(:json_chunks, &(&1 + if(chunk_analysis.contains_json, do: 1, else: 0)))
        |> Map.update!(:quality_indicators, &([chunk_analysis.complexity_score | &1] |> Enum.take(20)))
        
        %{stream | 
          chunks: [content | stream.chunks],
          total_chars: stream.total_chars + String.length(content),
          metrics: updated_metrics
        }
      else
        stream
      end
    end)
  end

  defp analyze_chunk_content(content) do
    %{
      contains_reasoning: String.contains?(content, ["<think>", "</think>", "reasoning", "because"]),
      contains_json: String.contains?(content, ["{", "}", "[", "]", "\":"]),
      complexity_score: calculate_complexity_score(content),
      word_count: content |> String.split() |> length(),
      character_count: String.length(content),
      has_punctuation: String.match?(content, ~r/[.!?;,]/),
      has_numbers: String.match?(content, ~r/\d/),
      has_code_patterns: String.match?(content, ~r/[(){}[\]]/),
      sentiment: analyze_sentiment(content)
    }
  end

  defp calculate_complexity_score(content) do
    base_score = String.length(content) / 100.0
    
    complexity_indicators = [
      String.contains?(content, ["however", "therefore", "consequently"]),
      String.contains?(content, ["analyze", "consider", "evaluate"]),
      String.contains?(content, ["implementation", "architecture", "optimization"]),
      String.match?(content, ~r/[{}[\]()]/),
      String.split(content) |> length() > 10
    ]
    
    indicator_bonus = Enum.count(complexity_indicators, & &1) * 0.2
    min(base_score + indicator_bonus, 1.0)
  end

  defp analyze_sentiment(content) do
    positive_words = ["good", "great", "excellent", "positive", "success", "improve"]
    negative_words = ["bad", "error", "fail", "problem", "issue", "difficult"]
    
    content_lower = String.downcase(content)
    positive_count = Enum.count(positive_words, &String.contains?(content_lower, &1))
    negative_count = Enum.count(negative_words, &String.contains?(content_lower, &1))
    
    cond do
      positive_count > negative_count -> :positive
      negative_count > positive_count -> :negative
      true -> :neutral
    end
  end

  defp calculate_quality_score(stream) do
    if length(stream.metrics.quality_indicators) > 0 do
      Enum.sum(stream.metrics.quality_indicators) / length(stream.metrics.quality_indicators) * 10
    else
      5.0
    end
  end

  defp compile_comprehensive_stats(state) do
    %{
      total_streams: map_size(state.concurrent_streams),
      active_streams: state.concurrent_streams |> Enum.count(fn {_id, stream} -> stream != nil end),
      global_metrics: calculate_global_metrics(state.concurrent_streams),
      performance_summary: generate_performance_summary(state.concurrent_streams),
      visual_config: state.visual_config,
      uptime: System.monotonic_time(:millisecond) - state.start_time
    }
  end

  defp calculate_global_metrics(concurrent_streams) do
    active_streams = concurrent_streams |> Map.values() |> Enum.filter(& &1)
    
    if length(active_streams) > 0 do
      total_chars = Enum.sum(Enum.map(active_streams, & &1.total_chars))
      total_chunks = Enum.sum(Enum.map(active_streams, & &1.metrics.chunks_received))
      
      %{
        total_characters: total_chars,
        total_chunks: total_chunks,
        average_stream_performance: total_chars / length(active_streams),
        collective_throughput: total_chars / (System.monotonic_time(:millisecond) - (Enum.map(active_streams, & &1.start_time) |> Enum.min()))
      }
    else
      %{total_characters: 0, total_chunks: 0, average_stream_performance: 0, collective_throughput: 0}
    end
  end

  defp generate_performance_summary(concurrent_streams) do
    active_streams = concurrent_streams |> Map.values() |> Enum.filter(& &1)
    
    %{
      fastest_stream: find_fastest_stream(active_streams),
      most_productive_stream: find_most_productive_stream(active_streams),
      quality_leader: find_highest_quality_stream(active_streams),
      efficiency_stats: calculate_efficiency_stats(active_streams)
    }
  end

  defp find_fastest_stream(streams) do
    if length(streams) > 0 do
      Enum.max_by(streams, fn stream ->
        if stream.metrics.chunks_received > 0 do
          stream.total_chars / (System.monotonic_time(:millisecond) - stream.start_time)
        else
          0
        end
      end, fn -> nil end)
    end
  end

  defp find_most_productive_stream(streams) do
    if length(streams) > 0 do
      Enum.max_by(streams, & &1.total_chars, fn -> nil end)
    end
  end

  defp find_highest_quality_stream(streams) do
    if length(streams) > 0 do
      Enum.max_by(streams, &calculate_quality_score/1, fn -> nil end)
    end
  end

  defp calculate_efficiency_stats(streams) do
    if length(streams) > 0 do
      efficiencies = Enum.map(streams, fn stream ->
        if stream.metrics.chunks_received > 0 do
          stream.total_chars / stream.metrics.chunks_received
        else
          0
        end
      end)
      
      %{
        average_efficiency: Enum.sum(efficiencies) / length(efficiencies),
        max_efficiency: Enum.max(efficiencies),
        min_efficiency: Enum.min(efficiencies)
      }
    else
      %{average_efficiency: 0, max_efficiency: 0, min_efficiency: 0}
    end
  end

  defp update_visual_animations(state) do
    new_frame = rem(state.animation_state.frame + state.animation_state.direction, 8)
    new_direction = if new_frame == 0 or new_frame == 7, 
      do: -state.animation_state.direction, 
      else: state.animation_state.direction
    
    %{state | animation_state: %{frame: new_frame, direction: new_direction}}
  end

  defp refresh_concurrent_displays(state) do
    if map_size(state.concurrent_streams) > 1 do
      display_concurrent_summary(state)
    end
  end

  defp display_concurrent_summary(state) do
    colors = state.visual_config.colors
    _symbols = state.visual_config.symbols
    active_streams = state.concurrent_streams |> Map.values() |> Enum.filter(& &1)
    
    if length(active_streams) > 0 and rem(state.animation_state.frame, 4) == 0 do
      # Create a live dashboard update
      IO.write("\e[2J\e[H")  # Clear screen and move to top
      
      IO.puts("#{colors.metrics}╭─ LIVE CONCURRENT STREAMING DASHBOARD ─╮#{colors.reset}")
      IO.puts("#{colors.metrics}│ Active Streams: #{length(active_streams)}" <> 
              String.duplicate(" ", 40 - String.length("Active Streams: #{length(active_streams)}") - 1) <> "│#{colors.reset}")
      
      Enum.each(active_streams, fn stream ->
        progress = min(100, stream.metrics.chunks_received * 2)
        bar = create_mini_progress_bar(progress, 20)
        chars_rate = if stream.total_chars > 0, 
          do: Float.round(stream.total_chars / max(1, System.monotonic_time(:millisecond) - stream.start_time) * 1000, 1), 
          else: 0
        
        IO.puts("#{colors.metrics}│ #{String.slice(stream.id, 0, 8)}: #{bar} #{chars_rate}c/s │#{colors.reset}")
      end)
      
      IO.puts("#{colors.metrics}╰────────────────────────────────────────╯#{colors.reset}")
    end
  end

  defp create_mini_progress_bar(percentage, width) do
    filled = round(percentage / 100 * width)
    get_colors().progress <> String.duplicate("█", filled) <> 
    get_colors().metrics <> String.duplicate("▒", width - filled) <> 
    get_colors().reset
  end

  defp schedule_visual_update do
    Process.send_after(self(), :visual_update, 250)
  end

  defp generate_stream_id do
    "stream_" <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp get_colors do
    %{
      reasoning: IO.ANSI.blue(),
      json: IO.ANSI.green(),
      metrics: IO.ANSI.cyan(),
      progress: IO.ANSI.yellow(),
      success: IO.ANSI.bright() <> IO.ANSI.green(),
      error: IO.ANSI.red(),
      reset: IO.ANSI.reset()
    }
  end

  defp get_symbols do
    %{
      chunk: "▓",
      progress: "█",
      reasoning: "🧠",
      json: "📊",
      speed: "⚡",
      quality: "⭐",
      concurrent: "🔄",
      completion: "✅",
      error: "❌"
    }
  end
end