defmodule Dspy.MultiAgentLogger do
  @moduledoc """
  Comprehensive logging and persistence system for multi-agent conversations.

  Provides detailed logging, conversation analysis, and export capabilities
  for multi-agent chat sessions.
  """

  use GenServer
  require Logger

  defstruct [
    :log_dir,
    :conversation_logs,
    :analytics,
    :export_formats
  ]

  @type conversation_analytics :: %{
          total_messages: integer(),
          messages_per_agent: map(),
          average_response_time: float(),
          conversation_duration: integer(),
          topic_keywords: [String.t()],
          sentiment_analysis: map(),
          interaction_patterns: map()
        }

  ## Client API

  @doc """
  Start the multi-agent logger.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start logging a conversation.
  """
  def start_logging(conversation_id, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:start_logging, conversation_id, metadata})
  end

  @doc """
  Log a message from a conversation.
  """
  def log_message(conversation_id, message) do
    GenServer.cast(__MODULE__, {:log_message, conversation_id, message})
  end

  @doc """
  Log an event from a conversation.
  """
  def log_event(conversation_id, event_type, event_data) do
    GenServer.cast(__MODULE__, {:log_event, conversation_id, event_type, event_data})
  end

  @doc """
  Stop logging a conversation and generate final analytics.
  """
  def stop_logging(conversation_id) do
    GenServer.call(__MODULE__, {:stop_logging, conversation_id})
  end

  @doc """
  Get analytics for a conversation.
  """
  def get_analytics(conversation_id) do
    GenServer.call(__MODULE__, {:get_analytics, conversation_id})
  end

  @doc """
  Export conversation in various formats.
  """
  def export_conversation(conversation_id, format \\ :json, opts \\ []) do
    GenServer.call(__MODULE__, {:export_conversation, conversation_id, format, opts})
  end

  @doc """
  List all logged conversations.
  """
  def list_conversations do
    GenServer.call(__MODULE__, :list_conversations)
  end

  ## GenServer Implementation

  @impl true
  def init(opts) do
    log_dir = Keyword.get(opts, :log_dir, "logs/multi_agent_conversations")
    File.mkdir_p!(log_dir)

    state = %__MODULE__{
      log_dir: log_dir,
      conversation_logs: %{},
      analytics: %{},
      export_formats: [:json, :csv, :markdown, :html]
    }

    Logger.info("Multi-agent logger started with log directory: #{log_dir}")

    {:ok, state}
  end

  @impl true
  def handle_call({:start_logging, conversation_id, metadata}, _from, state) do
    timestamp = DateTime.utc_now()

    conversation_log = %{
      conversation_id: conversation_id,
      start_time: timestamp,
      metadata: metadata,
      messages: [],
      events: [],
      analytics: %{
        total_messages: 0,
        messages_per_agent: %{},
        start_time: timestamp,
        end_time: nil,
        participants: []
      }
    }

    new_logs = Map.put(state.conversation_logs, conversation_id, conversation_log)

    {:reply, :ok, %{state | conversation_logs: new_logs}}
  end

  @impl true
  def handle_call({:stop_logging, conversation_id}, _from, state) do
    case Map.get(state.conversation_logs, conversation_id) do
      nil ->
        {:reply, {:error, :conversation_not_found}, state}

      conversation_log ->
        end_time = DateTime.utc_now()
        final_analytics = calculate_final_analytics(conversation_log, end_time)

        updated_log = %{
          conversation_log
          | analytics: Map.merge(conversation_log.analytics, final_analytics)
        }

        # Write to file
        write_conversation_log(state.log_dir, updated_log)

        # Update state
        new_logs = Map.put(state.conversation_logs, conversation_id, updated_log)
        new_analytics = Map.put(state.analytics, conversation_id, final_analytics)

        {:reply, {:ok, final_analytics},
         %{state | conversation_logs: new_logs, analytics: new_analytics}}
    end
  end

  @impl true
  def handle_call({:get_analytics, conversation_id}, _from, state) do
    case Map.get(state.conversation_logs, conversation_id) do
      nil -> {:reply, {:error, :conversation_not_found}, state}
      log -> {:reply, {:ok, log.analytics}, state}
    end
  end

  @impl true
  def handle_call({:export_conversation, conversation_id, format, opts}, _from, state) do
    case Map.get(state.conversation_logs, conversation_id) do
      nil ->
        {:reply, {:error, :conversation_not_found}, state}

      conversation_log ->
        case export_to_format(conversation_log, format, opts, state.log_dir) do
          {:ok, file_path} -> {:reply, {:ok, file_path}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call(:list_conversations, _from, state) do
    conversations =
      state.conversation_logs
      |> Map.values()
      |> Enum.map(fn log ->
        %{
          conversation_id: log.conversation_id,
          start_time: log.start_time,
          message_count: length(log.messages),
          participants: Map.keys(log.analytics.messages_per_agent)
        }
      end)

    {:reply, conversations, state}
  end

  @impl true
  def handle_cast({:log_message, conversation_id, message}, state) do
    case Map.get(state.conversation_logs, conversation_id) do
      nil ->
        Logger.warning("Attempted to log message for unknown conversation: #{conversation_id}")
        {:noreply, state}

      conversation_log ->
        updated_log = add_message_to_log(conversation_log, message)
        new_logs = Map.put(state.conversation_logs, conversation_id, updated_log)

        {:noreply, %{state | conversation_logs: new_logs}}
    end
  end

  @impl true
  def handle_cast({:log_event, conversation_id, event_type, event_data}, state) do
    case Map.get(state.conversation_logs, conversation_id) do
      nil ->
        Logger.warning("Attempted to log event for unknown conversation: #{conversation_id}")
        {:noreply, state}

      conversation_log ->
        event = %{
          type: event_type,
          data: event_data,
          timestamp: DateTime.utc_now()
        }

        updated_log = %{conversation_log | events: [event | conversation_log.events]}
        new_logs = Map.put(state.conversation_logs, conversation_id, updated_log)

        {:noreply, %{state | conversation_logs: new_logs}}
    end
  end

  ## Private Functions

  defp add_message_to_log(conversation_log, message) do
    # Update messages
    new_messages = [message | conversation_log.messages]

    # Update analytics
    speaker = message.speaker
    current_count = Map.get(conversation_log.analytics.messages_per_agent, speaker, 0)

    updated_messages_per_agent =
      Map.put(conversation_log.analytics.messages_per_agent, speaker, current_count + 1)

    updated_analytics = %{
      conversation_log.analytics
      | total_messages: conversation_log.analytics.total_messages + 1,
        messages_per_agent: updated_messages_per_agent,
        participants: Enum.uniq([speaker | conversation_log.analytics.participants])
    }

    %{conversation_log | messages: new_messages, analytics: updated_analytics}
  end

  defp calculate_final_analytics(conversation_log, end_time) do
    messages = Enum.reverse(conversation_log.messages)

    duration_seconds = DateTime.diff(end_time, conversation_log.analytics.start_time)

    # Calculate response times
    response_times = calculate_response_times(messages)

    avg_response_time =
      if length(response_times) > 0 do
        Enum.sum(response_times) / length(response_times)
      else
        0.0
      end

    # Extract keywords
    all_content = Enum.map(messages, & &1.content) |> Enum.join(" ")
    keywords = extract_keywords(all_content)

    # Analyze interaction patterns
    interaction_patterns = analyze_interaction_patterns(messages)

    %{
      end_time: end_time,
      duration_seconds: duration_seconds,
      average_response_time: avg_response_time,
      topic_keywords: keywords,
      interaction_patterns: interaction_patterns,
      message_length_stats: calculate_message_length_stats(messages),
      participation_balance:
        calculate_participation_balance(conversation_log.analytics.messages_per_agent)
    }
  end

  defp calculate_response_times(messages) do
    messages
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [msg1, msg2] ->
      DateTime.diff(msg2.timestamp, msg1.timestamp, :millisecond)
    end)
  end

  defp extract_keywords(content) do
    content
    |> String.downcase()
    |> String.split(~r/[^\w]+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> count end, :desc)
    |> Enum.take(20)
    |> Enum.map(fn {word, _count} -> word end)
  end

  defp analyze_interaction_patterns(messages) do
    # Analyze who responds to whom most often
    response_pairs_raw =
      messages
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [msg1, msg2] -> {msg1.speaker, msg2.speaker} end)
      |> Enum.frequencies()

    # Convert tuple keys to strings for JSON serialization
    response_pairs =
      response_pairs_raw
      |> Enum.map(fn {{speaker1, speaker2}, count} ->
        {"#{speaker1} -> #{speaker2}", count}
      end)
      |> Map.new()

    # Find conversation chains (sequences of 3+ messages)
    conversation_chains = find_conversation_chains(messages)

    %{
      response_pairs: response_pairs,
      conversation_chains: conversation_chains,
      most_active_responder: find_most_active_responder(response_pairs_raw),
      longest_chain: find_longest_chain(conversation_chains)
    }
  end

  defp find_conversation_chains(messages) do
    messages
    |> Enum.chunk_while(
      [],
      fn msg, acc ->
        case acc do
          [] -> {:cont, [msg]}
          [last_msg | _] when last_msg.speaker != msg.speaker -> {:cont, [msg]}
          _ -> {:cont, [msg | acc]}
        end
      end,
      fn acc -> {:cont, Enum.reverse(acc), []} end
    )
    |> Enum.filter(&(length(&1) >= 3))
  end

  defp find_most_active_responder(response_pairs) do
    result =
      response_pairs
      |> Enum.group_by(fn {{_from, to}, _count} -> to end)
      |> Enum.map(fn {responder, pairs} ->
        total_count = pairs |> Enum.map(fn {_pair, count} -> count end) |> Enum.sum()
        {responder, total_count}
      end)
      |> Enum.max_by(fn {_responder, count} -> count end, fn -> nil end)

    case result do
      {responder, count} -> %{responder: responder, count: count}
      nil -> nil
    end
  end

  defp find_longest_chain(chains) do
    chains
    |> Enum.max_by(&length/1, fn -> [] end)
  end

  defp calculate_message_length_stats(messages) do
    lengths = Enum.map(messages, &String.length(&1.content))

    %{
      min: Enum.min(lengths, fn -> 0 end),
      max: Enum.max(lengths, fn -> 0 end),
      average: if(length(lengths) > 0, do: Enum.sum(lengths) / length(lengths), else: 0),
      total_characters: Enum.sum(lengths)
    }
  end

  defp calculate_participation_balance(messages_per_agent) do
    if map_size(messages_per_agent) == 0 do
      %{balance_score: 0, most_active: nil, least_active: nil}
    else
      counts = Map.values(messages_per_agent)
      total_messages = Enum.sum(counts)
      expected_per_agent = total_messages / map_size(messages_per_agent)

      # Calculate balance score (lower is more balanced)
      balance_score =
        counts
        |> Enum.map(&abs(&1 - expected_per_agent))
        |> Enum.sum()
        |> Kernel./(total_messages)

      {most_active_agent, max_count} =
        Enum.max_by(messages_per_agent, fn {_agent, count} -> count end)

      {least_active_agent, min_count} =
        Enum.min_by(messages_per_agent, fn {_agent, count} -> count end)

      %{
        balance_score: balance_score,
        most_active: %{agent: most_active_agent, count: max_count},
        least_active: %{agent: least_active_agent, count: min_count}
      }
    end
  end

  defp write_conversation_log(log_dir, conversation_log) do
    timestamp = Calendar.strftime(conversation_log.start_time, "%Y%m%d_%H%M%S")
    filename = "conversation_#{conversation_log.conversation_id}_#{timestamp}.json"
    file_path = Path.join(log_dir, filename)

    json_data = Jason.encode!(conversation_log, pretty: true)
    File.write!(file_path, json_data)

    Logger.info("Conversation log written to: #{file_path}")
  end

  defp export_to_format(conversation_log, format, opts, log_dir) do
    timestamp = Calendar.strftime(conversation_log.start_time, "%Y%m%d_%H%M%S")
    base_filename = "export_#{conversation_log.conversation_id}_#{timestamp}"

    case format do
      :json -> export_json(conversation_log, base_filename, log_dir, opts)
      :csv -> export_csv(conversation_log, base_filename, log_dir, opts)
      :markdown -> export_markdown(conversation_log, base_filename, log_dir, opts)
      :html -> export_html(conversation_log, base_filename, log_dir, opts)
      _ -> {:error, :unsupported_format}
    end
  end

  defp export_json(conversation_log, base_filename, log_dir, _opts) do
    file_path = Path.join(log_dir, "#{base_filename}.json")
    json_data = Jason.encode!(conversation_log, pretty: true)
    File.write!(file_path, json_data)
    {:ok, file_path}
  end

  defp export_csv(conversation_log, base_filename, log_dir, _opts) do
    file_path = Path.join(log_dir, "#{base_filename}.csv")

    csv_content =
      [
        "timestamp,speaker,model,role,content",
        conversation_log.messages
        |> Enum.reverse()
        |> Enum.map(fn msg ->
          timestamp = Calendar.strftime(msg.timestamp, "%Y-%m-%d %H:%M:%S")
          content = String.replace(msg.content, ["\n", "\r", "\""], " ")
          "#{timestamp},#{msg.speaker},#{msg.model || ""},#{msg.role || ""},\"#{content}\""
        end)
      ]
      |> Enum.join("\n")

    File.write!(file_path, csv_content)
    {:ok, file_path}
  end

  defp export_markdown(conversation_log, base_filename, log_dir, _opts) do
    file_path = Path.join(log_dir, "#{base_filename}.md")

    markdown_content = """
    # Multi-Agent Conversation: #{conversation_log.conversation_id}

    **Start Time:** #{Calendar.strftime(conversation_log.start_time, "%Y-%m-%d %H:%M:%S")}
    **Total Messages:** #{conversation_log.analytics.total_messages}
    **Participants:** #{Enum.join(conversation_log.analytics.participants, ", ")}

    ## Conversation

    #{conversation_log.messages |> Enum.reverse() |> Enum.map(&format_message_markdown/1) |> Enum.join("\n\n")}

    ## Analytics

    #{format_analytics_markdown(conversation_log.analytics)}
    """

    File.write!(file_path, markdown_content)
    {:ok, file_path}
  end

  defp export_html(conversation_log, base_filename, log_dir, _opts) do
    file_path = Path.join(log_dir, "#{base_filename}.html")

    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Multi-Agent Conversation: #{conversation_log.conversation_id}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .message { margin: 10px 0; padding: 10px; border-left: 4px solid #007cba; background: #f9f9f9; }
            .speaker { font-weight: bold; color: #007cba; }
            .timestamp { color: #666; font-size: 0.9em; }
            .analytics { background: #e9f4f8; padding: 15px; margin: 20px 0; border-radius: 5px; }
        </style>
    </head>
    <body>
        <h1>Multi-Agent Conversation: #{conversation_log.conversation_id}</h1>
        <div class="analytics">
            <h2>Conversation Details</h2>
            <p><strong>Start Time:</strong> #{Calendar.strftime(conversation_log.start_time, "%Y-%m-%d %H:%M:%S")}</p>
            <p><strong>Total Messages:</strong> #{conversation_log.analytics.total_messages}</p>
            <p><strong>Participants:</strong> #{Enum.join(conversation_log.analytics.participants, ", ")}</p>
        </div>
        
        <h2>Messages</h2>
        #{conversation_log.messages |> Enum.reverse() |> Enum.map(&format_message_html/1) |> Enum.join("\n")}
    </body>
    </html>
    """

    File.write!(file_path, html_content)
    {:ok, file_path}
  end

  defp format_message_markdown(msg) do
    timestamp = Calendar.strftime(msg.timestamp, "%H:%M:%S")
    "**[#{timestamp}] #{msg.speaker}** (#{msg.model || "unknown"})\n\n#{msg.content}"
  end

  defp format_message_html(msg) do
    timestamp = Calendar.strftime(msg.timestamp, "%H:%M:%S")

    """
    <div class="message">
        <div class="speaker">#{msg.speaker} (#{msg.model || "unknown"})</div>
        <div class="timestamp">#{timestamp}</div>
        <div>#{String.replace(msg.content, "\n", "<br>")}</div>
    </div>
    """
  end

  defp format_analytics_markdown(analytics) do
    """
    - **Duration:** #{Map.get(analytics, :duration_seconds, 0)} seconds
    - **Average Response Time:** #{Map.get(analytics, :average_response_time, 0)} ms
    - **Keywords:** #{Map.get(analytics, :topic_keywords, []) |> Enum.join(", ")}
    """
  end
end
