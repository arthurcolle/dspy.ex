#!/usr/bin/env elixir

# Simple demonstration of multi-agent chat system
# This is a quick test to verify the system works

Mix.install([
  {:jason, "~> 1.4"}
])

Code.require_file("../lib/dspy.ex", __DIR__)
Code.require_file("../lib/dspy/lm.ex", __DIR__)
Code.require_file("../lib/dspy/lm/openai.ex", __DIR__)
Code.require_file("../lib/dspy/multi_agent_chat.ex", __DIR__)
Code.require_file("../lib/dspy/multi_agent_logger.ex", __DIR__)

defmodule SimpleMultiAgentDemo do
  @moduledoc """
  Simple demonstration of the multi-agent chat system.
  
  This demo creates a quick conversation between 4 different models
  to verify the system is working correctly.
  """

  def run_demo do
    IO.puts("🤖 Simple Multi-Agent Chat Demo")
    IO.puts("================================\n")
    
    # Check for API key
    unless System.get_env("OPENAI_API_KEY") do
      IO.puts("❌ Error: OPENAI_API_KEY environment variable not set")
      IO.puts("To run this demo, please set your OpenAI API key:")
      IO.puts("export OPENAI_API_KEY='your-api-key-here'")
      System.halt(1)
    end
    
    # Start services
    IO.puts("🚀 Starting services...")
    {:ok, _} = Registry.start_link(keys: :unique, name: Dspy.MultiAgentChat.Registry)
    {:ok, _} = Dspy.MultiAgentLogger.start_link()
    IO.puts("✅ Services started\n")
    
    # Test model availability
    IO.puts("🔍 Testing model availability...")
    test_models()
    
    # Run a quick conversation
    IO.puts("💬 Starting quick conversation demo...")
    run_quick_conversation()
    
    IO.puts("\n✅ Demo completed successfully!")
  end

  defp test_models do
    cost_effective_models = Dspy.MultiAgentChat.get_cost_effective_models()
    IO.puts("Available cost-effective models: #{length(cost_effective_models)}")
    
    # Test a few models
    test_models = Enum.take(cost_effective_models, 3)
    
    Enum.each(test_models, fn model ->
      try do
        client = Dspy.LM.OpenAI.new(model: model, api_key: "test-key")
        features = [:chat, :tools, :vision, :reasoning]
        |> Enum.filter(&Dspy.LM.OpenAI.supports?(client, &1))
        
        IO.puts("  ✅ #{model}: #{inspect(features)}")
      rescue
        e ->
          IO.puts("  ❌ #{model}: #{Exception.message(e)}")
      end
    end)
    
    IO.puts("")
  end

  defp run_quick_conversation do
    conversation_id = "demo_#{System.system_time(:millisecond)}"
    
    # Start logging
    Dspy.MultiAgentLogger.start_logging(conversation_id, %{
      demo: true,
      topic: "Quick demo conversation"
    })
    
    # Create a conversation with 4 agents
    {:ok, _chat_pid} = Dspy.MultiAgentChat.create_test_setup(4, 
      conversation_id: conversation_id,
      max_turns: 12,  # Limit for demo
      conversation_rules: %{
        max_message_length: 200,
        turn_timeout_ms: 30_000,
        moderation_enabled: false,
        auto_continue: true
      }
    )
    
    # Add observer for real-time display
    observer_pid = spawn(fn -> demo_observer(conversation_id, 0) end)
    Dspy.MultiAgentChat.add_observer(conversation_id, observer_pid)
    
    # Start the conversation
    topic = "What's the most exciting possibility for AI in the next 5 years?"
    Dspy.MultiAgentChat.start_topic(conversation_id, topic)
    
    IO.puts("🎯 Topic: #{topic}")
    IO.puts("⏱️  Running for 60 seconds or 12 turns...\n")
    
    # Wait for completion
    Process.sleep(60_000)  # 60 seconds
    
    # Stop the conversation
    Dspy.MultiAgentChat.stop_conversation(conversation_id)
    
    # Get final analytics
    case Dspy.MultiAgentLogger.stop_logging(conversation_id) do
      {:ok, analytics} ->
        IO.puts("\n📊 Demo Results:")
        IO.puts("   Total Messages: #{analytics.total_messages}")
        IO.puts("   Duration: #{analytics.duration_seconds} seconds")
        
        if Map.has_key?(analytics, :participation_balance) do
          balance = analytics.participation_balance
          {most_active, most_count} = balance.most_active
          IO.puts("   Most Active: #{most_active} (#{most_count} messages)")
        end
        
      {:error, reason} ->
        IO.puts("❌ Error getting analytics: #{inspect(reason)}")
    end
  end

  defp demo_observer(conversation_id, message_count) do
    receive do
      {Dspy.MultiAgentChat, ^conversation_id, {:new_message, message}} ->
        Dspy.MultiAgentLogger.log_message(conversation_id, message)
        
        # Display message
        timestamp = Calendar.strftime(message.timestamp, "%H:%M:%S")
        IO.puts("[#{timestamp}] #{message.speaker} (#{message.model}):")
        IO.puts("  #{message.content}\n")
        
        demo_observer(conversation_id, message_count + 1)
      
      {Dspy.MultiAgentChat, ^conversation_id, {:conversation_started, _topic}} ->
        Dspy.MultiAgentLogger.log_event(conversation_id, :conversation_started, %{})
        IO.puts("🎬 Conversation started!\n")
        demo_observer(conversation_id, message_count)
      
      {Dspy.MultiAgentChat, ^conversation_id, {:conversation_ended, _history}} ->
        Dspy.MultiAgentLogger.log_event(conversation_id, :conversation_ended, %{})
        IO.puts("🏁 Conversation ended")
      
      {Dspy.MultiAgentChat, ^conversation_id, {:error, reason}} ->
        Dspy.MultiAgentLogger.log_event(conversation_id, :error, %{reason: reason})
        IO.puts("❌ Error: #{inspect(reason)}")
        demo_observer(conversation_id, message_count)
      
      _ ->
        demo_observer(conversation_id, message_count)
    end
  end
end

# Run if executed directly
if __ENV__.file == Path.absname(__ENV__.file) do
  SimpleMultiAgentDemo.run_demo()
end