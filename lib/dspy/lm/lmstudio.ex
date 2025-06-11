defmodule Dspy.LM.LMStudio do
  @moduledoc """
  LMStudio language model client with streaming and structured output support.
  
  Integrates with LM Studio's local model server to provide streaming completions
  with JSON schema-based structured outputs.
  """

  @behaviour Dspy.LM
  
  require Logger

  defstruct [
    :base_url,
    :model,
    :temperature,
    :max_tokens,
    timeout: 60_000
  ]

  @type t :: %__MODULE__{
          base_url: String.t(),
          model: String.t(),
          temperature: float() | nil,
          max_tokens: pos_integer() | nil,
          timeout: pos_integer()
        }

  @default_base_url "http://localhost:1234"

  @doc """
  Create a new LMStudio client.
  """
  def new(opts \\ []) do
    %__MODULE__{
      base_url: Keyword.get(opts, :base_url, @default_base_url),
      model: Keyword.get(opts, :model, "deepseek-r1-0528-qwen3-8b-mlx"),
      temperature: Keyword.get(opts, :temperature, 0.7),
      max_tokens: Keyword.get(opts, :max_tokens, 2048),
      timeout: Keyword.get(opts, :timeout, 60_000)
    }
  end

  @impl true
  def generate(client, request) do
    messages = build_messages(request)
    
    opts = [
      model: client.model,
      temperature: client.temperature || 0.7,
      max_tokens: client.max_tokens || -1
    ]

    # Add structured output support via response_format
    {opts, messages} = if request[:response_format] do
      case request[:response_format] do
        %{type: "json_schema", json_schema: schema} ->
          # For structured output, we'll use a system prompt approach since
          # LM Studio may not support OpenAI's response_format directly
          schema_prompt = build_schema_prompt(schema)
          updated_messages = prepend_schema_system_message(messages, schema_prompt)
          {opts, updated_messages}
        _ ->
          {opts, messages}
      end
    else
      {opts, messages}
    end

    # Make HTTP request to LMStudio API
    case make_http_request(client, messages, opts) do
      {:ok, response} ->
        parse_response(response)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generate with streaming support and structured outputs.
  """
  def generate_stream(client, request, callback_fn) do
    messages = build_messages(request)
    
    opts = [
      model: client.model,
      temperature: client.temperature || 0.7,
      max_tokens: client.max_tokens || -1,
      stream: true,
      n: request[:n] || 1,
      logprobs: request[:logprobs] || false,
      stream_callback: fn
        {:chunk, content} -> callback_fn.({:chunk, content})
        {:done, _} -> callback_fn.({:done, nil})
      end
    ]

    # Handle structured output in streaming mode
    {opts, messages} = if request[:response_format] do
      case request[:response_format] do
        %{type: "json_schema", json_schema: schema} ->
          schema_prompt = build_schema_prompt(schema)
          updated_messages = prepend_schema_system_message(messages, schema_prompt)
          {opts, updated_messages}
        _ ->
          {opts, messages}
      end
    else
      {opts, messages}
    end

    # Make streaming HTTP request to LMStudio API
    case make_streaming_http_request(client, messages, opts) do
      {:ok, :stream_complete} ->
        {:ok, %{streaming: true}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generate dual outputs: streaming for real-time feedback and non-streaming for JSON processing.
  Returns both streaming content and final structured response.
  """
  def generate_dual(client, request, stream_callback \\ nil) do
    # Start streaming generation for real-time feedback
    streaming_task = if stream_callback do
      Task.async(fn ->
        generate_stream(client, request, stream_callback)
      end)
    else
      nil
    end
    
    # Non-streaming generation for final structured output with multiple choices
    final_request = Map.merge(request, %{
      n: request[:n] || 4,
      logprobs: request[:logprobs] || true,
      stream: false
    })
    
    final_result = generate(client, final_request)
    
    # Wait for streaming to complete if it was started
    streaming_result = if streaming_task do
      Task.await(streaming_task, :infinity)
    else
      {:ok, %{streaming: false}}
    end
    
    {:ok, %{
      streaming: streaming_result,
      final: final_result
    }}
  end

  @doc """
  Generate with two different models in parallel: one for streaming and one for structured output.
  This allows true dual-model generation using different model instances.
  """
  def generate_dual_models(streaming_client, final_client, request, stream_callback \\ nil) do
    # Start streaming generation with first model for real-time feedback
    streaming_task = if stream_callback do
      Task.async(fn ->
        generate_stream(streaming_client, request, stream_callback)
      end)
    else
      nil
    end
    
    # Start non-streaming generation with second model for final structured output
    final_task = Task.async(fn ->
      final_request = Map.merge(request, %{
        n: request[:n] || 4,
        logprobs: request[:logprobs] || true,
        stream: false
      })
      generate(final_client, final_request)
    end)
    
    # Wait for both to complete
    final_result = Task.await(final_task, :infinity)
    
    streaming_result = if streaming_task do
      Task.await(streaming_task, :infinity)
    else
      {:ok, %{streaming: false}}
    end
    
    {:ok, %{
      streaming: %{result: streaming_result, model: streaming_client.model},
      final: %{result: final_result, model: final_client.model}
    }}
  end

  @impl true
  def supports?(_client, feature) do
    case feature do
      :chat -> true
      :streaming -> true
      :json_mode -> true
      :structured_output -> true
      :tools -> true
      _ -> false
    end
  end

  # Private functions

  defp make_http_request(client, messages, opts) do
    url = "#{client.base_url}/v1/chat/completions"
    
    # Use different accept header for streaming
    headers = if opts[:stream] do
      [
        {~c"Content-Type", ~c"application/json"},
        {~c"Accept", ~c"text/event-stream"}
      ]
    else
      [
        {~c"Content-Type", ~c"application/json"},
        {~c"Accept", ~c"application/json"}
      ]
    end
    
    body = %{
      model: client.model,
      messages: messages,
      temperature: opts[:temperature] || client.temperature,
      max_tokens: opts[:max_tokens] || client.max_tokens
    }
    
    # Add optional parameters
    body = if opts[:n] && opts[:n] > 1, do: Map.put(body, :n, opts[:n]), else: body
    body = if opts[:logprobs], do: Map.put(body, :logprobs, opts[:logprobs]), else: body
    body = if opts[:stream], do: Map.put(body, :stream, opts[:stream]), else: body
    
    case :httpc.request(:post, {String.to_charlist(url), headers, ~c"application/json", String.to_charlist(Jason.encode!(body))}, [], []) do
      {:ok, {{_, 200, _}, _, response_body}} ->
        if opts[:stream] do
          # Handle SSE response
          parse_sse_response(response_body)
        else
          # Handle regular JSON response
          {:ok, Jason.decode!(response_body)}
        end
      {:ok, {{_, status, _}, _, response_body}} ->
        {:error, {:http_error, status, response_body}}
      {:error, reason} ->
        {:error, {:http_request_failed, reason}}
    end
  rescue
    e -> {:error, {:request_exception, e}}
  end

  defp make_streaming_http_request(client, messages, opts) do
    url = "#{client.base_url}/v1/chat/completions"
    
    body = %{
      model: client.model,
      messages: messages,
      temperature: opts[:temperature] || client.temperature,
      max_tokens: opts[:max_tokens] || client.max_tokens,
      stream: true
    }
    
    # Add optional parameters for streaming
    body = if opts[:n] && opts[:n] > 1, do: Map.put(body, :n, opts[:n]), else: body
    body = if opts[:logprobs], do: Map.put(body, :logprobs, opts[:logprobs]), else: body
    
    # Use httpc for HTTP request (streaming not fully supported, fallback to regular request)
    case Jason.encode(body) do
      {:ok, json_body} ->
        try do
          request = {
            String.to_charlist(url),
            [
              {~c"Content-Type", ~c"application/json"},
              {~c"Accept", ~c"text/event-stream"}
            ],
            ~c"application/json",
            String.to_charlist(json_body)
          }

          http_options = [
            {:timeout, 30_000},
            {:ssl, [{:verify, :verify_none}, {:log_level, :none}]}
          ]

          case :httpc.request(:post, request, http_options, []) do
            {:ok, {{_, 200, _}, _headers, response_body}} ->
              body_string = List.to_string(response_body)
              
              if opts[:stream_callback] do
                # Parse response and call callback
                parse_and_stream_chunk("data: #{body_string}", opts[:stream_callback])
                opts[:stream_callback].({:done, nil})
              end
              
              {:ok, :stream_complete}

            {:ok, {{_, status, _}, _headers, error_body}} ->
              error_string = List.to_string(error_body)
              {:error, {:http_error, status, error_string}}

            {:error, reason} ->
              {:error, {:request_failed, reason}}
          end
        rescue
          e -> {:error, {:streaming_failed, e}}
        end

      {:error, reason} ->
        {:error, {:json_encode_error, reason}}
    end
  end

  defp build_messages(request) do
    case request[:messages] do
      nil -> []
      messages when is_list(messages) -> messages
      _ -> []
    end
  end

  defp build_schema_prompt(schema) do
    """
    You must respond with valid JSON that strictly follows this schema:

    #{Jason.encode!(schema, pretty: true)}

    Important requirements:
    - Your response MUST be valid JSON
    - Your response MUST conform exactly to the provided schema
    - Do not include any text before or after the JSON
    - Ensure all required fields are present
    - Follow the specified data types exactly
    """
  end

  defp prepend_schema_system_message(messages, schema_prompt) do
    # Check if there's already a system message
    case messages do
      [%{role: "system"} = system_msg | rest] ->
        # Combine with existing system message
        updated_content = system_msg.content <> "\n\n" <> schema_prompt
        [%{system_msg | content: updated_content} | rest]
      
      _ ->
        # Add new system message
        [%{role: "system", content: schema_prompt} | messages]
    end
  end

  defp parse_response(response) do
    case response do
      %{"choices" => choices} when is_list(choices) and length(choices) > 0 ->
        parsed_choices =
          Enum.map(choices, fn choice ->
            base_choice = %{
              message: choice["message"],
              finish_reason: choice["finish_reason"]
            }
            
            # Add logprobs if present
            if choice["logprobs"] do
              Map.put(base_choice, :logprobs, choice["logprobs"])
            else
              base_choice
            end
          end)

        result = %{
          choices: parsed_choices,
          usage: response["usage"]
        }
        
        # Add model info if present
        result = if response["model"], do: Map.put(result, :model, response["model"]), else: result
        result = if response["id"], do: Map.put(result, :id, response["id"]), else: result

        {:ok, result}

      _ ->
        {:error, {:invalid_response, response}}
    end
  end

  defp parse_sse_response(response_body) do
    try do
      # Parse SSE format - split by double newlines and extract data lines
      # Convert charlist to binary string first (httpc returns charlist)
      chunks = String.split(to_string(response_body), "\n\n")
      
      # Extract and combine all delta content from SSE chunks
      content_parts = 
        chunks
        |> Enum.flat_map(fn chunk ->
          chunk
          |> String.split("\n")
          |> Enum.filter(&String.starts_with?(&1, "data: "))
          |> Enum.map(&String.trim_leading(&1, "data: "))
          |> Enum.reject(&(&1 == "[DONE]" || &1 == ""))
        end)
        |> Enum.map(&parse_sse_chunk/1)
        |> Enum.reject(&is_nil/1)

      # Combine all content parts
      combined_content = 
        content_parts
        |> Enum.map(fn chunk -> 
          get_in(chunk, ["choices", Access.at(0), "delta", "content"]) || ""
        end)
        |> Enum.join("")

      # Return in standard format
      {:ok, %{
        "choices" => [%{
          "message" => %{"content" => combined_content, "role" => "assistant"},
          "finish_reason" => "stop"
        }],
        "usage" => %{"completion_tokens" => String.length(combined_content), "prompt_tokens" => 0}
      }}
    rescue
      e -> {:error, {:sse_parse_error, e}}
    end
  end

  defp parse_sse_chunk(json_str) do
    try do
      Jason.decode!(json_str)
    rescue
      _ -> nil
    end
  end

  defp parse_and_stream_chunk(chunk, callback) do
    # Parse SSE data chunks and extract content
    chunk
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.map(&String.trim_leading(&1, "data: "))
    |> Enum.reject(&(&1 == "[DONE]" || &1 == ""))
    |> Enum.each(fn data_line ->
      case Jason.decode(data_line) do
        {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}} when is_binary(content) ->
          callback.({:chunk, content})
        {:ok, _} ->
          # Other SSE messages (metadata, etc.)
          :ok
        {:error, _} ->
          # Invalid JSON in chunk
          :ok
      end
    end)
  end
end