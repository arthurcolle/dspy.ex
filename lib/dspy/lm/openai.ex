defmodule Dspy.LM.OpenAI do
  @moduledoc """
  OpenAI language model client.
  
  Integrates with OpenAI's Chat Completions API to provide
  language model capabilities for DSPy.
  """

  @behaviour Dspy.LM

  defstruct [
    :api_key,
    :model,
    :base_url,
    :organization,
    timeout: 30_000
  ]

  @type t :: %__MODULE__{
    api_key: String.t(),
    model: String.t(),
    base_url: String.t(),
    organization: String.t() | nil,
    timeout: pos_integer()
  }

  @default_base_url "https://api.openai.com/v1"

  @doc """
  Create a new OpenAI client.
  """
  def new(opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")
    
    %__MODULE__{
      api_key: api_key,
      model: Keyword.get(opts, :model, "gpt-4.1-mini"),
      base_url: Keyword.get(opts, :base_url, @default_base_url),
      organization: Keyword.get(opts, :organization),
      timeout: Keyword.get(opts, :timeout, 30_000)
    }
  end

  @impl true
  def generate(client, request) do
    body = build_request_body(client, request)
    
    case make_request(client, "/chat/completions", body) do
      {:ok, response} -> 
        parse_response(response)
      {:error, reason} -> 
        {:error, reason}
    end
  end

  @impl true
  def supports?(_client, feature) do
    feature in [:chat, :tools, :streaming, :json_mode]
  end

  defp build_request_body(client, request) do
    base_body = %{
      model: client.model,
      messages: request.messages
    }
    
    base_body
    |> maybe_put(:max_tokens, request[:max_tokens])
    |> maybe_put(:temperature, request[:temperature])
    |> maybe_put(:stop, request[:stop])
    |> maybe_put(:tools, request[:tools])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp make_request(client, path, body) do
    if is_nil(client.api_key) do
      {:error, :missing_api_key}
    else
      base_url = client.base_url || @default_base_url
      url = String.to_charlist(base_url <> path)
    
    headers = [
      {'Authorization', String.to_charlist("Bearer #{client.api_key}")},
      {'Content-Type', 'application/json'}
    ]
    
    headers = if client.organization do
      [{'OpenAI-Organization', String.to_charlist(client.organization)} | headers]
    else
      headers
    end
    
    json_body = Jason.encode!(body) |> String.to_charlist()
    
    :inets.start()
    :ssl.start()
    
    request = {url, headers, 'application/json', json_body}
    
    case :httpc.request(:post, request, [{:timeout, client.timeout}], []) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        case Jason.decode(List.to_string(response_body)) do
          {:ok, parsed_body} -> {:ok, parsed_body}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end
      {:ok, {{_, status, _}, _headers, error_body}} ->
        {:error, {:http_error, status, List.to_string(error_body)}}
      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
    end
  end

  defp parse_response(response_body) do
    case response_body do
      %{"choices" => choices} = response when is_list(choices) and length(choices) > 0 ->
        parsed_choices = Enum.map(choices, fn choice ->
          %{
            message: choice["message"],
            finish_reason: choice["finish_reason"]
          }
        end)
        
        {:ok, %{
          choices: parsed_choices,
          usage: response_body["usage"]
        }}
      _ ->
        {:error, {:invalid_response, response_body}}
    end
  end

end