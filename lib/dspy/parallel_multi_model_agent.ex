defmodule Dspy.ParallelMultiModelAgent do
  @moduledoc """
  A parallel multi-model agent that leverages multiple AI models simultaneously
  to solve complex problems through distributed reasoning and consensus.

  Features:
  - Parallel query execution across multiple models
  - Intelligent model selection based on task characteristics
  - Consensus algorithms for combining model outputs
  - Dynamic load balancing and failover
  - Real-time performance monitoring and optimization
  """

  use GenServer
  require Logger

  defstruct [
    :agent_id,
    :models,
    :task_queue,
    :execution_pool,
    :consensus_engine,
    :performance_tracker,
    :coordination_strategy,
    :active_tasks,
    :model_capabilities
  ]

  @type model_config :: %{
    id: atom(),
    client: any(),
    capabilities: [atom()],
    performance_score: float(),
    cost_per_token: float(),
    max_context: integer(),
    specializations: [atom()]
  }

  @type task :: %{
    id: String.t(),
    type: atom(),
    prompt: String.t(),
    context: map(),
    priority: atom(),
    deadline: DateTime.t(),
    complexity: atom(),
    models_assigned: [atom()]
  }

  @type consensus_result :: %{
    final_answer: String.t(),
    confidence: float(),
    contributing_models: [atom()],
    reasoning_paths: [String.t()],
    execution_time: integer(),
    token_usage: integer()
  }

  ## Client API

  @doc """
  Start a new parallel multi-model agent.
  """
  def start_link(opts \\ []) do
    agent_id = Keyword.get(opts, :agent_id, generate_agent_id())
    GenServer.start_link(__MODULE__, opts, name: via_tuple(agent_id))
  end

  @doc """
  Execute a task using multiple models in parallel.
  """
  def execute_parallel_task(agent_id, task_spec) do
    GenServer.call(via_tuple(agent_id), {:execute_parallel_task, task_spec}, 60_000)
  end

  @doc """
  Get agent status and performance metrics.
  """
  def get_agent_status(agent_id) do
    GenServer.call(via_tuple(agent_id), :get_status)
  end

  @doc """
  Update model configurations dynamically.
  """
  def update_models(agent_id, model_configs) do
    GenServer.call(via_tuple(agent_id), {:update_models, model_configs})
  end

  @doc """
  Set consensus strategy for combining model outputs.
  """
  def set_consensus_strategy(agent_id, strategy) do
    GenServer.call(via_tuple(agent_id), {:set_consensus_strategy, strategy})
  end

  @doc """
  Get cost analysis for different model combinations.
  """
  def analyze_costs(agent_id, task_spec) do
    GenServer.call(via_tuple(agent_id), {:analyze_costs, task_spec})
  end

  @doc """
  Get model recommendations based on requirements.
  """
  def get_model_recommendations(requirements) do
    # Static function that doesn't require agent instance
    recommend_models_for_requirements(requirements)
  end

  ## GenServer Implementation

  @impl true
  def init(opts) do
    agent_id = Keyword.get(opts, :agent_id, generate_agent_id())
    models = initialize_models(Keyword.get(opts, :models, []))
    
    state = %__MODULE__{
      agent_id: agent_id,
      models: models,
      task_queue: :queue.new(),
      execution_pool: initialize_execution_pool(),
      consensus_engine: initialize_consensus_engine(),
      performance_tracker: initialize_performance_tracker(),
      coordination_strategy: Keyword.get(opts, :coordination_strategy, :weighted_voting),
      active_tasks: %{},
      model_capabilities: analyze_model_capabilities(models)
    }

    Logger.info("Parallel Multi-Model Agent #{agent_id} initialized with #{map_size(models)} models")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute_parallel_task, task_spec}, _from, state) do
    task = prepare_task(task_spec, state)
    selected_models = select_optimal_models(task, state.models, state.model_capabilities)
    
    # Execute in parallel using Task.async_stream
    execution_start = System.monotonic_time(:millisecond)
    
    results = execute_models_parallel(task, selected_models, state)
    consensus_result = apply_consensus_algorithm(results, task, state.consensus_engine, state.coordination_strategy)
    
    execution_time = System.monotonic_time(:millisecond) - execution_start
    
    # Update performance tracking
    updated_tracker = update_performance_metrics(
      state.performance_tracker, 
      task, 
      consensus_result, 
      execution_time
    )
    
    updated_state = %{state | performance_tracker: updated_tracker}
    
    {:reply, {:ok, consensus_result}, updated_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      agent_id: state.agent_id,
      models: Map.keys(state.models),
      active_tasks: map_size(state.active_tasks),
      queue_size: :queue.len(state.task_queue),
      performance_metrics: state.performance_tracker,
      model_capabilities: state.model_capabilities,
      coordination_strategy: state.coordination_strategy
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_call({:update_models, model_configs}, _from, state) do
    updated_models = update_model_configurations(state.models, model_configs)
    updated_capabilities = analyze_model_capabilities(updated_models)
    
    updated_state = %{state | 
      models: updated_models, 
      model_capabilities: updated_capabilities
    }
    
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:set_consensus_strategy, strategy}, _from, state) do
    updated_state = %{state | coordination_strategy: strategy}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:analyze_costs, task_spec}, _from, state) do
    task = prepare_task(task_spec, state)
    cost_analysis = generate_cost_analysis(task, state.models, state.model_capabilities)
    {:reply, {:ok, cost_analysis}, state}
  end

  ## Private Functions

  defp initialize_models(model_configs) when is_list(model_configs) and length(model_configs) > 0 do
    Enum.reduce(model_configs, %{}, fn config, acc ->
      Map.put(acc, config.id, config)
    end)
  end

  defp initialize_models(_) do
    # Comprehensive model configuration with all OpenAI models
    %{
      # Flagship Models - Highest Performance
      gpt45_preview: %{
        id: :gpt45_preview,
        client: create_openai_client("gpt-4.5-preview"),
        capabilities: [:advanced_reasoning, :research, :complex_analysis, :frontier_capabilities],
        performance_score: 0.98,
        cost_per_token: 0.075,
        max_context: 200000,
        specializations: [:frontier_research, :complex_reasoning, :advanced_analysis],
        category: :flagship,
        use_cases: [:research, :complex_problem_solving, :advanced_analysis]
      },
      
      # GPT-4.1 Series - Latest Generation
      gpt41: %{
        id: :gpt41,
        client: create_openai_client("gpt-4.1"),
        capabilities: [:reasoning, :coding, :analysis, :creative, :multimodal],
        performance_score: 0.96,
        cost_per_token: 0.002,
        max_context: 200000,
        specializations: [:latest_capabilities, :general_excellence, :multimodal],
        category: :latest,
        use_cases: [:general_purpose, :coding, :analysis, :creative_tasks]
      },
      gpt41_mini: %{
        id: :gpt41_mini,
        client: create_openai_client("gpt-4.1-mini"),
        capabilities: [:reasoning, :coding, :analysis, :fast_response],
        performance_score: 0.90,
        cost_per_token: 0.0004,
        max_context: 128000,
        specializations: [:cost_efficient, :fast_response, :balanced_performance],
        category: :efficient,
        use_cases: [:general_purpose, :cost_sensitive, :fast_response]
      },
      gpt41_nano: %{
        id: :gpt41_nano,
        client: create_openai_client("gpt-4.1-nano"),
        capabilities: [:general, :fast_response, :cost_efficient],
        performance_score: 0.82,
        cost_per_token: 0.0001,
        max_context: 128000,
        specializations: [:ultra_cost_efficient, :speed, :simple_tasks],
        category: :efficient,
        use_cases: [:simple_tasks, :high_volume, :cost_optimization]
      },

      # O-Series - Reasoning Models
      o1: %{
        id: :o1,
        client: create_openai_client("o1"),
        capabilities: [:deep_reasoning, :problem_solving, :mathematics, :science],
        performance_score: 0.97,
        cost_per_token: 0.015,
        max_context: 200000,
        specializations: [:deep_reasoning, :mathematical_thinking, :scientific_analysis],
        category: :reasoning,
        use_cases: [:complex_reasoning, :mathematics, :science, :research]
      },
      o1_pro: %{
        id: :o1_pro,
        client: create_openai_client("o1-pro"),
        capabilities: [:advanced_reasoning, :expert_analysis, :research, :complex_problem_solving],
        performance_score: 0.99,
        cost_per_token: 0.15,
        max_context: 200000,
        specializations: [:expert_reasoning, :research_grade, :premium_analysis],
        category: :premium,
        use_cases: [:expert_analysis, :research, :complex_projects, :premium_applications]
      },
      o3: %{
        id: :o3,
        client: create_openai_client("o3"),
        capabilities: [:advanced_reasoning, :problem_solving, :analysis],
        performance_score: 0.94,
        cost_per_token: 0.01,
        max_context: 200000,
        specializations: [:advanced_reasoning, :problem_solving],
        category: :reasoning,
        use_cases: [:reasoning_tasks, :problem_solving, :analysis]
      },
      o4_mini: %{
        id: :o4_mini,
        client: create_openai_client("o4-mini"),
        capabilities: [:reasoning, :cost_efficient, :fast_response],
        performance_score: 0.85,
        cost_per_token: 0.0011,
        max_context: 128000,
        specializations: [:efficient_reasoning, :cost_optimization],
        category: :efficient,
        use_cases: [:reasoning_tasks, :cost_sensitive, :batch_processing]
      },
      o3_mini: %{
        id: :o3_mini,
        client: create_openai_client("o3-mini"),
        capabilities: [:reasoning, :fast_response, :cost_efficient],
        performance_score: 0.83,
        cost_per_token: 0.0011,
        max_context: 128000,
        specializations: [:mini_reasoning, :cost_efficiency],
        category: :efficient,
        use_cases: [:simple_reasoning, :cost_optimization, :high_volume]
      },
      o1_mini: %{
        id: :o1_mini,
        client: create_openai_client("o1-mini"),
        capabilities: [:reasoning, :problem_solving, :cost_efficient],
        performance_score: 0.82,
        cost_per_token: 0.0011,
        max_context: 128000,
        specializations: [:compact_reasoning, :efficiency],
        category: :efficient,
        use_cases: [:reasoning_tasks, :cost_sensitive, :educational]
      },

      # GPT-4o Series - Omni Models
      gpt4o: %{
        id: :gpt4o,
        client: create_openai_client("gpt-4o"),
        capabilities: [:reasoning, :coding, :analysis, :creative, :multimodal],
        performance_score: 0.95,
        cost_per_token: 0.0025,
        max_context: 128000,
        specializations: [:multimodal, :general_excellence, :omni_capabilities],
        category: :multimodal,
        use_cases: [:general_purpose, :multimodal_tasks, :content_creation]
      },
      gpt4o_mini: %{
        id: :gpt4o_mini,
        client: create_openai_client("gpt-4o-mini"),
        capabilities: [:reasoning, :coding, :analysis, :fast_response, :multimodal],
        performance_score: 0.88,
        cost_per_token: 0.00015,
        max_context: 128000,
        specializations: [:cost_efficient_multimodal, :fast_response],
        category: :efficient_multimodal,
        use_cases: [:general_purpose, :cost_sensitive, :multimodal_tasks]
      },

      # Audio-Enabled Models
      gpt4o_audio: %{
        id: :gpt4o_audio,
        client: create_openai_client("gpt-4o-audio-preview"),
        capabilities: [:audio_processing, :multimodal, :reasoning, :creative],
        performance_score: 0.92,
        cost_per_token: 0.0025,
        max_context: 128000,
        specializations: [:audio_capabilities, :multimodal_audio],
        category: :audio,
        use_cases: [:audio_processing, :voice_applications, :multimedia]
      },
      gpt4o_mini_audio: %{
        id: :gpt4o_mini_audio,
        client: create_openai_client("gpt-4o-mini-audio-preview"),
        capabilities: [:audio_processing, :multimodal, :cost_efficient],
        performance_score: 0.85,
        cost_per_token: 0.00015,
        max_context: 128000,
        specializations: [:cost_efficient_audio, :basic_audio],
        category: :efficient_audio,
        use_cases: [:audio_processing, :cost_sensitive_audio, :voice_apps]
      },

      # Search-Enhanced Models
      gpt4o_search: %{
        id: :gpt4o_search,
        client: create_openai_client("gpt-4o-search-preview"),
        capabilities: [:web_search, :real_time_info, :research, :analysis],
        performance_score: 0.93,
        cost_per_token: 0.0025,
        max_context: 128000,
        specializations: [:web_search, :real_time_information, :research],
        category: :search,
        use_cases: [:research, :current_events, :fact_checking, :web_search]
      },
      gpt4o_mini_search: %{
        id: :gpt4o_mini_search,
        client: create_openai_client("gpt-4o-mini-search-preview"),
        capabilities: [:web_search, :real_time_info, :cost_efficient],
        performance_score: 0.86,
        cost_per_token: 0.00015,
        max_context: 128000,
        specializations: [:cost_efficient_search, :basic_search],
        category: :efficient_search,
        use_cases: [:web_search, :cost_sensitive_research, :fact_checking]
      },

      # Specialized Models
      codex_mini: %{
        id: :codex_mini,
        client: create_openai_client("codex-mini-latest"),
        capabilities: [:code_generation, :programming, :technical_analysis],
        performance_score: 0.89,
        cost_per_token: 0.0015,
        max_context: 128000,
        specializations: [:code_generation, :programming, :software_development],
        category: :coding,
        use_cases: [:code_generation, :programming_assistance, :technical_tasks]
      },
      computer_use: %{
        id: :computer_use,
        client: create_openai_client("computer-use-preview"),
        capabilities: [:computer_interaction, :automation, :gui_control],
        performance_score: 0.87,
        cost_per_token: 0.003,
        max_context: 128000,
        specializations: [:computer_control, :automation, :gui_interaction],
        category: :automation,
        use_cases: [:automation, :computer_control, :gui_testing, :rpa]
      },

      # Legacy but Reliable Models
      chatgpt4o_latest: %{
        id: :chatgpt4o_latest,
        client: create_openai_client("chatgpt-4o-latest"),
        capabilities: [:chat, :general_purpose, :reliable],
        performance_score: 0.91,
        cost_per_token: 0.005,
        max_context: 128000,
        specializations: [:chat_optimized, :conversational],
        category: :chat,
        use_cases: [:chat_applications, :conversational_ai, :general_purpose]
      },
      gpt4_turbo: %{
        id: :gpt4_turbo,
        client: create_openai_client("gpt-4-turbo"),
        capabilities: [:reasoning, :coding, :analysis, :reliable],
        performance_score: 0.90,
        cost_per_token: 0.01,
        max_context: 128000,
        specializations: [:proven_performance, :reliable],
        category: :legacy,
        use_cases: [:general_purpose, :reliable_performance, :production]
      },
      gpt4: %{
        id: :gpt4,
        client: create_openai_client("gpt-4"),
        capabilities: [:reasoning, :analysis, :reliable],
        performance_score: 0.88,
        cost_per_token: 0.03,
        max_context: 8000,
        specializations: [:proven_reliability, :stable],
        category: :legacy,
        use_cases: [:reliable_performance, :stable_applications]
      },
      
      # Cost-Efficient Models
      gpt35_turbo: %{
        id: :gpt35_turbo,
        client: create_openai_client("gpt-3.5-turbo"),
        capabilities: [:general, :fast_response, :cost_efficient],
        performance_score: 0.75,
        cost_per_token: 0.0005,
        max_context: 16000,
        specializations: [:ultra_cost_efficient, :speed, :high_volume],
        category: :budget,
        use_cases: [:simple_tasks, :high_volume, :cost_optimization, :prototyping]
      },
      gpt35_turbo_instruct: %{
        id: :gpt35_turbo_instruct,
        client: create_openai_client("gpt-3.5-turbo-instruct"),
        capabilities: [:instruction_following, :completion, :cost_efficient],
        performance_score: 0.76,
        cost_per_token: 0.0015,
        max_context: 4000,
        specializations: [:instruction_following, :completion_tasks],
        category: :instruction,
        use_cases: [:instruction_following, :completion_tasks, :simple_automation]
      }
    }
  end

  defp create_openai_client(model) do
    Dspy.LM.OpenAI.new(
      model: model,
      api_key: System.get_env("OPENAI_API_KEY")
    )
  end


  defp prepare_task(task_spec, _state) do
    %{
      id: task_spec[:id] || generate_task_id(),
      type: task_spec[:type] || :general,
      prompt: task_spec[:prompt] || "",
      context: task_spec[:context] || %{},
      priority: task_spec[:priority] || :medium,
      deadline: task_spec[:deadline] || DateTime.add(DateTime.utc_now(), 300, :second),
      complexity: analyze_task_complexity(task_spec[:prompt] || ""),
      models_assigned: []
    }
  end

  defp select_optimal_models(task, models, _capabilities) do
    # Intelligent model selection based on task characteristics, cost, and performance
    case task.type do
      # Research and Complex Analysis
      :complex_reasoning ->
        select_models_by_strategy(models, :reasoning_optimized, task.priority, 3)
      
      :research ->
        select_models_by_strategy(models, :research_optimized, task.priority, 3)
      
      :expert_analysis ->
        select_models_by_strategy(models, :expert_grade, task.priority, 2)
      
      # Programming and Technical Tasks
      :code_generation ->
        select_models_by_strategy(models, :coding_optimized, task.priority, 3)
      
      :technical_analysis ->
        select_models_by_strategy(models, :technical_optimized, task.priority, 3)
      
      :automation ->
        select_models_by_capability(models, [:computer_interaction, :automation], 2)
      
      # Creative and Content Tasks
      :creative_writing ->
        select_models_by_strategy(models, :creative_optimized, task.priority, 2)
      
      :content_creation ->
        select_models_by_capability(models, [:creative, :multimodal], 2)
      
      # Specialized Tasks
      :audio_processing ->
        select_models_by_capability(models, [:audio_processing], 2)
      
      :web_search ->
        select_models_by_capability(models, [:web_search, :real_time_info], 2)
      
      :multimodal_tasks ->
        select_models_by_capability(models, [:multimodal], 3)
      
      # Performance and Cost Constraints
      :fast_response ->
        select_models_by_strategy(models, :speed_optimized, task.priority, 2)
      
      :cost_sensitive ->
        select_models_by_strategy(models, :cost_optimized, task.priority, 2)
      
      :high_volume ->
        select_models_by_strategy(models, :volume_optimized, task.priority, 2)
      
      # Educational and Simple Tasks
      :educational ->
        select_models_by_strategy(models, :educational_optimized, task.priority, 2)
      
      :simple_tasks ->
        select_models_by_strategy(models, :simple_optimized, task.priority, 2)
      
      # Default Strategy
      _ ->
        select_models_by_strategy(models, :balanced, task.priority, 3)
    end
  end

  defp select_models_by_capability(models, required_capabilities, count) do
    models
    |> Enum.filter(fn {_id, config} ->
      Enum.any?(required_capabilities, fn cap -> cap in (config.capabilities ++ config.specializations) end)
    end)
    |> Enum.sort_by(fn {_id, config} -> config.performance_score end, :desc)
    |> Enum.take(count)
  end

  defp select_models_by_strategy(models, strategy, priority, count) do
    case strategy do
      :reasoning_optimized ->
        select_reasoning_models(models, priority, count)
      
      :research_optimized ->
        select_research_models(models, priority, count)
      
      :expert_grade ->
        select_expert_models(models, priority, count)
      
      :coding_optimized ->
        select_coding_models(models, priority, count)
      
      :technical_optimized ->
        select_technical_models(models, priority, count)
      
      :creative_optimized ->
        select_creative_models(models, priority, count)
      
      :speed_optimized ->
        select_speed_models(models, priority, count)
      
      :cost_optimized ->
        select_cost_models(models, priority, count)
      
      :volume_optimized ->
        select_volume_models(models, priority, count)
      
      :educational_optimized ->
        select_educational_models(models, priority, count)
      
      :simple_optimized ->
        select_simple_models(models, priority, count)
      
      :balanced ->
        select_balanced_models(models, priority, count)
      
      _ ->
        select_default_models(models, count)
    end
  end

  # Reasoning-optimized selection
  defp select_reasoning_models(models, priority, count) do
    reasoning_models = [:o1_pro, :o1, :o3, :gpt45_preview, :gpt41, :o4_mini]
    
    case priority do
      :critical -> 
        prioritize_models(models, [:o1_pro, :gpt45_preview, :o1], count)
      :high -> 
        prioritize_models(models, [:o1, :o3, :gpt41], count)
      _ -> 
        prioritize_models(models, reasoning_models, count)
    end
  end

  # Research-optimized selection
  defp select_research_models(models, priority, count) do
    case priority do
      :critical -> 
        prioritize_models(models, [:gpt45_preview, :o1_pro, :gpt4o_search], count)
      :high -> 
        prioritize_models(models, [:o1, :gpt41, :gpt4o_search], count)
      _ -> 
        prioritize_models(models, [:gpt4o_search, :gpt4o_mini_search, :gpt41], count)
    end
  end

  # Expert-grade selection
  defp select_expert_models(models, priority, count) do
    case priority do
      :critical -> 
        prioritize_models(models, [:o1_pro, :gpt45_preview], count)
      _ -> 
        prioritize_models(models, [:o1_pro, :gpt45_preview, :o1], count)
    end
  end

  # Coding-optimized selection
  defp select_coding_models(models, priority, count) do
    coding_models = [:codex_mini, :gpt41, :gpt4o, :o3, :gpt4_turbo]
    
    case priority do
      :critical -> 
        prioritize_models(models, [:gpt41, :codex_mini, :o3], count)
      :high -> 
        prioritize_models(models, [:codex_mini, :gpt4o, :gpt41], count)
      _ -> 
        prioritize_models(models, coding_models, count)
    end
  end

  # Technical analysis optimized
  defp select_technical_models(models, priority, count) do
    case priority do
      :critical -> 
        prioritize_models(models, [:gpt41, :o3, :gpt4o], count)
      _ -> 
        prioritize_models(models, [:gpt4o, :gpt41, :codex_mini], count)
    end
  end

  # Creative-optimized selection
  defp select_creative_models(models, priority, count) do
    creative_models = [:gpt4o, :gpt41, :chatgpt4o_latest, :gpt4_turbo]
    
    case priority do
      :high -> 
        prioritize_models(models, [:gpt4o, :gpt41], count)
      _ -> 
        prioritize_models(models, creative_models, count)
    end
  end

  # Speed-optimized selection
  defp select_speed_models(models, _priority, count) do
    speed_models = [:gpt41_nano, :gpt4o_mini, :gpt35_turbo, :gpt41_mini]
    prioritize_models(models, speed_models, count)
  end

  # Cost-optimized selection
  defp select_cost_models(models, _priority, count) do
    models
    |> Enum.sort_by(fn {_id, config} -> config.cost_per_token end, :asc)
    |> Enum.take(count)
  end

  # Volume-optimized selection (for high-volume processing)
  defp select_volume_models(models, _priority, count) do
    volume_models = [:gpt41_nano, :gpt35_turbo, :gpt4o_mini, :o3_mini]
    prioritize_models(models, volume_models, count)
  end

  # Educational-optimized selection
  defp select_educational_models(models, _priority, count) do
    educational_models = [:o1_mini, :gpt41_mini, :gpt4o_mini, :gpt35_turbo]
    prioritize_models(models, educational_models, count)
  end

  # Simple tasks optimized
  defp select_simple_models(models, _priority, count) do
    simple_models = [:gpt35_turbo, :gpt41_nano, :gpt4o_mini]
    prioritize_models(models, simple_models, count)
  end

  # Balanced selection
  defp select_balanced_models(models, priority, count) do
    case priority do
      :critical -> 
        prioritize_models(models, [:gpt41, :gpt4o, :o3], count)
      :high -> 
        prioritize_models(models, [:gpt4o, :gpt41_mini, :gpt4_turbo], count)
      _ -> 
        prioritize_models(models, [:gpt4o_mini, :gpt41_mini, :gpt35_turbo], count)
    end
  end

  # Default fallback
  defp select_default_models(models, count) do
    models
    |> Enum.sort_by(fn {_id, config} -> config.performance_score end, :desc)
    |> Enum.take(count)
  end

  # Helper function to prioritize specific models
  defp prioritize_models(models, preferred_order, count) do
    # First, try to get models in preferred order
    prioritized = Enum.reduce(preferred_order, [], fn model_id, acc ->
      case Map.get(models, model_id) do
        nil -> acc
        config -> [{model_id, config} | acc]
      end
    end) |> Enum.reverse()

    # If we don't have enough, fill with remaining models by performance
    if length(prioritized) >= count do
      Enum.take(prioritized, count)
    else
      remaining_needed = count - length(prioritized)
      prioritized_ids = Enum.map(prioritized, fn {id, _} -> id end)
      
      remaining_models = models
      |> Enum.reject(fn {id, _} -> id in prioritized_ids end)
      |> Enum.sort_by(fn {_id, config} -> config.performance_score end, :desc)
      |> Enum.take(remaining_needed)
      
      prioritized ++ remaining_models
    end
  end


  defp execute_models_parallel(task, selected_models, _state) do
    # Execute queries in parallel using Task.async_stream
    selected_models
    |> Task.async_stream(
      fn {model_id, model_config} ->
        execute_single_model(task, model_id, model_config)
      end,
      max_concurrency: length(selected_models),
      timeout: 45_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn 
      {:ok, result} -> result
      {:exit, reason} -> {:error, model_id: :unknown, reason: reason}
    end)
  end

  defp execute_single_model(task, model_id, model_config) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      # Enhanced prompt with task context
      enhanced_prompt = build_enhanced_prompt(task, model_config)
      
      case query_model(model_config.client, enhanced_prompt, model_config) do
        {:ok, response} ->
          execution_time = System.monotonic_time(:millisecond) - start_time
          tokens_used = estimate_token_usage(enhanced_prompt, response)
          
          %{
            model_id: model_id,
            response: response,
            execution_time: execution_time,
            tokens_used: tokens_used,
            confidence: calculate_response_confidence(response, model_config),
            status: :success
          }
          
        {:error, reason} ->
          %{
            model_id: model_id,
            response: nil,
            execution_time: System.monotonic_time(:millisecond) - start_time,
            tokens_used: 0,
            confidence: 0.0,
            status: :error,
            error: reason
          }
      end
    rescue
      error ->
        %{
          model_id: model_id,
          response: nil,
          execution_time: System.monotonic_time(:millisecond) - start_time,
          tokens_used: 0,
          confidence: 0.0,
          status: :error,
          error: inspect(error)
        }
    end
  end

  defp build_enhanced_prompt(task, model_config) do
    context_str = if map_size(task.context) > 0, do: "\n\nContext: #{inspect(task.context)}", else: ""
    
    specialization_hint = case model_config.specializations do
      [] -> ""
      specs -> "\n\nNote: You excel at #{Enum.join(specs, ", ")}. Leverage these strengths in your response."
    end
    
    """
    Task Type: #{task.type}
    Priority: #{task.priority}
    Complexity: #{task.complexity}#{context_str}#{specialization_hint}

    #{task.prompt}

    Provide a detailed, well-reasoned response. Include your confidence level and reasoning process.
    """
  end

  defp query_model(client, prompt, model_config) do
    # Handle different client types
    case client do
      %{type: :anthropic} ->
        # Placeholder for Anthropic API call
        {:ok, "Response from #{model_config.id}: #{String.slice(prompt, 0, 50)}..."}
      
      _ ->
        # OpenAI client
        request = %{
          messages: [%{"role" => "user", "content" => prompt}],
          max_tokens: min(2000, div(model_config.max_context, 4)),
          temperature: 0.7
        }
        
        case Dspy.LM.generate(client, request) do
          {:ok, response} ->
            case get_in(response, [:choices, Access.at(0), :message, "content"]) do
              content when is_binary(content) -> {:ok, String.trim(content)}
              _ -> {:error, :invalid_response_format}
            end
          
          error -> error
        end
    end
  end

  defp apply_consensus_algorithm(results, task, _consensus_engine, coordination_strategy) do
    successful_results = Enum.filter(results, fn result -> result.status == :success end)
    
    if length(successful_results) == 0 do
      %{
        final_answer: "No successful responses from models",
        confidence: 0.0,
        contributing_models: [],
        reasoning_paths: [],
        execution_time: 0,
        token_usage: 0
      }
    else
      case coordination_strategy do
        :weighted_voting -> weighted_voting_consensus(successful_results, task)
        :majority_vote -> majority_vote_consensus(successful_results, task)
        :best_confidence -> best_confidence_consensus(successful_results, task)
        :ensemble_blend -> ensemble_blend_consensus(successful_results, task)
        _ -> weighted_voting_consensus(successful_results, task)
      end
    end
  end

  defp weighted_voting_consensus(results, _task) do
    # Weight responses by model confidence and performance
    total_weight = Enum.sum(Enum.map(results, & &1.confidence))
    
    if total_weight > 0 do
      # Find the response with highest weighted score
      best_result = Enum.max_by(results, fn result ->
        result.confidence * 0.7 + (1.0 / max(result.execution_time, 1)) * 0.3
      end)
      
      %{
        final_answer: best_result.response,
        confidence: calculate_ensemble_confidence(results),
        contributing_models: Enum.map(results, & &1.model_id),
        reasoning_paths: Enum.map(results, fn r -> "#{r.model_id}: #{String.slice(r.response, 0, 100)}..." end),
        execution_time: Enum.max(Enum.map(results, & &1.execution_time)),
        token_usage: Enum.sum(Enum.map(results, & &1.tokens_used))
      }
    else
      %{
        final_answer: "Unable to generate consensus",
        confidence: 0.0,
        contributing_models: Enum.map(results, & &1.model_id),
        reasoning_paths: [],
        execution_time: 0,
        token_usage: 0
      }
    end
  end

  defp majority_vote_consensus(results, task) do
    # For simple majority voting, we'll use the most common response pattern
    # In a real implementation, this would involve more sophisticated text similarity
    weighted_voting_consensus(results, task)
  end

  defp best_confidence_consensus(results, _task) do
    best_result = Enum.max_by(results, & &1.confidence)
    
    %{
      final_answer: best_result.response,
      confidence: best_result.confidence,
      contributing_models: [best_result.model_id],
      reasoning_paths: ["#{best_result.model_id}: #{best_result.response}"],
      execution_time: best_result.execution_time,
      token_usage: best_result.tokens_used
    }
  end

  defp ensemble_blend_consensus(results, _task) do
    # Blend responses from all models into a comprehensive answer
    blended_response = """
    Ensemble Response from #{length(results)} models:
    
    #{Enum.map_join(results, "\n\n", fn result ->
      "#{result.model_id} (confidence: #{Float.round(result.confidence, 2)}): #{result.response}"
    end)}
    
    Consensus: #{find_common_themes(results)}
    """
    
    %{
      final_answer: blended_response,
      confidence: calculate_ensemble_confidence(results),
      contributing_models: Enum.map(results, & &1.model_id),
      reasoning_paths: Enum.map(results, fn r -> "#{r.model_id}: #{r.response}" end),
      execution_time: Enum.max(Enum.map(results, & &1.execution_time)),
      token_usage: Enum.sum(Enum.map(results, & &1.tokens_used))
    }
  end

  defp calculate_ensemble_confidence(results) do
    if length(results) > 0 do
      avg_confidence = Enum.sum(Enum.map(results, & &1.confidence)) / length(results)
      # Boost confidence when multiple models agree
      agreement_bonus = min(0.2, (length(results) - 1) * 0.05)
      min(1.0, avg_confidence + agreement_bonus)
    else
      0.0
    end
  end

  defp find_common_themes(results) do
    # Simplified common theme detection
    responses = Enum.map(results, & &1.response)
    
    if length(responses) > 1 do
      "Multiple models provided consistent insights"
    else
      "Single model response"
    end
  end

  defp calculate_response_confidence(response, model_config) do
    # Simple heuristic for response confidence
    base_confidence = model_config.performance_score
    
    # Adjust based on response length and content
    length_factor = min(1.0, String.length(response) / 500.0)
    content_factor = if String.contains?(response, ["analysis", "reasoning", "because"]), do: 0.1, else: 0.0
    
    min(1.0, base_confidence * length_factor + content_factor)
  end

  defp estimate_token_usage(prompt, response) do
    # Rough estimation: ~4 characters per token
    total_chars = String.length(prompt) + String.length(response)
    div(total_chars, 4)
  end

  defp analyze_task_complexity(prompt) do
    cond do
      String.length(prompt) > 1000 -> :high
      String.length(prompt) > 500 -> :medium
      true -> :low
    end
  end

  defp analyze_model_capabilities(models) do
    Enum.reduce(models, %{}, fn {model_id, config}, acc ->
      Map.put(acc, model_id, %{
        capabilities: config.capabilities,
        specializations: config.specializations,
        performance_score: config.performance_score,
        cost_efficiency: 1.0 / config.cost_per_token
      })
    end)
  end

  defp update_model_configurations(current_models, updates) do
    Enum.reduce(updates, current_models, fn update, acc ->
      Map.put(acc, update.id, update)
    end)
  end

  defp update_performance_metrics(tracker, task, result, execution_time) do
    %{tracker |
      tasks_completed: Map.get(tracker, :tasks_completed, 0) + 1,
      total_execution_time: Map.get(tracker, :total_execution_time, 0) + execution_time,
      average_confidence: calculate_running_average(
        Map.get(tracker, :average_confidence, 0.0),
        result.confidence,
        Map.get(tracker, :tasks_completed, 0)
      ),
      total_tokens: Map.get(tracker, :total_tokens, 0) + result.token_usage,
      task_types: update_task_type_stats(Map.get(tracker, :task_types, %{}), task.type)
    }
  end

  defp calculate_running_average(current_avg, new_value, count) do
    if count == 0 do
      new_value
    else
      (current_avg * count + new_value) / (count + 1)
    end
  end

  defp update_task_type_stats(stats, task_type) do
    Map.update(stats, task_type, 1, & &1 + 1)
  end

  defp initialize_execution_pool, do: %{max_concurrent: 10, active: 0}
  defp initialize_consensus_engine, do: %{strategies: [:weighted_voting, :majority_vote, :best_confidence]}
  defp initialize_performance_tracker, do: %{tasks_completed: 0, total_execution_time: 0}

  defp via_tuple(agent_id) do
    {:via, Registry, {Dspy.ParallelMultiModelAgent.Registry, agent_id}}
  end

  defp generate_agent_id do
    "pmma_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp generate_task_id do
    "task_" <> (:crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower))
  end

  # Cost Analysis Functions

  defp generate_cost_analysis(task, models, _capabilities) do
    # Analyze costs for different model selection strategies
    strategies = [
      {:current_selection, select_optimal_models(task, models, %{})},
      {:cost_optimized, select_models_by_strategy(models, :cost_optimized, task.priority, 3)},
      {:performance_optimized, select_models_by_strategy(models, :reasoning_optimized, task.priority, 3)},
      {:balanced, select_models_by_strategy(models, :balanced, task.priority, 3)}
    ]

    estimated_tokens = estimate_token_usage(task.prompt, "Average response length")

    cost_comparisons = Enum.map(strategies, fn {strategy_name, selected_models} ->
      total_cost = calculate_total_cost(selected_models, estimated_tokens)
      model_names = Enum.map(selected_models, fn {id, _} -> id end)
      
      %{
        strategy: strategy_name,
        models: model_names,
        estimated_cost: total_cost,
        cost_per_model: total_cost / length(selected_models),
        cost_breakdown: get_cost_breakdown(selected_models, estimated_tokens)
      }
    end)

    %{
      task_analysis: %{
        type: task.type,
        priority: task.priority,
        complexity: task.complexity,
        estimated_tokens: estimated_tokens
      },
      cost_comparisons: cost_comparisons,
      recommendations: generate_cost_recommendations(cost_comparisons),
      model_categories: categorize_models_by_cost(models)
    }
  end

  defp calculate_total_cost(selected_models, estimated_tokens) do
    Enum.reduce(selected_models, 0, fn {_id, config}, acc ->
      acc + (config.cost_per_token * estimated_tokens)
    end)
  end

  defp get_cost_breakdown(selected_models, estimated_tokens) do
    Enum.map(selected_models, fn {id, config} ->
      cost = config.cost_per_token * estimated_tokens
      %{
        model: id,
        cost_per_token: config.cost_per_token,
        estimated_tokens: estimated_tokens,
        total_cost: cost,
        category: config.category
      }
    end)
  end

  defp generate_cost_recommendations(cost_comparisons) do
    cheapest = Enum.min_by(cost_comparisons, & &1.estimated_cost)
    most_expensive = Enum.max_by(cost_comparisons, & &1.estimated_cost)
    
    savings = most_expensive.estimated_cost - cheapest.estimated_cost
    savings_percent = (savings / most_expensive.estimated_cost) * 100

    %{
      most_cost_effective: cheapest.strategy,
      potential_savings: %{
        amount: savings,
        percentage: Float.round(savings_percent, 1)
      },
      recommendations: [
        "For cost optimization: Use #{cheapest.strategy} strategy",
        "For maximum performance: Consider premium models for critical tasks",
        "For balanced approach: Mix efficient and high-performance models",
        if(savings_percent > 50, do: "High cost variance detected - consider optimization", else: "Cost differences are reasonable")
      ] |> Enum.filter(& &1)
    }
  end

  defp categorize_models_by_cost(models) do
    sorted_models = Enum.sort_by(models, fn {_id, config} -> config.cost_per_token end, :asc)
    
    %{
      ultra_budget: filter_models_by_cost_range(sorted_models, 0, 0.0005),
      budget: filter_models_by_cost_range(sorted_models, 0.0005, 0.002),
      standard: filter_models_by_cost_range(sorted_models, 0.002, 0.01),
      premium: filter_models_by_cost_range(sorted_models, 0.01, 0.1),
      flagship: filter_models_by_cost_range(sorted_models, 0.1, 1.0)
    }
  end

  defp filter_models_by_cost_range(models, min_cost, max_cost) do
    models
    |> Enum.filter(fn {_id, config} -> 
      config.cost_per_token >= min_cost and config.cost_per_token < max_cost
    end)
    |> Enum.map(fn {id, config} -> 
      %{id: id, cost_per_token: config.cost_per_token, category: config.category}
    end)
  end

  # Model Recommendation Functions

  defp recommend_models_for_requirements(requirements) do
    all_models = initialize_models([])
    
    %{
      primary_recommendations: get_primary_recommendations(requirements, all_models),
      alternative_options: get_alternative_options(requirements, all_models),
      cost_analysis: get_requirements_cost_analysis(requirements, all_models),
      use_case_examples: get_use_case_examples(requirements)
    }
  end

  defp get_primary_recommendations(requirements, models) do
    budget = Map.get(requirements, :budget, :medium)
    performance_needs = Map.get(requirements, :performance, :medium)
    task_types = Map.get(requirements, :task_types, [:general])
    
    case {budget, performance_needs} do
      {:low, _} -> 
        recommend_budget_models(models, task_types)
      
      {_, :high} -> 
        recommend_performance_models(models, task_types)
      
      {:high, _} -> 
        recommend_premium_models(models, task_types)
      
      _ -> 
        recommend_balanced_models(models, task_types)
    end
  end

  defp recommend_budget_models(models, task_types) do
    budget_models = [:gpt35_turbo, :gpt41_nano, :gpt4o_mini, :o3_mini]
    filter_by_capabilities(models, budget_models, task_types)
  end

  defp recommend_performance_models(models, task_types) do
    performance_models = [:gpt45_preview, :o1_pro, :o1, :gpt41, :o3]
    filter_by_capabilities(models, performance_models, task_types)
  end

  defp recommend_premium_models(models, task_types) do
    premium_models = [:gpt45_preview, :o1_pro, :gpt41, :o3]
    filter_by_capabilities(models, premium_models, task_types)
  end

  defp recommend_balanced_models(models, task_types) do
    balanced_models = [:gpt4o, :gpt41_mini, :gpt4o_mini, :o4_mini]
    filter_by_capabilities(models, balanced_models, task_types)
  end

  defp filter_by_capabilities(models, model_list, task_types) do
    Enum.filter(model_list, fn model_id ->
      case Map.get(models, model_id) do
        nil -> false
        config -> 
          task_match = Enum.any?(task_types, fn task_type ->
            task_type in config.use_cases or 
            task_type in config.capabilities or 
            task_type in config.specializations
          end)
          task_match
      end
    end)
    |> Enum.map(fn model_id -> 
      config = Map.get(models, model_id)
      %{
        id: model_id,
        category: config.category,
        cost_per_token: config.cost_per_token,
        performance_score: config.performance_score,
        specializations: config.specializations,
        use_cases: config.use_cases
      }
    end)
  end

  defp get_alternative_options(requirements, models) do
    # Provide alternative models for different scenarios
    primary = get_primary_recommendations(requirements, models)
    primary_ids = Enum.map(primary, & &1.id)
    
    all_suitable = models
    |> Enum.filter(fn {_id, config} ->
      task_types = Map.get(requirements, :task_types, [:general])
      Enum.any?(task_types, fn task_type ->
        task_type in config.use_cases or task_type in config.capabilities
      end)
    end)
    |> Enum.reject(fn {id, _} -> id in primary_ids end)
    |> Enum.map(fn {id, config} ->
      %{
        id: id,
        category: config.category,
        cost_per_token: config.cost_per_token,
        performance_score: config.performance_score,
        why_alternative: determine_alternative_reason(config, requirements)
      }
    end)
    |> Enum.sort_by(& &1.performance_score, :desc)
    |> Enum.take(5)
    
    all_suitable
  end

  defp determine_alternative_reason(config, requirements) do
    _budget = Map.get(requirements, :budget, :medium)
    _performance = Map.get(requirements, :performance, :medium)
    
    cond do
      config.cost_per_token < 0.001 -> "Ultra cost-efficient option"
      config.performance_score > 0.95 -> "Maximum performance option"
      config.category == :multimodal -> "Multimodal capabilities"
      config.category == :audio -> "Audio processing capabilities"
      config.category == :search -> "Web search capabilities"
      true -> "Alternative specialized option"
    end
  end

  defp get_requirements_cost_analysis(requirements, models) do
    _task_types = Map.get(requirements, :task_types, [:general])
    volume = Map.get(requirements, :volume, :medium)
    
    # Estimate monthly costs for different volume levels
    monthly_tokens = case volume do
      :low -> 100_000      # 100K tokens/month
      :medium -> 1_000_000 # 1M tokens/month
      :high -> 10_000_000  # 10M tokens/month
      :enterprise -> 100_000_000 # 100M tokens/month
    end
    
    primary_models = get_primary_recommendations(requirements, models)
    
    cost_scenarios = Enum.map(primary_models, fn model ->
      monthly_cost = model.cost_per_token * monthly_tokens
      
      %{
        model: model.id,
        monthly_cost: monthly_cost,
        cost_per_1k_tokens: model.cost_per_token * 1000,
        volume_tier: volume,
        cost_category: categorize_monthly_cost(monthly_cost)
      }
    end)
    
    %{
      volume_analysis: %{
        estimated_monthly_tokens: monthly_tokens,
        volume_tier: volume
      },
      cost_scenarios: cost_scenarios,
      budget_recommendations: generate_budget_recommendations(cost_scenarios)
    }
  end

  defp categorize_monthly_cost(monthly_cost) do
    cond do
      monthly_cost < 10 -> :micro
      monthly_cost < 100 -> :small
      monthly_cost < 1000 -> :medium
      monthly_cost < 10000 -> :large
      true -> :enterprise
    end
  end

  defp generate_budget_recommendations(cost_scenarios) do
    if length(cost_scenarios) > 0 do
      cheapest = Enum.min_by(cost_scenarios, & &1.monthly_cost)
      most_expensive = Enum.max_by(cost_scenarios, & &1.monthly_cost)
      
      [
        "Cheapest option: #{cheapest.model} at $#{Float.round(cheapest.monthly_cost, 2)}/month",
        "Most expensive: #{most_expensive.model} at $#{Float.round(most_expensive.monthly_cost, 2)}/month",
        "Consider usage patterns when selecting models",
        "Use cheaper models for simple tasks, premium for complex work"
      ]
    else
      ["No suitable models found for requirements"]
    end
  end

  defp get_use_case_examples(requirements) do
    task_types = Map.get(requirements, :task_types, [:general])
    
    Enum.flat_map(task_types, fn task_type ->
      case task_type do
        :research -> [
          "Academic paper analysis and summarization",
          "Literature reviews and research synthesis",
          "Data analysis and interpretation",
          "Hypothesis generation and testing"
        ]
        
        :code_generation -> [
          "Software architecture design",
          "Code review and optimization",
          "Bug fixing and debugging",
          "API development and testing"
        ]
        
        :creative_writing -> [
          "Content creation and copywriting",
          "Story and narrative development",
          "Marketing material generation",
          "Social media content creation"
        ]
        
        :analysis -> [
          "Business intelligence and reporting",
          "Financial analysis and forecasting",
          "Market research and trends",
          "Risk assessment and mitigation"
        ]
        
        _ -> [
          "General purpose question answering",
          "Document processing and summarization",
          "Basic reasoning and problem solving",
          "Simple automation tasks"
        ]
      end
    end)
    |> Enum.uniq()
    |> Enum.take(8)
  end
end