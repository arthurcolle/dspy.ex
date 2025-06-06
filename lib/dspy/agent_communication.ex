defmodule Dspy.AgentCommunication do
  @moduledoc """
  Agent Communication System for DSPy
  
  This module provides a comprehensive agent communication framework that enables:
  - Direct agent-to-agent messaging
  - Broadcast communication to multiple agents
  - Topic-based publish/subscribe patterns
  - Message routing and filtering
  - Conversation threading and history
  - Protocol negotiation between agents
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :agents,
    :communication_channels,
    :message_queue,
    :conversation_threads,
    :protocol_registry,
    :routing_table
  ]
  
  @type agent_id :: String.t()
  @type channel_id :: String.t()
  @type message_id :: String.t()
  
  @type message :: %{
    id: message_id(),
    from: agent_id(),
    to: agent_id() | :broadcast | {:channel, channel_id()},
    content: any(),
    timestamp: DateTime.t(),
    thread_id: String.t() | nil,
    protocol: atom(),
    metadata: map()
  }
  
  @type communication_protocol :: :direct | :request_response | :stream | :negotiation
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Register an agent with the communication system
  """
  def register_agent(agent_id, agent_info) do
    GenServer.call(__MODULE__, {:register_agent, agent_id, agent_info})
  end
  
  @doc """
  Send a direct message from one agent to another
  """
  def send_message(from_agent, to_agent, content, opts \\ []) do
    GenServer.call(__MODULE__, {:send_message, from_agent, to_agent, content, opts})
  end
  
  @doc """
  Broadcast a message to all agents or a specific channel
  """
  def broadcast(from_agent, content, opts \\ []) do
    GenServer.call(__MODULE__, {:broadcast, from_agent, content, opts})
  end
  
  @doc """
  Subscribe an agent to a communication channel
  """
  def subscribe(agent_id, channel_id) do
    GenServer.call(__MODULE__, {:subscribe, agent_id, channel_id})
  end
  
  @doc """
  Create a new conversation thread between agents
  """
  def start_conversation(initiator, participants, topic) do
    GenServer.call(__MODULE__, {:start_conversation, initiator, participants, topic})
  end
  
  @doc """
  Get conversation history for a thread
  """
  def get_conversation_history(thread_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_history, thread_id, opts})
  end
  
  @doc """
  Request collaboration between multiple agents on a task
  """
  def request_collaboration(requester, agents, task, opts \\ []) do
    GenServer.call(__MODULE__, {:request_collaboration, requester, agents, task, opts})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %__MODULE__{
      agents: %{},
      communication_channels: %{},
      message_queue: :queue.new(),
      conversation_threads: %{},
      protocol_registry: initialize_protocols(),
      routing_table: %{}
    }
    
    # Start message processor
    schedule_message_processing()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register_agent, agent_id, agent_info}, _from, state) do
    updated_agents = Map.put(state.agents, agent_id, %{
      id: agent_id,
      info: agent_info,
      inbox: [],
      subscriptions: [],
      active_conversations: [],
      capabilities: agent_info[:capabilities] || [],
      status: :online
    })
    
    # Update routing table
    updated_routing = update_routing_table(state.routing_table, agent_id, agent_info)
    
    {:reply, :ok, %{state | agents: updated_agents, routing_table: updated_routing}}
  end
  
  @impl true
  def handle_call({:send_message, from_agent, to_agent, content, opts}, _from, state) do
    message = create_message(from_agent, to_agent, content, opts)
    
    case route_message(state, message) do
      {:ok, updated_state} ->
        Logger.info("Message #{message.id} sent from #{from_agent} to #{to_agent}")
        {:reply, {:ok, message.id}, updated_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:broadcast, from_agent, content, opts}, _from, state) do
    channel = opts[:channel] || :global
    message = create_message(from_agent, {:channel, channel}, content, opts)
    
    # Route to all agents in channel
    recipients = get_channel_subscribers(state, channel)
    updated_state = Enum.reduce(recipients, state, fn agent_id, acc_state ->
      deliver_message(acc_state, agent_id, message)
    end)
    
    {:reply, {:ok, message.id}, updated_state}
  end
  
  @impl true
  def handle_call({:subscribe, agent_id, channel_id}, _from, state) do
    updated_channels = Map.update(state.communication_channels, channel_id, [agent_id], fn subscribers ->
      if agent_id in subscribers, do: subscribers, else: [agent_id | subscribers]
    end)
    
    # Update agent's subscriptions
    updated_agents = update_in(state.agents[agent_id].subscriptions, fn subs ->
      if channel_id in subs, do: subs, else: [channel_id | subs]
    end)
    
    {:reply, :ok, %{state | communication_channels: updated_channels, agents: updated_agents}}
  end
  
  @impl true
  def handle_call({:start_conversation, initiator, participants, topic}, _from, state) do
    thread_id = generate_thread_id()
    
    conversation = %{
      id: thread_id,
      initiator: initiator,
      participants: participants,
      topic: topic,
      messages: [],
      created_at: DateTime.utc_now(),
      status: :active
    }
    
    updated_threads = Map.put(state.conversation_threads, thread_id, conversation)
    
    # Notify participants
    notification = %{
      type: :conversation_started,
      thread_id: thread_id,
      topic: topic,
      initiator: initiator
    }
    
    updated_state = Enum.reduce(participants, state, fn participant, acc_state ->
      deliver_notification(acc_state, participant, notification)
    end)
    
    {:reply, {:ok, thread_id}, %{updated_state | conversation_threads: updated_threads}}
  end
  
  @impl true
  def handle_call({:get_history, thread_id, opts}, _from, state) do
    case Map.get(state.conversation_threads, thread_id) do
      nil -> 
        {:reply, {:error, :thread_not_found}, state}
        
      thread ->
        messages = apply_history_filters(thread.messages, opts)
        {:reply, {:ok, messages}, state}
    end
  end
  
  @impl true
  def handle_call({:request_collaboration, requester, agents, task, opts}, _from, state) do
    collaboration_id = generate_collaboration_id()
    
    # Create collaboration request message
    request = %{
      id: collaboration_id,
      type: :collaboration_request,
      requester: requester,
      task: task,
      required_capabilities: opts[:required_capabilities] || [],
      deadline: opts[:deadline],
      compensation: opts[:compensation]
    }
    
    # Send to selected agents based on capabilities
    eligible_agents = filter_agents_by_capability(state.agents, agents, request.required_capabilities)
    
    updated_state = Enum.reduce(eligible_agents, state, fn agent_id, acc_state ->
      message = create_message(requester, agent_id, request, protocol: :negotiation)
      deliver_message(acc_state, agent_id, message)
    end)
    
    {:reply, {:ok, collaboration_id}, updated_state}
  end
  
  @impl true
  def handle_info(:process_messages, state) do
    # Process queued messages
    {processed_state, _processed_count} = process_message_queue(state)
    
    # Schedule next processing
    schedule_message_processing()
    
    {:noreply, processed_state}
  end
  
  # Private Functions
  
  defp initialize_protocols do
    %{
      direct: %{
        handler: &handle_direct_message/3,
        validators: []
      },
      request_response: %{
        handler: &handle_request_response/3,
        validators: [:validate_response_format]
      },
      stream: %{
        handler: &handle_stream_message/3,
        validators: [:validate_stream_sequence]
      },
      negotiation: %{
        handler: &handle_negotiation/3,
        validators: [:validate_negotiation_terms]
      }
    }
  end
  
  defp create_message(from, to, content, opts) do
    %{
      id: generate_message_id(),
      from: from,
      to: to,
      content: content,
      timestamp: DateTime.utc_now(),
      thread_id: opts[:thread_id],
      protocol: opts[:protocol] || :direct,
      metadata: opts[:metadata] || %{}
    }
  end
  
  defp route_message(state, message) do
    case message.to do
      {:channel, _channel} ->
        # Handled by broadcast
        {:ok, state}
        
      to_agent when is_binary(to_agent) ->
        deliver_message(state, to_agent, message)
        
      _ ->
        {:error, :invalid_recipient}
    end
  end
  
  defp deliver_message(state, agent_id, message) do
    case Map.get(state.agents, agent_id) do
      nil -> 
        state
        
      agent ->
        # Add to agent's inbox
        updated_agent = Map.update!(agent, :inbox, fn inbox ->
          [message | inbox]
        end)
        
        # Trigger agent notification
        notify_agent(agent_id, message)
        
        put_in(state.agents[agent_id], updated_agent)
    end
  end
  
  defp deliver_notification(state, agent_id, notification) do
    notification_message = %{
      id: generate_message_id(),
      from: :system,
      to: agent_id,
      content: notification,
      timestamp: DateTime.utc_now(),
      protocol: :notification,
      metadata: %{type: :system_notification}
    }
    
    deliver_message(state, agent_id, notification_message)
  end
  
  defp notify_agent(agent_id, message) do
    # Send notification to agent process if it's running
    case Process.whereis(String.to_atom("agent_#{agent_id}")) do
      nil -> :ok
      pid -> send(pid, {:new_message, message})
    end
  end
  
  defp get_channel_subscribers(state, :global) do
    Map.keys(state.agents)
  end
  
  defp get_channel_subscribers(state, channel_id) do
    Map.get(state.communication_channels, channel_id, [])
  end
  
  defp filter_agents_by_capability(agents, requested_agents, required_capabilities) do
    requested_agents
    |> Enum.filter(fn agent_id ->
      case Map.get(agents, agent_id) do
        nil -> false
        agent -> has_required_capabilities?(agent, required_capabilities)
      end
    end)
  end
  
  defp has_required_capabilities?(agent, required_capabilities) do
    agent_capabilities = agent.info[:capabilities] || []
    Enum.all?(required_capabilities, &(&1 in agent_capabilities))
  end
  
  defp update_routing_table(routing_table, agent_id, agent_info) do
    # Update routing based on agent capabilities
    capabilities = agent_info[:capabilities] || []
    
    Enum.reduce(capabilities, routing_table, fn capability, acc ->
      Map.update(acc, capability, [agent_id], fn agents ->
        if agent_id in agents, do: agents, else: [agent_id | agents]
      end)
    end)
  end
  
  defp apply_history_filters(messages, opts) do
    messages
    |> filter_by_time_range(opts[:from], opts[:to])
    |> filter_by_participant(opts[:participant])
    |> limit_results(opts[:limit])
  end
  
  defp filter_by_time_range(messages, nil, nil), do: messages
  defp filter_by_time_range(messages, from, to) do
    Enum.filter(messages, fn msg ->
      after_from = is_nil(from) or DateTime.compare(msg.timestamp, from) != :lt
      before_to = is_nil(to) or DateTime.compare(msg.timestamp, to) != :gt
      after_from and before_to
    end)
  end
  
  defp filter_by_participant(messages, nil), do: messages
  defp filter_by_participant(messages, participant) do
    Enum.filter(messages, fn msg ->
      msg.from == participant or msg.to == participant
    end)
  end
  
  defp limit_results(messages, nil), do: messages
  defp limit_results(messages, limit), do: Enum.take(messages, limit)
  
  defp process_message_queue(state) do
    # Process any pending messages in queue
    # This is where we'd implement message ordering, retry logic, etc.
    {state, 0}
  end
  
  defp schedule_message_processing do
    Process.send_after(self(), :process_messages, 1000)
  end
  
  # Protocol Handlers
  
  defp handle_direct_message(_state, _message, _agent), do: :ok
  defp handle_request_response(_state, _message, _agent), do: :ok
  defp handle_stream_message(_state, _message, _agent), do: :ok
  defp handle_negotiation(_state, _message, _agent), do: :ok
  
  # ID Generation
  
  defp generate_message_id do
    "msg_#{:crypto.strong_rand_bytes(16) |> Base.encode16()}"
  end
  
  defp generate_thread_id do
    "thread_#{:crypto.strong_rand_bytes(16) |> Base.encode16()}"
  end
  
  defp generate_collaboration_id do
    "collab_#{:crypto.strong_rand_bytes(16) |> Base.encode16()}"
  end
end