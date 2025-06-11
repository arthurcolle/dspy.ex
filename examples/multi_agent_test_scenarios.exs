#!/usr/bin/env elixir

# Comprehensive multi-agent test scenarios for DSPy
# This script demonstrates various unbounded conversation scenarios

# Load the application modules
case Application.ensure_all_started(:dspy) do
  {:ok, _} -> 
    IO.puts("✓ DSPy application started successfully")
  {:error, reason} -> 
    IO.puts("✗ Failed to start DSPy application: #{inspect(reason)}")
    System.halt(1)
end

# Wait a moment for the registry to be ready
Process.sleep(100)

defmodule MultiAgentTestScenarios do
  @moduledoc """
  Comprehensive test scenarios for multi-agent conversations.
  
  This module provides various conversation scenarios that can run unbounded
  with different configurations and topics.
  """

  require Logger

  # Helper function to safely get input with a default value
  defp safe_gets(prompt, default \\ "") do
    case IO.gets(prompt) do
      :eof -> default
      input -> String.trim(input)
    end
  end

  @test_scenarios [
    %{
      name: "Technical Problem Solving",
      topic: "How should we design a distributed system that can handle 1 million concurrent users with 99.9% uptime?",
      agents: 8,
      description: "Technical experts collaborate on system architecture",
      duration_minutes: 30
    },
    %{
      name: "Creative Brainstorming",
      topic: "Imagine we're creating a new form of entertainment that combines AI, virtual reality, and social interaction. What should it look like?",
      agents: 6,
      description: "Creative minds explore innovative entertainment concepts",
      duration_minutes: 25
    },
    %{
      name: "Ethical Debate",
      topic: "Should AI systems be given legal rights and responsibilities? What are the implications for society?",
      agents: 10,
      description: "Philosophical and ethical discussion on AI rights",
      duration_minutes: 40
    },
    %{
      name: "Scientific Research Planning",
      topic: "How can we accelerate the development of sustainable fusion energy? What research priorities should we focus on?",
      agents: 7,
      description: "Scientists collaborate on research strategy",
      duration_minutes: 35
    },
    %{
      name: "Business Strategy Session",
      topic: "A startup wants to revolutionize online education. What business model, technology stack, and go-to-market strategy should they pursue?",
      agents: 9,
      description: "Business experts develop startup strategy",
      duration_minutes: 45
    },
    %{
      name: "Crisis Management Simulation",
      topic: "A major cyber attack has affected critical infrastructure in multiple countries. How should international organizations coordinate their response?",
      agents: 12,
      description: "Emergency response and coordination planning",
      duration_minutes: 50
    },
    %{
      name: "Future of Work Discussion",
      topic: "With AI automating many jobs, how should society restructure work, education, and economic systems over the next 20 years?",
      agents: 8,
      description: "Societal and economic transformation planning",
      duration_minutes: 40
    },
    %{
      name: "Climate Action Planning",
      topic: "What concrete steps can we take in the next 5 years to significantly reduce global carbon emissions while maintaining economic growth?",
      agents: 11,
      description: "Environmental and economic policy coordination",
      duration_minutes: 45
    }
  ]

  @conversation_styles [
    %{
      name: "Structured Debate",
      rules: %{
        max_message_length: 400,
        turn_timeout_ms: 45_000,
        moderation_enabled: true,
        auto_continue: true
      },
      description: "Formal debate with structured arguments"
    },
    %{
      name: "Free-flowing Discussion",
      rules: %{
        max_message_length: 300,
        turn_timeout_ms: 30_000,
        moderation_enabled: false,
        auto_continue: true
      },
      description: "Natural conversation flow with minimal constraints"
    },
    %{
      name: "Rapid Brainstorming",
      rules: %{
        max_message_length: 200,
        turn_timeout_ms: 20_000,
        moderation_enabled: false,
        auto_continue: true
      },
      description: "Quick idea generation and building"
    },
    %{
      name: "Deep Analysis",
      rules: %{
        max_message_length: 600,
        turn_timeout_ms: 60_000,
        moderation_enabled: true,
        auto_continue: true
      },
      description: "Thorough exploration of complex topics"
    }
  ]

  def main do
    IO.puts("🤖 Multi-Agent Test Scenarios for DSPy")
    IO.puts("=====================================\n")
    
    # Check for API key
    unless System.get_env("OPENAI_API_KEY") do
      IO.puts("❌ Error: OPENAI_API_KEY environment variable not set")
      IO.puts("Please set your OpenAI API key before running the tests.")
      System.halt(1)
    end
    
    # Start required services
    start_services()
    
    # Show available scenarios
    show_scenarios()
    
    # Interactive menu
    run_interactive_menu()
  end

  defp start_services do
    IO.puts("🚀 Starting multi-agent services...")
    
    # Services are now started automatically by the application supervisor
    # Just verify they're running
    case Registry.lookup(Dspy.MultiAgentChat.Registry, "test") do
      [] -> :ok  # Registry is working
      _ -> :ok
    end
    
    IO.puts("✅ Services started successfully\n")
  end

  defp show_scenarios do
    IO.puts("📋 Available Test Scenarios:")
    IO.puts("============================")
    
    @test_scenarios
    |> Enum.with_index(1)
    |> Enum.each(fn {scenario, index} ->
      IO.puts("#{index}. #{scenario.name}")
      IO.puts("   Topic: #{scenario.topic}")
      IO.puts("   Agents: #{scenario.agents} | Duration: #{scenario.duration_minutes} min")
      IO.puts("   #{scenario.description}\n")
    end)
  end

  defp run_interactive_menu do
    IO.puts("🎮 Interactive Menu:")
    IO.puts("===================")
    IO.puts("1. Run a specific scenario")
    IO.puts("2. Run all scenarios (sequential)")
    IO.puts("3. Run stress test (multiple concurrent conversations)")
    IO.puts("4. Custom scenario builder")
    IO.puts("5. View conversation logs")
    IO.puts("6. Exit")
    
    choice = safe_gets("\nSelect an option (1-6): ", "6")
    
    case choice do
      "1" -> run_specific_scenario()
      "2" -> run_all_scenarios()
      "3" -> run_stress_test()
      "4" -> custom_scenario_builder()
      "5" -> view_conversation_logs()
      "6" -> IO.puts("👋 Goodbye!")
      _ -> 
        IO.puts("❌ Invalid choice. Please try again.\n")
        run_interactive_menu()
    end
  end

  defp run_specific_scenario do
    IO.puts("\n📝 Select a scenario (1-#{length(@test_scenarios)}):")
    
    choice_str = safe_gets("Enter scenario number: ", "1")
    choice = case Integer.parse(choice_str) do
      {num, ""} -> num
      _ -> 1
    end
    
    if choice >= 1 and choice <= length(@test_scenarios) do
      scenario = Enum.at(@test_scenarios, choice - 1)
      style = select_conversation_style()
      
      run_scenario(scenario, style)
    else
      IO.puts("❌ Invalid scenario number")
      run_specific_scenario()
    end
  end

  defp run_all_scenarios do
    IO.puts("\n🚀 Running all scenarios sequentially...")
    style = select_conversation_style()
    
    @test_scenarios
    |> Enum.with_index(1)
    |> Enum.each(fn {scenario, index} ->
      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("Running Scenario #{index}/#{length(@test_scenarios)}: #{scenario.name}")
      IO.puts(String.duplicate("=", 60))
      
      run_scenario(scenario, style)
      
      if index < length(@test_scenarios) do
        IO.puts("\n⏳ Waiting 10 seconds before next scenario...")
        Process.sleep(10_000)
      end
    end)
    
    IO.puts("\n✅ All scenarios completed!")
    run_interactive_menu()
  end

  defp run_stress_test do
    IO.puts("\n🔥 Stress Test: Multiple Concurrent Conversations")
    
    num_str = safe_gets("Number of concurrent conversations (1-5): ", "2")
    num_conversations = case Integer.parse(num_str) do
      {num, ""} -> num |> max(1) |> min(5)
      _ -> 2
    end
    
    IO.puts("🚀 Starting #{num_conversations} concurrent conversations...")
    
    # Start multiple conversations
    conversation_tasks = 1..num_conversations
    |> Enum.map(fn index ->
      scenario = Enum.random(@test_scenarios)
      style = Enum.random(@conversation_styles)
      
      Task.async(fn ->
        IO.puts("🎯 Starting conversation #{index}: #{scenario.name}")
        run_scenario(scenario, style, "stress_test_#{index}")
      end)
    end)
    
    # Wait for all to complete
    Task.await_many(conversation_tasks, :infinity)
    
    IO.puts("✅ Stress test completed!")
    run_interactive_menu()
  end

  defp custom_scenario_builder do
    IO.puts("\n🛠️ Custom Scenario Builder")
    IO.puts("==========================")
    
    name = IO.gets("Scenario name: ") |> String.trim()
    topic = IO.gets("Discussion topic: ") |> String.trim()
    
    agents = IO.gets("Number of agents (2-12): ") 
    |> String.trim() 
    |> String.to_integer() 
    |> max(2) 
    |> min(12)
    
    duration = IO.gets("Duration in minutes (5-120): ") 
    |> String.trim() 
    |> String.to_integer() 
    |> max(5) 
    |> min(120)
    
    custom_scenario = %{
      name: name,
      topic: topic,
      agents: agents,
      description: "Custom user-defined scenario",
      duration_minutes: duration
    }
    
    style = select_conversation_style()
    
    IO.puts("\n🚀 Starting custom scenario...")
    run_scenario(custom_scenario, style)
    
    run_interactive_menu()
  end

  defp view_conversation_logs do
    IO.puts("\n📊 Conversation Logs")
    IO.puts("===================")
    
    case Dspy.MultiAgentLogger.list_conversations() do
      [] ->
        IO.puts("No conversations logged yet.")
      
      conversations ->
        conversations
        |> Enum.with_index(1)
        |> Enum.each(fn {conv, index} ->
          start_time = Calendar.strftime(conv.start_time, "%Y-%m-%d %H:%M:%S")
          IO.puts("#{index}. #{conv.conversation_id}")
          IO.puts("   Started: #{start_time}")
          IO.puts("   Messages: #{conv.message_count}")
          IO.puts("   Participants: #{Enum.join(conv.participants, ", ")}")
        end)
        
        choice = IO.gets("\nView details for conversation (number) or 'back': ") |> String.trim()
        
        case Integer.parse(choice) do
          {index, ""} when index >= 1 and index <= length(conversations) ->
            conv = Enum.at(conversations, index - 1)
            view_conversation_details(conv.conversation_id)
          
          _ when choice == "back" ->
            :ok
          
          _ ->
            IO.puts("❌ Invalid choice")
        end
    end
    
    run_interactive_menu()
  end

  defp view_conversation_details(conversation_id) do
    case Dspy.MultiAgentLogger.get_analytics(conversation_id) do
      {:ok, analytics} ->
        IO.puts("\n📈 Analytics for #{conversation_id}")
        IO.puts(String.duplicate("=", 50))
        IO.puts("Total Messages: #{analytics.total_messages}")
        IO.puts("Duration: #{Map.get(analytics, :duration_seconds, 0)} seconds")
        IO.puts("Avg Response Time: #{Map.get(analytics, :average_response_time, 0)} ms")
        
        if Map.has_key?(analytics, :participation_balance) do
          balance = analytics.participation_balance
          IO.puts("Most Active: #{elem(balance.most_active, 0)} (#{elem(balance.most_active, 1)} messages)")
          IO.puts("Least Active: #{elem(balance.least_active, 0)} (#{elem(balance.least_active, 1)} messages)")
        end
        
      {:error, reason} ->
        IO.puts("❌ Error retrieving analytics: #{inspect(reason)}")
    end
    
    export_choice = IO.gets("\nExport conversation? (json/csv/markdown/html/no): ") |> String.trim()
    
    case export_choice do
      format when format in ["json", "csv", "markdown", "html"] ->
        format_atom = String.to_atom(format)
        case Dspy.MultiAgentLogger.export_conversation(conversation_id, format_atom) do
          {:ok, file_path} ->
            IO.puts("✅ Exported to: #{file_path}")
          {:error, reason} ->
            IO.puts("❌ Export failed: #{inspect(reason)}")
        end
      
      _ ->
        :ok
    end
  end

  defp select_conversation_style do
    IO.puts("\n🎨 Select Conversation Style:")
    
    @conversation_styles
    |> Enum.with_index(1)
    |> Enum.each(fn {style, index} ->
      IO.puts("#{index}. #{style.name} - #{style.description}")
    end)
    
    choice_str = safe_gets("Select style (1-#{length(@conversation_styles)}): ", "1")
    choice = case Integer.parse(choice_str) do
      {num, ""} -> num
      _ -> 1
    end
    
    if choice >= 1 and choice <= length(@conversation_styles) do
      Enum.at(@conversation_styles, choice - 1)
    else
      IO.puts("❌ Invalid choice, using default style")
      List.first(@conversation_styles)
    end
  end

  defp run_scenario(scenario, style, conversation_id \\ nil) do
    conversation_id = conversation_id || "scenario_#{System.system_time(:millisecond)}"
    
    # Ensure the application is started
    unless Process.whereis(Dspy.MultiAgentChat.Registry) do
      Application.ensure_all_started(:dspy)
      Process.sleep(500) # Give registry time to start
    end
    
    IO.puts("\n🎭 Starting: #{scenario.name}")
    IO.puts("📝 Topic: #{scenario.topic}")
    IO.puts("👥 Agents: #{scenario.agents}")
    IO.puts("⏱️  Duration: #{scenario.duration_minutes} minutes")
    IO.puts("🎨 Style: #{style.name}")
    
    # Start logging
    Dspy.MultiAgentLogger.start_logging(conversation_id, %{
      scenario_name: scenario.name,
      topic: scenario.topic,
      style: style.name,
      expected_duration: scenario.duration_minutes
    })
    
    # Create conversation
    case Dspy.MultiAgentChat.create_test_setup(
      scenario.agents,
      conversation_rules: style.rules,
      conversation_id: conversation_id
    ) do
      {:ok, _chat_pid} ->
        IO.puts("✓ Multi-agent chat created successfully")
        
        # Add observer for logging with error handling
        observer_pid = spawn(fn -> conversation_observer(conversation_id) end)
        
        case Dspy.MultiAgentChat.add_observer(conversation_id, observer_pid) do
          :ok -> 
            IO.puts("✓ Observer added successfully")
          {:error, reason} ->
            IO.puts("⚠️  Warning: Failed to add observer: #{inspect(reason)}")
            IO.puts("   Continuing without real-time observation...")
        end
        
      {:error, reason} ->
        IO.puts("✗ Failed to create multi-agent chat: #{inspect(reason)}")
        raise "Chat setup failed: #{inspect(reason)}"
    end
    
    # Start the conversation
    Dspy.MultiAgentChat.start_topic(conversation_id, scenario.topic)
    
    IO.puts("🚀 Conversation started! Running for #{scenario.duration_minutes} minutes...")
    IO.puts("💡 Press Ctrl+C to stop early or let it run automatically")
    
    # Monitor the conversation
    monitor_conversation(conversation_id, scenario.duration_minutes * 60 * 1000)
    
    # Stop logging and get final analytics
    case Dspy.MultiAgentLogger.stop_logging(conversation_id) do
      {:ok, analytics} ->
        IO.puts("\n📊 Final Analytics:")
        IO.puts("   Messages: #{analytics.total_messages}")
        IO.puts("   Duration: #{analytics.duration_seconds} seconds")
        IO.puts("   Avg Response: #{Float.round(analytics.average_response_time, 2)} ms")
        
      {:error, reason} ->
        IO.puts("❌ Error getting analytics: #{inspect(reason)}")
    end
    
    # Stop the conversation
    Dspy.MultiAgentChat.stop_conversation(conversation_id)
    
    IO.puts("✅ Scenario completed: #{scenario.name}\n")
  end

  defp conversation_observer(conversation_id) do
    receive do
      {Dspy.MultiAgentChat, ^conversation_id, {:new_message, message}} ->
        Dspy.MultiAgentLogger.log_message(conversation_id, message)
        
        # Print full message in real-time with chain of thought visibility
        timestamp = Calendar.strftime(message.timestamp, "%H:%M:%S")
        
        # Show full content to see complete chain of thought
        content_lines = String.split(message.content, "\n")
        
        IO.puts("\n[#{timestamp}] #{message.speaker} (#{message.model}):")
        IO.puts(String.duplicate("-", 60))
        
        Enum.each(content_lines, fn line ->
          IO.puts(line)
        end)
        
        IO.puts(String.duplicate("-", 60))
        
        conversation_observer(conversation_id)
      
      {Dspy.MultiAgentChat, ^conversation_id, {:conversation_started, topic}} ->
        Dspy.MultiAgentLogger.log_event(conversation_id, :conversation_started, %{topic: topic})
        conversation_observer(conversation_id)
      
      {Dspy.MultiAgentChat, ^conversation_id, {:conversation_ended, _history}} ->
        Dspy.MultiAgentLogger.log_event(conversation_id, :conversation_ended, %{})
        IO.puts("🏁 Conversation ended")
      
      {Dspy.MultiAgentChat, ^conversation_id, {:error, reason}} ->
        Dspy.MultiAgentLogger.log_event(conversation_id, :error, %{reason: reason})
        IO.puts("❌ Conversation error: #{inspect(reason)}")
        conversation_observer(conversation_id)
      
      _ ->
        conversation_observer(conversation_id)
    end
  end

  defp monitor_conversation(_conversation_id, duration_ms) do
    receive do
      :stop ->
        IO.puts("\n⏹️  Stopping conversation early...")
    after
      duration_ms ->
        IO.puts("\n⏰ Time limit reached, stopping conversation...")
    end
  end
end

# Run the main function if this script is executed directly
if __ENV__.file == Path.absname(__ENV__.file) do
  MultiAgentTestScenarios.main()
end