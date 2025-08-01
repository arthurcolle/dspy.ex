defmodule Dspy.Tools do
  @moduledoc """
  Tool integration system for function calling and ReAct patterns.
  Compatible with Python DSPy's tool architecture.
  
  Supports:
  - Function calling with structured arguments
  - Tool registration and discovery
  - ReAct (Reasoning + Acting) patterns
  - Error handling and retry logic
  - Multi-step tool execution
  - Tool composition and chaining
  """

  defmodule Tool do
    @moduledoc """
    Represents a callable tool with metadata and validation.
    """
    
    defstruct [
      :name,
      :description,
      :function,
      :parameters,
      :return_type,
      :examples,
      :timeout,
      :retry_attempts,
      :validation_schema
    ]

    @type t :: %__MODULE__{
      name: String.t(),
      description: String.t(),
      function: function(),
      parameters: list(),
      return_type: atom(),
      examples: list(),
      timeout: pos_integer(),
      retry_attempts: pos_integer(),
      validation_schema: map() | nil
    }
  end

  defmodule ToolRegistry do
    @moduledoc """
    Registry for managing available tools.
    """
    
    use GenServer
    
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(_opts) do
      {:ok, %{tools: %{}, categories: %{}}}
    end

    def register_tool(%Tool{} = tool) do
      GenServer.call(__MODULE__, {:register, tool})
    end

    def get_tool(name) do
      GenServer.call(__MODULE__, {:get, name})
    end

    def list_tools do
      GenServer.call(__MODULE__, :list)
    end

    def search_tools(query) do
      GenServer.call(__MODULE__, {:search, query})
    end

    def handle_call({:register, tool}, _from, state) do
      updated_tools = Map.put(state.tools, tool.name, tool)
      {:reply, :ok, %{state | tools: updated_tools}}
    end

    def handle_call({:get, name}, _from, state) do
      tool = Map.get(state.tools, name)
      {:reply, tool, state}
    end

    def handle_call(:list, _from, state) do
      tools = Map.values(state.tools)
      {:reply, tools, state}
    end

    def handle_call({:search, query}, _from, state) do
      matching_tools = state.tools
      |> Map.values()
      |> Enum.filter(fn tool ->
        String.contains?(String.downcase(tool.name), String.downcase(query)) or
        String.contains?(String.downcase(tool.description), String.downcase(query))
      end)
      {:reply, matching_tools, state}
    end
  end

  defmodule FunctionCalling do
    @moduledoc """
    Handles structured function calling with language models.
    """
    
    def call_function(lm, function_spec, args, opts \\ []) do
      prompt = build_function_call_prompt(function_spec, args, opts)
      
      case Dspy.LM.generate(lm, prompt, opts) do
        {:ok, response} ->
          parse_function_response(response, function_spec, opts)
        {:error, reason} ->
          {:error, "Function call failed: #{reason}"}
      end
    end

    def build_function_call_prompt(function_spec, args, opts) do
      base_prompt = """
      You are a function calling assistant. Execute the following function with the provided arguments.
      
      Function: #{function_spec.name}
      Description: #{function_spec.description}
      
      Arguments:
      #{format_args(args)}
      
      Parameters:
      #{format_parameters(function_spec.parameters)}
      
      Execute the function and return the result in the specified format.
      """
      
      if opts[:format] == :json do
        base_prompt <> "\n\nReturn the result as JSON."
      else
        base_prompt
      end
    end

    defp format_args(args) when is_map(args) do
      Enum.map(args, fn {key, value} ->
        "- #{key}: #{inspect(value)}"
      end) |> Enum.join("\n")
    end

    defp format_parameters(parameters) do
      Enum.map(parameters, fn param ->
        "- #{param.name} (#{param.type}): #{param.description}"
      end) |> Enum.join("\n")
    end

    defp parse_function_response(response, function_spec, opts) do
      case opts[:format] do
        :json ->
          case Dspy.Adapters.parse(response, :json) do
            {:ok, parsed} -> validate_function_result(parsed, function_spec)
            {:error, reason} -> {:error, "Failed to parse JSON response: #{reason}"}
          end
        _ ->
          {:ok, response}
      end
    end

    defp validate_function_result(result, function_spec) do
      if function_spec.validation_schema do
        case validate_schema(result, function_spec.validation_schema) do
          :ok -> {:ok, result}
          {:error, reason} -> {:error, "Validation failed: #{reason}"}
        end
      else
        {:ok, result}
      end
    end

    defp validate_schema(data, schema) do
      # Basic schema validation - could be extended
      if is_map(data) and is_map(schema) do
        missing_keys = Map.keys(schema) -- Map.keys(data)
        if missing_keys == [] do
          :ok
        else
          {:error, "Missing required keys: #{inspect(missing_keys)}"}
        end
      else
        :ok
      end
    end
  end

  defmodule React do
    @moduledoc """
    Implementation of ReAct (Reasoning + Acting) pattern.
    Allows models to interleave reasoning and tool use.
    """
    
    defstruct [
      :lm,
      :tools,
      :max_steps,
      :thought_prefix,
      :action_prefix,
      :observation_prefix,
      :answer_prefix,
      :stop_words
    ]

    @type t :: %__MODULE__{
      lm: any(),
      tools: list(),
      max_steps: pos_integer(),
      thought_prefix: String.t(),
      action_prefix: String.t(),
      observation_prefix: String.t(),
      answer_prefix: String.t(),
      stop_words: list()
    }

    def new(lm, tools, opts \\ []) do
      %__MODULE__{
        lm: lm,
        tools: tools,
        max_steps: opts[:max_steps] || 10,
        thought_prefix: opts[:thought_prefix] || "Thought:",
        action_prefix: opts[:action_prefix] || "Action:",
        observation_prefix: opts[:observation_prefix] || "Observation:",
        answer_prefix: opts[:answer_prefix] || "Answer:",
        stop_words: opts[:stop_words] || ["Observation:", "Answer:"]
      }
    end

    def run(%__MODULE__{} = react, question, opts \\ []) do
      initial_prompt = build_react_prompt(react, question, opts)
      execute_react_loop(react, initial_prompt, [], 0)
    end

    defp build_react_prompt(react, question, _opts) do
      tool_descriptions = Enum.map(react.tools, fn tool ->
        "#{tool.name}: #{tool.description}"
      end) |> Enum.join("\n")
      
      """
      You are solving a problem step by step using reasoning and actions.
      
      Available tools:
      #{tool_descriptions}
      
      Use the following format:
      #{react.thought_prefix} [your reasoning about what to do next]
      #{react.action_prefix} [tool_name(arguments)]
      #{react.observation_prefix} [tool result will appear here]
      
      When you have enough information, provide your final answer:
      #{react.answer_prefix} [your final answer]
      
      Question: #{question}
      
      #{react.thought_prefix}
      """
    end

    defp execute_react_loop(react, prompt, history, step) when step < react.max_steps do
      case Dspy.LM.generate(react.lm, prompt, stop: react.stop_words) do
        {:ok, response} ->
          updated_prompt = prompt <> response
          
          case parse_react_step(response, react) do
            {:thought, thought} ->
              new_history = [{:thought, thought, step} | history]
              continue_react_loop(react, updated_prompt, new_history, step)
            
            {:action, action_call} ->
              case execute_action(action_call, react.tools) do
                {:ok, observation} ->
                  obs_text = "\n#{react.observation_prefix} #{observation}\n#{react.thought_prefix} "
                  new_prompt = updated_prompt <> obs_text
                  new_history = [{:action, action_call, step}, {:observation, observation, step} | history]
                  execute_react_loop(react, new_prompt, new_history, step + 1)
                
                {:error, error} ->
                  error_text = "\n#{react.observation_prefix} Error: #{error}\n#{react.thought_prefix} "
                  new_prompt = updated_prompt <> error_text
                  new_history = [{:action, action_call, step}, {:error, error, step} | history]
                  execute_react_loop(react, new_prompt, new_history, step + 1)
              end
            
            {:answer, answer} ->
              {:ok, %{
                answer: answer,
                steps: step + 1,
                history: Enum.reverse(history),
                reasoning_trace: extract_reasoning_trace(history)
              }}
            
            {:none, text} ->
              continue_react_loop(react, updated_prompt, history, step)
          end
        
        {:error, reason} ->
          {:error, "React execution failed: #{reason}"}
      end
    end

    defp execute_react_loop(react, _prompt, history, _step) do
      {:error, %{
        reason: "Max steps reached",
        max_steps: react.max_steps,
        history: Enum.reverse(history)
      }}
    end

    defp continue_react_loop(react, prompt, history, step) do
      execute_react_loop(react, prompt, history, step)
    end

    defp parse_react_step(text, react) do
      text = String.trim(text)
      
      cond do
        String.starts_with?(text, react.answer_prefix) ->
          answer = String.replace_prefix(text, react.answer_prefix, "") |> String.trim()
          {:answer, answer}
        
        String.contains?(text, react.action_prefix) ->
          case Regex.run(~r/#{react.action_prefix}\s*(.+)/i, text, capture: :all_but_first) do
            [action] -> {:action, String.trim(action)}
            _ -> {:none, text}
          end
        
        String.starts_with?(text, react.thought_prefix) ->
          thought = String.replace_prefix(text, react.thought_prefix, "") |> String.trim()
          {:thought, thought}
        
        true ->
          {:none, text}
      end
    end

    defp execute_action(action_call, tools) do
      case parse_action_call(action_call) do
        {:ok, {tool_name, args}} ->
          case find_tool(tool_name, tools) do
            {:ok, tool} ->
              call_tool(tool, args)
            {:error, reason} ->
              {:error, reason}
          end
        {:error, reason} ->
          {:error, reason}
      end
    end

    defp parse_action_call(action_call) do
      # Parse action calls like "search(query='machine learning')" or "calculate(2+2)"
      case Regex.run(~r/(\w+)\s*\(([^)]*)\)/, action_call, capture: :all_but_first) do
        [tool_name, args_str] ->
          case parse_arguments(args_str) do
            {:ok, args} -> {:ok, {tool_name, args}}
            {:error, reason} -> {:error, "Failed to parse arguments: #{reason}"}
          end
        _ ->
          # Maybe it's just a tool name
          {:ok, {String.trim(action_call), %{}}}
      end
    end

    defp parse_arguments(""), do: {:ok, %{}}
    defp parse_arguments(args_str) do
      # Simple argument parsing - could be more sophisticated
      try do
        # Try to parse as key=value pairs
        args = String.split(args_str, ",")
        |> Enum.map(&String.trim/1)
        |> Enum.reduce(%{}, fn arg, acc ->
          case String.split(arg, "=", parts: 2) do
            [key, value] ->
              clean_key = String.trim(key)
              clean_value = String.trim(value) |> String.trim("'\"")
              Map.put(acc, clean_key, clean_value)
            [single_arg] ->
              Map.put(acc, "query", String.trim(single_arg) |> String.trim("'\""))
          end
        end)
        
        {:ok, args}
      rescue
        _ -> {:error, "Invalid argument format"}
      end
    end

    defp find_tool(tool_name, tools) do
      case Enum.find(tools, &(&1.name == tool_name)) do
        nil -> {:error, "Tool '#{tool_name}' not found"}
        tool -> {:ok, tool}
      end
    end

    defp call_tool(%Tool{} = tool, args) do
      try do
        result = tool.function.(args)
        {:ok, result}
      rescue
        e -> {:error, "Tool execution failed: #{Exception.message(e)}"}
      end
    end

    defp extract_reasoning_trace(history) do
      history
      |> Enum.filter(fn {type, _content, _step} -> type == :thought end)
      |> Enum.map(fn {_type, content, step} -> "Step #{step}: #{content}" end)
      |> Enum.join("\n")
    end
  end

  # Predefined useful tools

  def builtin_tools do
    [
      %Tool{
        name: "search",
        description: "Search for information on the internet",
        function: &search_tool/1,
        parameters: [
          %{name: "query", type: "string", description: "Search query"},
          %{name: "num_results", type: "integer", description: "Number of results to return"}
        ],
        return_type: :list,
        timeout: 10_000,
        retry_attempts: 2
      },
      
      %Tool{
        name: "calculate",
        description: "Perform mathematical calculations",
        function: &calculate_tool/1,
        parameters: [
          %{name: "expression", type: "string", description: "Mathematical expression to evaluate"}
        ],
        return_type: :number,
        timeout: 5_000,
        retry_attempts: 1
      },
      
      %Tool{
        name: "datetime",
        description: "Get current date and time information",
        function: &datetime_tool/1,
        parameters: [
          %{name: "format", type: "string", description: "Date format (optional)"}
        ],
        return_type: :string,
        timeout: 1_000,
        retry_attempts: 1
      }
    ]
  end

  # Tool implementations

  defp search_tool(%{"query" => query} = args) do
    num_results = Map.get(args, "num_results", 5)
    
    # Mock search implementation - would integrate with real search API
    results = [
      %{title: "Result 1 for: #{query}", url: "https://example.com/1", snippet: "Sample result..."},
      %{title: "Result 2 for: #{query}", url: "https://example.com/2", snippet: "Another result..."}
    ] |> Enum.take(num_results)
    
    "Found #{length(results)} results for '#{query}': " <>
    Enum.map(results, &(&1.title)) |> Enum.join(", ")
  end

  defp calculate_tool(%{"expression" => expression}) do
    # Simple calculator - would use proper math parser in production
    case Code.eval_string(expression, [], __ENV__) do
      {result, _} -> "#{expression} = #{result}"
      _ -> "Error: Could not evaluate expression"
    end
  rescue
    _ -> "Error: Invalid mathematical expression"
  end

  defp datetime_tool(args) do
    format = Map.get(args, "format", "%Y-%m-%d %H:%M:%S")
    
    case DateTime.now("Etc/UTC") do
      {:ok, dt} -> 
        case Calendar.strftime(dt, format) do
          formatted -> "Current time: #{formatted}"
        end
      {:error, _} -> 
        "Error: Could not get current time"
    end
  end

  # Public API

  @doc """
  Register a tool in the global registry.
  """
  def register_tool(%Tool{} = tool) do
    ToolRegistry.register_tool(tool)
  end

  @doc """
  Get a tool by name from the registry.
  """
  def get_tool(name) do
    ToolRegistry.get_tool(name)
  end

  @doc """
  List all registered tools.
  """
  def list_tools do
    ToolRegistry.list_tools()
  end

  @doc """
  Search for tools by name or description.
  """
  def search_tools(query) do
    ToolRegistry.search_tools(query)
  end

  @doc """
  Create a new tool.
  """
  def new_tool(name, description, function, opts \\ []) do
    %Tool{
      name: name,
      description: description,
      function: function,
      parameters: opts[:parameters] || [],
      return_type: opts[:return_type] || :any,
      examples: opts[:examples] || [],
      timeout: opts[:timeout] || 30_000,
      retry_attempts: opts[:retry_attempts] || 3,
      validation_schema: opts[:validation_schema]
    }
  end

  @doc """
  Execute a tool with arguments.
  """
  def execute_tool(%Tool{} = tool, args, opts \\ []) do
    timeout = opts[:timeout] || tool.timeout
    
    task = Task.async(fn ->
      try do
        result = tool.function.(args)
        {:ok, result}
      rescue
        e -> {:error, Exception.message(e)}
      end
    end)
    
    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, "Tool execution timed out"}
    end
  end

  @doc """
  Create a ReAct agent with the given language model and tools.
  """
  def create_react_agent(lm, tools \\ [], opts \\ []) do
    all_tools = builtin_tools() ++ tools
    React.new(lm, all_tools, opts)
  end

  @doc """
  Initialize the tool system.
  """
  def start_link(opts \\ []) do
    children = [
      {ToolRegistry, opts}
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end