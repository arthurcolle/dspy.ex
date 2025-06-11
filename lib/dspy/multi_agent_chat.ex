defmodule Dspy.MultiAgentChat do
  @moduledoc """
  Comprehensive multi-agent chat system for testing interactions between up to 12 different OpenAI models.

  This module creates an unbounded conversation environment where different AI models can interact,
  allowing for emergent behaviors and comprehensive testing of model capabilities.
  """

  use GenServer
  require Logger

  defstruct [
    :conversation_id,
    :participants,
    :conversation_history,
    :current_speaker,
    :turn_counter,
    :topic,
    :max_turns,
    :running,
    :observers,
    :conversation_rules,
    :moderator_config
  ]

  @type agent_config :: %{
          name: String.t(),
          model: String.t(),
          personality: String.t(),
          role: String.t(),
          temperature: float(),
          max_tokens: integer()
        }

  @type conversation_rules :: %{
          max_message_length: integer(),
          turn_timeout_ms: integer(),
          topics_allowed: [String.t()],
          moderation_enabled: boolean(),
          auto_continue: boolean()
        }

  @type t :: %__MODULE__{
          conversation_id: String.t(),
          participants: [agent_config()],
          conversation_history: [map()],
          current_speaker: integer(),
          turn_counter: integer(),
          topic: String.t(),
          max_turns: integer() | :unlimited,
          running: boolean(),
          observers: [pid()],
          conversation_rules: conversation_rules(),
          moderator_config: map()
        }

  # Default cost-effective models for multi-agent testing
  @cost_effective_models [
    # Fast, affordable, capable
    "gpt-4o-mini",
    # Balanced intelligence and cost
    "gpt-4.1-mini",
    # Most cost-effective
    "gpt-4.1-nano",
    # Flagship model
    "gpt-4o",
    # Reliable alternative
    "gpt-4-turbo",
    # Legacy but very cost-effective
    "gpt-3.5-turbo",
    # Stable baseline
    "gpt-4",
    # Latest chat model
    "chatgpt-4o-latest"
  ]

  @default_personalities [
    "analytical thinker who focuses on logic and evidence",
    "creative problem solver who thinks outside the box",
    "devil's advocate who challenges assumptions",
    "collaborative mediator who seeks common ground",
    "detail-oriented expert who examines specifics",
    "big-picture strategist who considers long-term implications",
    "skeptical questioner who probes deeper",
    "optimistic innovator who sees possibilities",
    "practical implementer who focuses on actionable solutions",
    "philosophical contemplator who explores meaning",
    "data-driven analyst who relies on facts and metrics",
    "empathetic communicator who considers human factors"
  ]

  @default_roles [
    "Research Scientist",
    "Creative Director",
    "Systems Analyst",
    "Project Manager",
    "Quality Assurance",
    "Strategic Planner",
    "Technical Lead",
    "Innovation Consultant",
    "Operations Manager",
    "Philosophy Professor",
    "Data Scientist",
    "UX Designer"
  ]

  ## Client API

  @doc """
  Start a new multi-agent conversation.
  """
  def start_conversation(opts \\ []) do
    conversation_id = Keyword.get(opts, :conversation_id, generate_id())
    opts_with_id = Keyword.put(opts, :conversation_id, conversation_id)

    case GenServer.start_link(__MODULE__, opts_with_id, name: via_tuple(conversation_id)) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Add an observer to receive conversation updates.
  """
  def add_observer(conversation_id, observer_pid) do
    try do
      GenServer.call(via_tuple(conversation_id), {:add_observer, observer_pid}, 10_000)
    catch
      :exit, {:noproc, _} ->
        {:error, :conversation_not_found}

      :exit, {:timeout, _} ->
        {:error, :timeout}
    end
  end

  @doc """
  Start the conversation with a topic.
  """
  def start_topic(conversation_id, topic) do
    GenServer.call(via_tuple(conversation_id), {:start_topic, topic})
  end

  @doc """
  Get the current conversation state.
  """
  def get_state(conversation_id) do
    GenServer.call(via_tuple(conversation_id), :get_state)
  end

  @doc """
  Pause the conversation.
  """
  def pause(conversation_id) do
    GenServer.call(via_tuple(conversation_id), :pause)
  end

  @doc """
  Resume the conversation.
  """
  def resume(conversation_id) do
    GenServer.call(via_tuple(conversation_id), :resume)
  end

  @doc """
  Stop the conversation.
  """
  def stop_conversation(conversation_id) do
    GenServer.call(via_tuple(conversation_id), :stop, 15_000)
  end

  @doc """
  Create a pre-configured multi-agent setup for testing.
  """
  def create_test_setup(num_agents \\ 6, opts \\ []) do
    agents = create_diverse_agents(num_agents, opts)

    conversation_opts = [
      participants: agents,
      max_turns: Keyword.get(opts, :max_turns, :unlimited),
      conversation_id: Keyword.get(opts, :conversation_id),
      conversation_rules: %{
        max_message_length: Keyword.get(opts, :max_message_length, 500),
        turn_timeout_ms: Keyword.get(opts, :turn_timeout_ms, 30_000),
        topics_allowed: Keyword.get(opts, :topics_allowed, :any),
        moderation_enabled: Keyword.get(opts, :moderation_enabled, true),
        auto_continue: Keyword.get(opts, :auto_continue, true)
      }
    ]

    start_conversation(conversation_opts)
  end

  ## GenServer Implementation

  @impl true
  def init(opts) do
    conversation_id = Keyword.get(opts, :conversation_id, generate_id())
    participants = Keyword.get(opts, :participants, [])
    max_turns = Keyword.get(opts, :max_turns, :unlimited)

    default_rules = %{
      max_message_length: 500,
      turn_timeout_ms: 30_000,
      topics_allowed: :any,
      moderation_enabled: true,
      auto_continue: true
    }

    state = %__MODULE__{
      conversation_id: conversation_id,
      participants: participants,
      conversation_history: [],
      current_speaker: 0,
      turn_counter: 0,
      topic: nil,
      max_turns: max_turns,
      running: false,
      observers: [],
      conversation_rules: Keyword.get(opts, :conversation_rules, default_rules),
      moderator_config: Keyword.get(opts, :moderator_config, %{})
    }

    Logger.info(
      "Multi-agent conversation #{conversation_id} initialized with #{length(participants)} participants"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:add_observer, observer_pid}, _from, state) do
    new_observers = [observer_pid | state.observers]
    {:reply, :ok, %{state | observers: new_observers}}
  end

  @impl true
  def handle_call({:start_topic, topic}, _from, state) do
    if state.running do
      {:reply, {:error, :already_running}, state}
    else
      new_state = %{state | topic: topic, running: true, turn_counter: 0}

      # Start the conversation with an opening message
      opening_message = create_opening_message(topic, state.participants)
      updated_state = add_message_to_history(new_state, opening_message)

      # Notify observers
      notify_observers(updated_state, {:conversation_started, topic})

      # Schedule the first turn
      schedule_next_turn(updated_state)

      {:reply, :ok, updated_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:pause, _from, state) do
    {:reply, :ok, %{state | running: false}}
  end

  @impl true
  def handle_call(:resume, _from, state) do
    new_state = %{state | running: true}
    schedule_next_turn(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    # Notify observers with a timeout to prevent hanging
    Task.start(fn -> 
      notify_observers(state, {:conversation_ended, state.conversation_history})
    end)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info(:next_turn, state) do
    if state.running and should_continue?(state) do
      case execute_turn(state) do
        {:ok, new_state} ->
          schedule_next_turn(new_state)
          {:noreply, new_state}

        {:error, reason} ->
          Logger.error("Turn execution failed: #{inspect(reason)}")
          notify_observers(state, {:error, reason})
          {:noreply, %{state | running: false}}
      end
    else
      {:noreply, %{state | running: false}}
    end
  end

  ## Private Functions

  defp via_tuple(conversation_id) do
    {:via, Registry, {Dspy.MultiAgentChat.Registry, conversation_id}}
  end

  defp generate_id do
    "chat_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp create_diverse_agents(num_agents, opts) when num_agents <= 12 do
    models = Enum.take(@cost_effective_models, num_agents)
    personalities = Enum.take(@default_personalities, num_agents)
    roles = Enum.take(@default_roles, num_agents)

    Enum.zip([models, personalities, roles])
    |> Enum.with_index()
    |> Enum.map(fn {{model, personality, role}, index} ->
      %{
        name: "#{model}",
        model: model,
        personality: personality,
        role: role,
        # Slight variation in creativity
        temperature: 0.7 + index * 0.05,
        max_tokens: Keyword.get(opts, :max_tokens, 300)
      }
    end)
  end

  defp create_opening_message(topic, participants) do
    participant_intro =
      participants
      |> Enum.with_index()
      |> Enum.map(fn {agent, _index} ->
        "#{agent.name} (#{agent.role}, #{agent.model})"
      end)
      |> Enum.join(", ")

    %{
      speaker: "System",
      model: "system",
      role: "system",
      content: """
      Welcome to a multi-agent conversation about: #{topic}

      Participants: #{participant_intro}

      Each participant should contribute their unique perspective based on their role and expertise.
      Keep responses concise but meaningful. Build on previous contributions and engage constructively.

      Let's begin the discussion!
      """,
      timestamp: DateTime.utc_now(),
      turn: 0
    }
  end

  defp should_continue?(state) do
    case state.max_turns do
      :unlimited -> true
      max when is_integer(max) -> state.turn_counter < max
    end
  end

  defp execute_turn(state) do
    current_agent = Enum.at(state.participants, state.current_speaker)

    if current_agent do
      case generate_response(current_agent, state) do
        {:ok, response} ->
          message = %{
            speaker: current_agent.name,
            model: current_agent.model,
            role: current_agent.role,
            content: response,
            timestamp: DateTime.utc_now(),
            turn: state.turn_counter + 1
          }

          new_state =
            state
            |> add_message_to_history(message)
            |> advance_turn()

          notify_observers(new_state, {:new_message, message})

          {:ok, new_state}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :no_current_agent}
    end
  end

  defp generate_response(agent, state) do
    # Build context from recent conversation history
    context_messages = build_context_messages(agent, state)

    client =
      Dspy.LM.OpenAI.new(
        model: agent.model,
        api_key: System.get_env("OPENAI_API_KEY")
      )

    # Use appropriate parameters based on model type - always use standard chat format
    request = %{
      messages: context_messages,
      max_tokens: agent.max_tokens,
      temperature: agent.temperature
    }

    case Dspy.LM.generate(client, request) do
      {:ok, response} ->
        case get_in(response, [:choices, Access.at(0), :message, "content"]) do
          content when is_binary(content) ->
            cleaned_content =
              content
              |> fix_encoding_issues()
              |> String.trim()

            {:ok, cleaned_content}

          _ ->
            {:error, :invalid_response_format}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fix_encoding_issues(content) do
    content
    # Fix multiplication sign
    |> String.replace("Ã", "×")
    # Fix approximately equals
    |> String.replace("â", "≈")
    # Fix degree symbol
    |> String.replace("Â°", "°")
  end

  defp build_context_messages(agent, state) do
    system_message = %{
      "role" => "system",
      "content" => """
      You are #{agent.name}, a #{agent.role} participating in a multi-agent conversation.
      Your personality: #{agent.personality}

      Topic: #{state.topic}

      Instructions:
      - Stay in character as #{agent.role}
      - Express your unique perspective based on your expertise
      - Keep responses concise but meaningful (under #{state.conversation_rules.max_message_length} characters)
      - Build on previous messages and engage constructively
      - Don't repeat what others have already said well
      - Ask questions or propose new angles when appropriate
      """
    }

    # Get recent conversation history (last 10 messages to avoid token limits)
    recent_history =
      state.conversation_history
      |> Enum.take(-10)
      |> Enum.map(fn msg ->
        %{
          "role" => if(msg.speaker == agent.name, do: "assistant", else: "user"),
          "content" => "#{msg.speaker}: #{msg.content}"
        }
      end)

    [system_message | recent_history]
  end

  defp add_message_to_history(state, message) do
    %{state | conversation_history: state.conversation_history ++ [message]}
  end

  defp advance_turn(state) do
    next_speaker = rem(state.current_speaker + 1, length(state.participants))
    %{state | current_speaker: next_speaker, turn_counter: state.turn_counter + 1}
  end

  defp schedule_next_turn(state) do
    if state.running and state.conversation_rules.auto_continue do
      # 2 second delay between turns
      Process.send_after(self(), :next_turn, 2000)
    end
  end

  defp notify_observers(state, message) do
    Enum.each(state.observers, fn observer ->
      send(observer, {__MODULE__, state.conversation_id, message})
    end)
  end

  ## Utility Functions

  @doc """
  Get available cost-effective models for multi-agent testing.
  """
  def get_cost_effective_models, do: @cost_effective_models

  @doc """
  Print conversation history in a readable format.
  """
  def print_conversation(conversation_id) do
    case get_state(conversation_id) do
      %__MODULE__{conversation_history: history} ->
        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("MULTI-AGENT CONVERSATION")
        IO.puts(String.duplicate("=", 80))

        Enum.each(history, fn msg ->
          timestamp = Calendar.strftime(msg.timestamp, "%H:%M:%S")
          IO.puts("\n[#{timestamp}] #{msg.speaker} (#{msg.model}):")
          IO.puts("#{msg.content}")
          IO.puts(String.duplicate("-", 40))
        end)

        IO.puts("\n" <> String.duplicate("=", 80))

      error ->
        IO.puts("Error retrieving conversation: #{inspect(error)}")
    end
  end
end
