defmodule DspyWeb.GodmodeCoordinatorLive do
  use DspyWeb, :live_view
  
  alias Dspy.GodmodeCoordinator
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to coordinator events
      GodmodeCoordinator.subscribe_to_events([:all])
      
      # Schedule periodic updates
      :timer.send_interval(1000, self(), :update_metrics)
    end
    
    socket = 
      socket
      |> assign(:page_title, "🔥 Godmode Coordinator")
      |> assign(:system_status, %{})
      |> assign(:live_metrics, %{})
      |> assign(:active_tasks, [])
      |> assign(:recent_events, [])
      |> assign(:power_level, :godmode)
      |> assign(:auto_optimization, true)
      |> load_initial_data()
    
    {:ok, socket}
  end
  
  @impl true
  def handle_info(:update_metrics, socket) do
    socket = 
      socket
      |> update_system_status()
      |> update_live_metrics()
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:coordinator_event, event}, socket) do
    socket = add_event_to_recent(socket, event)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("activate_godmode", _params, socket) do
    case GodmodeCoordinator.activate_godmode() do
      {:ok, :godmode_active} ->
        socket = 
          socket
          |> assign(:power_level, :godmode)
          |> put_flash(:info, "⚡ GODMODE ACTIVATED - Supreme system control enabled")
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to activate godmode: #{inspect(reason)}")
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("force_optimization", _params, socket) do
    case GodmodeCoordinator.force_system_optimization() do
      {:ok, result} ->
        socket = 
          socket
          |> put_flash(:info, "🎯 System optimization completed: #{result.improvement}% improvement")
          |> update_system_status()
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = put_flash(socket, :error, "Optimization failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("execute_coordinated_task", %{"task_type" => task_type}, socket) do
    task_spec = %{
      type: String.to_atom(task_type),
      description: "User-initiated #{task_type} task",
      complexity: :medium,
      priority: :high
    }
    
    case GodmodeCoordinator.execute_coordinated_task(task_spec) do
      {:ok, task_id, result} ->
        socket = 
          socket
          |> put_flash(:info, "✅ Task #{task_id} executed successfully")
          |> add_task_to_active(%{id: task_id, type: task_type, result: result, timestamp: DateTime.utc_now()})
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = put_flash(socket, :error, "Task execution failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("spawn_agent_swarm", %{"count" => count_str}, socket) do
    count = String.to_integer(count_str)
    
    agent_specs = Enum.map(1..count, fn i ->
      %{
        id: "swarm_agent_#{i}",
        model: "gpt-4.1",
        task_type: :general,
        coordination_level: :high
      }
    end)
    
    case GodmodeCoordinator.spawn_agent_swarm(agent_specs) do
      {:ok, swarm_id, agents, _coordination_result} ->
        socket = 
          socket
          |> put_flash(:info, "🚀 Agent swarm #{swarm_id} spawned with #{map_size(agents)} agents")
          |> update_system_status()
        
        {:noreply, socket}
        
      {:error, reason} ->
        socket = put_flash(socket, :error, "Agent swarm spawn failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("toggle_auto_optimization", _params, socket) do
    new_value = !socket.assigns.auto_optimization
    socket = assign(socket, :auto_optimization, new_value)
    
    # This would typically update the coordinator's configuration
    # GodmodeCoordinator.update_config(%{auto_optimization: new_value})
    
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="godmode-dashboard">
      <!-- Header -->
      <div class="dashboard-header">
        <div class="header-left">
          <h1 class="dashboard-title">
            🔥 <span class="godmode-text">GODMODE</span> COORDINATOR
          </h1>
          <div class="power-level-indicator">
            <span class="power-level-badge" class={power_level_class(@power_level)}>
              <%= power_level_display(@power_level) %>
            </span>
          </div>
        </div>
        
        <div class="header-controls">
          <button 
            phx-click="activate_godmode" 
            class="btn btn-primary btn-godmode"
            disabled={@power_level == :godmode}
          >
            ⚡ ACTIVATE GODMODE
          </button>
          
          <button 
            phx-click="force_optimization" 
            class="btn btn-secondary"
          >
            🎯 FORCE OPTIMIZATION
          </button>
        </div>
      </div>
      
      <!-- Main Dashboard Grid -->
      <div class="dashboard-grid">
        <!-- System Status Panel -->
        <div class="panel system-status-panel">
          <h3>🌐 System Status</h3>
          <div class="status-grid">
            <div class="status-item">
              <span class="status-label">Status:</span>
              <span class="status-value status-active">
                <%= Map.get(@system_status, :coordinator_status, "Unknown") %>
              </span>
            </div>
            
            <div class="status-item">
              <span class="status-label">Active Agents:</span>
              <span class="status-value">
                <%= Map.get(@system_status, :active_agent_count, 0) %>
              </span>
            </div>
            
            <div class="status-item">
              <span class="status-label">Hotswaps:</span>
              <span class="status-value">
                <%= Map.get(@system_status, :hotswap_count, 0) %>
              </span>
            </div>
            
            <div class="status-item">
              <span class="status-label">Monitoring Tasks:</span>
              <span class="status-value">
                <%= Map.get(@system_status, :monitoring_tasks, 0) %>
              </span>
            </div>
          </div>
        </div>
        
        <!-- Live Metrics Panel -->
        <div class="panel metrics-panel">
          <h3>📊 Live Metrics</h3>
          <div class="metrics-grid">
            <div class="metric-item">
              <div class="metric-label">System Load</div>
              <div class="metric-value">
                <%= format_percentage(Map.get(@live_metrics, :system_load, 0)) %>
              </div>
              <div class="metric-bar">
                <div class="metric-fill" style={"width: #{Map.get(@live_metrics, :system_load, 0) * 100}%"}></div>
              </div>
            </div>
            
            <div class="metric-item">
              <div class="metric-label">Memory Usage</div>
              <div class="metric-value">
                <%= format_memory(Map.get(@live_metrics, :memory_usage, 0)) %>
              </div>
              <div class="metric-bar">
                <div class="metric-fill" style={"width: #{min(Map.get(@live_metrics, :memory_usage, 0) * 10, 100)}%"}></div>
              </div>
            </div>
            
            <div class="metric-item">
              <div class="metric-label">Coordination Efficiency</div>
              <div class="metric-value">
                <%= format_percentage(Map.get(@live_metrics, :coordination_efficiency, 0)) %>
              </div>
              <div class="metric-bar">
                <div class="metric-fill" style={"width: #{Map.get(@live_metrics, :coordination_efficiency, 0) * 100}%"}></div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Control Panel -->
        <div class="panel control-panel">
          <h3>🎮 Control Panel</h3>
          
          <div class="control-section">
            <h4>Task Execution</h4>
            <div class="control-buttons">
              <button 
                phx-click="execute_coordinated_task" 
                phx-value-task_type="reasoning"
                class="btn btn-primary"
              >
                🧠 Execute Reasoning Task
              </button>
              
              <button 
                phx-click="execute_coordinated_task" 
                phx-value-task_type="analysis"
                class="btn btn-primary"
              >
                📈 Execute Analysis Task
              </button>
              
              <button 
                phx-click="execute_coordinated_task" 
                phx-value-task_type="optimization"
                class="btn btn-primary"
              >
                ⚡ Execute Optimization Task
              </button>
            </div>
          </div>
          
          <div class="control-section">
            <h4>Agent Management</h4>
            <div class="agent-spawn-controls">
              <input type="number" id="agent-count" value="3" min="1" max="20" class="form-input">
              <button 
                phx-click="spawn_agent_swarm" 
                phx-value-count={get_input_value("agent-count", "3")}
                class="btn btn-secondary"
              >
                🚀 Spawn Agent Swarm
              </button>
            </div>
          </div>
          
          <div class="control-section">
            <h4>System Settings</h4>
            <label class="toggle-control">
              <input 
                type="checkbox" 
                phx-click="toggle_auto_optimization"
                checked={@auto_optimization}
              >
              <span class="toggle-slider"></span>
              Auto-Optimization
            </label>
          </div>
        </div>
        
        <!-- Active Tasks Panel -->
        <div class="panel tasks-panel">
          <h3>⚙️ Active Tasks</h3>
          <div class="tasks-list">
            <%= for task <- @active_tasks do %>
              <div class="task-item">
                <div class="task-header">
                  <span class="task-id"><%= task.id %></span>
                  <span class="task-type"><%= task.type %></span>
                </div>
                <div class="task-timestamp">
                  <%= format_timestamp(task.timestamp) %>
                </div>
              </div>
            <% end %>
            
            <%= if Enum.empty?(@active_tasks) do %>
              <div class="empty-state">No active tasks</div>
            <% end %>
          </div>
        </div>
        
        <!-- Recent Events Panel -->
        <div class="panel events-panel">
          <h3>📡 Recent Events</h3>
          <div class="events-list">
            <%= for event <- Enum.take(@recent_events, 10) do %>
              <div class="event-item">
                <span class="event-type"><%= format_event_type(elem(event, 0)) %></span>
                <span class="event-timestamp"><%= format_timestamp(elem(event, 1)) %></span>
              </div>
            <% end %>
            
            <%= if Enum.empty?(@recent_events) do %>
              <div class="empty-state">No recent events</div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    
    <style>
      .godmode-dashboard {
        min-height: 100vh;
        background: linear-gradient(135deg, #0f1419 0%, #1a1a2e 50%, #16213e 100%);
        color: #fff;
        font-family: 'SF Mono', 'Monaco', 'Inconsolata', monospace;
      }
      
      .dashboard-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 2rem;
        border-bottom: 2px solid #ff6b6b;
        background: rgba(255, 107, 107, 0.1);
      }
      
      .dashboard-title {
        font-size: 2.5rem;
        font-weight: bold;
        margin: 0;
        text-shadow: 0 0 20px #ff6b6b;
      }
      
      .godmode-text {
        color: #ff6b6b;
        animation: glow 2s ease-in-out infinite alternate;
      }
      
      @keyframes glow {
        from { text-shadow: 0 0 20px #ff6b6b, 0 0 30px #ff6b6b; }
        to { text-shadow: 0 0 30px #ff6b6b, 0 0 40px #ff6b6b; }
      }
      
      .power-level-indicator {
        margin-top: 0.5rem;
      }
      
      .power-level-badge {
        padding: 0.25rem 0.75rem;
        border-radius: 1rem;
        font-size: 0.875rem;
        font-weight: bold;
        text-transform: uppercase;
      }
      
      .power-level-godmode {
        background: linear-gradient(45deg, #ff6b6b, #ff8e53);
        color: white;
        box-shadow: 0 0 15px rgba(255, 107, 107, 0.5);
      }
      
      .header-controls {
        display: flex;
        gap: 1rem;
      }
      
      .btn {
        padding: 0.75rem 1.5rem;
        border: none;
        border-radius: 0.5rem;
        font-weight: bold;
        cursor: pointer;
        transition: all 0.3s;
        text-transform: uppercase;
        font-size: 0.875rem;
      }
      
      .btn-godmode {
        background: linear-gradient(45deg, #ff6b6b, #ff8e53);
        color: white;
        box-shadow: 0 4px 15px rgba(255, 107, 107, 0.4);
      }
      
      .btn-godmode:hover:not(:disabled) {
        transform: translateY(-2px);
        box-shadow: 0 6px 20px rgba(255, 107, 107, 0.6);
      }
      
      .btn-godmode:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }
      
      .btn-primary {
        background: linear-gradient(45deg, #4ecdc4, #44a08d);
        color: white;
      }
      
      .btn-secondary {
        background: linear-gradient(45deg, #667eea, #764ba2);
        color: white;
      }
      
      .dashboard-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
        gap: 2rem;
        padding: 2rem;
      }
      
      .panel {
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 1rem;
        padding: 1.5rem;
        backdrop-filter: blur(10px);
      }
      
      .panel h3 {
        margin: 0 0 1rem 0;
        font-size: 1.25rem;
        color: #4ecdc4;
      }
      
      .status-grid, .metrics-grid {
        display: grid;
        gap: 1rem;
      }
      
      .status-item, .metric-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.75rem;
        background: rgba(255, 255, 255, 0.05);
        border-radius: 0.5rem;
      }
      
      .status-label, .metric-label {
        font-weight: 500;
        opacity: 0.8;
      }
      
      .status-value, .metric-value {
        font-weight: bold;
        color: #4ecdc4;
      }
      
      .status-active {
        color: #4ecdc4;
      }
      
      .metric-bar {
        width: 100%;
        height: 4px;
        background: rgba(255, 255, 255, 0.2);
        border-radius: 2px;
        margin-top: 0.5rem;
        overflow: hidden;
      }
      
      .metric-fill {
        height: 100%;
        background: linear-gradient(90deg, #4ecdc4, #44a08d);
        transition: width 0.3s ease;
      }
      
      .control-section {
        margin-bottom: 1.5rem;
      }
      
      .control-section h4 {
        margin: 0 0 0.75rem 0;
        color: #fff;
        opacity: 0.9;
      }
      
      .control-buttons {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
      }
      
      .agent-spawn-controls {
        display: flex;
        gap: 0.75rem;
        align-items: center;
      }
      
      .form-input {
        padding: 0.5rem;
        border: 1px solid rgba(255, 255, 255, 0.3);
        border-radius: 0.25rem;
        background: rgba(255, 255, 255, 0.1);
        color: white;
        width: 80px;
      }
      
      .toggle-control {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        cursor: pointer;
      }
      
      .toggle-slider {
        width: 40px;
        height: 20px;
        background: rgba(255, 255, 255, 0.3);
        border-radius: 10px;
        position: relative;
        transition: background 0.3s;
      }
      
      .toggle-control input:checked + .toggle-slider {
        background: #4ecdc4;
      }
      
      .tasks-list, .events-list {
        max-height: 300px;
        overflow-y: auto;
      }
      
      .task-item, .event-item {
        padding: 0.75rem;
        background: rgba(255, 255, 255, 0.05);
        border-radius: 0.5rem;
        margin-bottom: 0.5rem;
      }
      
      .task-header {
        display: flex;
        justify-content: space-between;
        margin-bottom: 0.25rem;
      }
      
      .task-id {
        font-family: monospace;
        color: #4ecdc4;
      }
      
      .task-type {
        color: #ff8e53;
        text-transform: uppercase;
        font-size: 0.75rem;
      }
      
      .task-timestamp, .event-timestamp {
        font-size: 0.75rem;
        opacity: 0.7;
      }
      
      .event-type {
        color: #667eea;
        font-weight: bold;
      }
      
      .empty-state {
        text-align: center;
        padding: 2rem;
        opacity: 0.5;
        font-style: italic;
      }
    </style>
    """
  end
  
  # Helper functions
  
  defp load_initial_data(socket) do
    socket
    |> update_system_status()
    |> update_live_metrics()
  end
  
  defp update_system_status(socket) do
    system_status = case GodmodeCoordinator.get_system_status() do
      status when is_map(status) -> status
      _ -> %{}
    end
    
    assign(socket, :system_status, system_status)
  end
  
  defp update_live_metrics(socket) do
    live_metrics = case GodmodeCoordinator.get_live_metrics() do
      metrics when is_map(metrics) -> metrics
      _ -> %{}
    end
    
    assign(socket, :live_metrics, live_metrics)
  end
  
  defp add_event_to_recent(socket, event) do
    recent_events = [event | socket.assigns.recent_events]
    |> Enum.take(50)  # Keep last 50 events
    
    assign(socket, :recent_events, recent_events)
  end
  
  defp add_task_to_active(socket, task) do
    active_tasks = [task | socket.assigns.active_tasks]
    |> Enum.take(20)  # Keep last 20 tasks
    
    assign(socket, :active_tasks, active_tasks)
  end
  
  defp power_level_class(:godmode), do: "power-level-godmode"
  defp power_level_class(:enhanced), do: "power-level-enhanced"
  defp power_level_class(_), do: "power-level-normal"
  
  defp power_level_display(:godmode), do: "⚡ GODMODE"
  defp power_level_display(:enhanced), do: "🔥 ENHANCED"
  defp power_level_display(_), do: "💡 NORMAL"
  
  defp format_percentage(value) when is_number(value) do
    "#{:erlang.float_to_binary(value * 100, decimals: 1)}%"
  end
  defp format_percentage(_), do: "0.0%"
  
  defp format_memory(value) when is_number(value) do
    "#{:erlang.float_to_binary(value, decimals: 2)}GB"
  end
  defp format_memory(_), do: "0.00GB"
  
  defp format_timestamp(timestamp) when is_struct(timestamp, DateTime) do
    Calendar.strftime(timestamp, "%H:%M:%S")
  end
  defp format_timestamp(_), do: "--:--:--"
  
  defp format_event_type(event_type) when is_atom(event_type) do
    event_type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.upcase()
  end
  defp format_event_type(_), do: "UNKNOWN"
  
  defp get_input_value(_id, default), do: default
end