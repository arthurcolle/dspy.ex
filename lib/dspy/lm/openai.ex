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

  # Reasoning models
  @reasoning_models %{
    "o4-mini" => %{type: :reasoning, capabilities: [:text, :reasoning]},
    "o3" => %{type: :reasoning, capabilities: [:text, :reasoning]},
    "o3-mini" => %{type: :reasoning, capabilities: [:text, :reasoning]},
    "o1" => %{type: :reasoning, capabilities: [:text, :reasoning]},
    "o1-mini" => %{type: :reasoning, capabilities: [:text, :reasoning], deprecated: true},
    "o1-pro" => %{type: :reasoning, capabilities: [:text, :reasoning]}
  }

  # Flagship chat models
  @flagship_models %{
    "gpt-4.1" => %{type: :chat, capabilities: [:text, :vision, :tools]},
    "gpt-4o" => %{type: :chat, capabilities: [:text, :vision, :tools]},
    "gpt-4o-audio-preview" => %{type: :chat, capabilities: [:text, :vision, :audio, :tools]},
    "chatgpt-4o-latest" => %{type: :chat, capabilities: [:text, :vision, :tools]}
  }

  # Cost-optimized models
  @cost_optimized_models %{
    "gpt-4.1-mini" => %{type: :chat, capabilities: [:text, :vision, :tools]},
    "gpt-4.1-nano" => %{type: :chat, capabilities: [:text, :tools]},
    "gpt-4o-mini" => %{type: :chat, capabilities: [:text, :vision, :tools]},
    "gpt-4o-mini-audio-preview" => %{type: :chat, capabilities: [:text, :audio, :tools]}
  }

  # Realtime models
  @realtime_models %{
    "gpt-4o-realtime-preview" => %{type: :realtime, capabilities: [:text, :audio, :realtime]},
    "gpt-4o-mini-realtime-preview" => %{type: :realtime, capabilities: [:text, :audio, :realtime]}
  }

  # Image generation models
  @image_models %{
    "gpt-image-1" => %{type: :image_generation, capabilities: [:image_generation]},
    "dall-e-3" => %{type: :image_generation, capabilities: [:image_generation]},
    "dall-e-2" => %{type: :image_generation, capabilities: [:image_generation]}
  }

  # Text-to-speech models
  @tts_models %{
    "gpt-4o-mini-tts" => %{type: :tts, capabilities: [:text_to_speech]},
    "tts-1" => %{type: :tts, capabilities: [:text_to_speech]},
    "tts-1-hd" => %{type: :tts, capabilities: [:text_to_speech]}
  }

  # Transcription models
  @transcription_models %{
    "gpt-4o-transcribe" => %{type: :transcription, capabilities: [:speech_to_text]},
    "gpt-4o-mini-transcribe" => %{type: :transcription, capabilities: [:speech_to_text]},
    "whisper-1" => %{type: :transcription, capabilities: [:speech_to_text]}
  }

  # Tool-specific models
  @tool_models %{
    "gpt-4o-search-preview" => %{type: :search, capabilities: [:text, :search]},
    "gpt-4o-mini-search-preview" => %{type: :search, capabilities: [:text, :search]},
    "computer-use-preview" => %{type: :computer_use, capabilities: [:computer_use]},
    "codex-mini-latest" => %{type: :code, capabilities: [:text, :code]}
  }

  # Embeddings models
  @embedding_models %{
    "text-embedding-3-small" => %{type: :embedding, capabilities: [:embeddings]},
    "text-embedding-3-large" => %{type: :embedding, capabilities: [:embeddings]},
    "text-embedding-ada-002" => %{type: :embedding, capabilities: [:embeddings]}
  }

  # Moderation models
  @moderation_models %{
    "omni-moderation-latest" => %{
      type: :moderation,
      capabilities: [:text_moderation, :image_moderation]
    },
    "text-moderation-latest" => %{
      type: :moderation,
      capabilities: [:text_moderation],
      deprecated: true
    }
  }

  # Older GPT models
  @legacy_models %{
    "gpt-4-turbo" => %{type: :chat, capabilities: [:text, :vision, :tools]},
    "gpt-4" => %{type: :chat, capabilities: [:text, :tools]},
    "gpt-3.5-turbo" => %{type: :chat, capabilities: [:text, :tools], legacy: true}
  }

  # GPT base models
  @base_models %{
    "babbage-002" => %{type: :base, capabilities: [:text]},
    "davinci-002" => %{type: :base, capabilities: [:text]}
  }

  @all_models Map.merge(
                @reasoning_models,
                Map.merge(
                  @flagship_models,
                  Map.merge(
                    @cost_optimized_models,
                    Map.merge(
                      @realtime_models,
                      Map.merge(
                        @image_models,
                        Map.merge(
                          @tts_models,
                          Map.merge(
                            @transcription_models,
                            Map.merge(
                              @tool_models,
                              Map.merge(
                                @embedding_models,
                                Map.merge(
                                  @moderation_models,
                                  Map.merge(@legacy_models, @base_models)
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )

  @doc """
  Create a new OpenAI client.
  """
  def new(opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")
    model = Keyword.get(opts, :model, "gpt-4.1-mini")

    # Validate model exists
    unless Map.has_key?(@all_models, model) do
      raise ArgumentError,
            "Unknown model: #{model}. Available models: #{inspect(Map.keys(@all_models))}"
    end

    %__MODULE__{
      api_key: api_key,
      model: model,
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
  def supports?(client, feature) do
    model_info = Map.get(@all_models, client.model, %{})
    capabilities = Map.get(model_info, :capabilities, [])

    case feature do
      :chat -> :text in capabilities
      :tools -> :tools in capabilities
      # Most text models support streaming
      :streaming -> :text in capabilities
      :json_mode -> :text in capabilities
      :vision -> :vision in capabilities
      :audio -> :audio in capabilities
      :realtime -> :realtime in capabilities
      :image_generation -> :image_generation in capabilities
      :text_to_speech -> :text_to_speech in capabilities
      :speech_to_text -> :speech_to_text in capabilities
      :embeddings -> :embeddings in capabilities
      :moderation -> :text_moderation in capabilities or :image_moderation in capabilities
      :reasoning -> :reasoning in capabilities
      :search -> :search in capabilities
      :computer_use -> :computer_use in capabilities
      :code -> :code in capabilities
      _ -> false
    end
  end

  @doc """
  Get information about a model.
  """
  def model_info(model_name) do
    Map.get(@all_models, model_name)
  end

  @doc """
  List all available models.
  """
  def list_models do
    Map.keys(@all_models)
  end

  @doc """
  List models by type.
  """
  def list_models_by_type(type) do
    @all_models
    |> Enum.filter(fn {_name, info} -> Map.get(info, :type) == type end)
    |> Enum.map(fn {name, _info} -> name end)
  end

  @doc """
  List models by capability.
  """
  def list_models_by_capability(capability) do
    @all_models
    |> Enum.filter(fn {_name, info} ->
      capabilities = Map.get(info, :capabilities, [])
      capability in capabilities
    end)
    |> Enum.map(fn {name, _info} -> name end)
  end

  @doc """
  Check if a model is deprecated.
  """
  def deprecated?(model_name) do
    model_info = Map.get(@all_models, model_name, %{})
    Map.get(model_info, :deprecated, false)
  end

  @doc """
  Check if a model is legacy.
  """
  def legacy?(model_name) do
    model_info = Map.get(@all_models, model_name, %{})
    Map.get(model_info, :legacy, false)
  end

  defp build_request_body(client, request) do
    model_info = Map.get(@all_models, client.model, %{})
    model_type = Map.get(model_info, :type, :chat)

    base_body =
      case model_type do
        :chat ->
          %{
            model: client.model,
            messages: request.messages
          }

        :reasoning ->
          %{
            model: client.model,
            messages: request.messages
          }

        :embedding ->
          %{
            model: client.model,
            input: request[:input] || request[:text] || ""
          }

        :image_generation ->
          %{
            model: client.model,
            prompt: request[:prompt] || "",
            n: request[:n] || 1,
            size: request[:size] || "1024x1024"
          }

        :tts ->
          %{
            model: client.model,
            input: request[:input] || request[:text] || "",
            voice: request[:voice] || "alloy"
          }

        :transcription ->
          %{
            model: client.model,
            file: request[:file]
          }

        :moderation ->
          %{
            model: client.model,
            input: request[:input] || request[:text] || ""
          }

        _ ->
          %{
            model: client.model,
            messages: request.messages
          }
      end

    # Add common parameters for chat/reasoning models
    if model_type in [:chat, :reasoning] do
      base_body
      |> maybe_put(:max_tokens, request[:max_tokens])
      |> maybe_put(:temperature, request[:temperature])
      |> maybe_put(:stop, request[:stop])
      |> maybe_put(:tools, request[:tools])
      |> maybe_put(:response_format, format_response_format(request[:response_format]))
    else
      base_body
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_response_format(nil), do: nil
  defp format_response_format(%{type: "json_schema"} = format), do: format
  defp format_response_format(%{type: "json_object"}), do: %{type: "json_object"}
  defp format_response_format(%{type: "text"}), do: %{type: "text"}
  defp format_response_format(format), do: format

  defp make_request(client, path, body) do
    if is_nil(client.api_key) do
      {:error, :missing_api_key}
    else
      # Adjust endpoint based on model type
      model_info = Map.get(@all_models, client.model, %{})
      model_type = Map.get(model_info, :type, :chat)

      endpoint =
        case model_type do
          :chat -> "/chat/completions"
          :reasoning -> "/chat/completions"
          :embedding -> "/embeddings"
          :image_generation -> "/images/generations"
          :tts -> "/audio/speech"
          :transcription -> "/audio/transcriptions"
          :moderation -> "/moderations"
          _ -> path
        end

      base_url = client.base_url || @default_base_url
      url = String.to_charlist(base_url <> endpoint)

      headers = [
        {~c"Authorization", String.to_charlist("Bearer #{client.api_key}")},
        {~c"Content-Type", ~c"application/json; charset=utf-8"}
      ]

      headers =
        if client.organization do
          [{~c"OpenAI-Organization", String.to_charlist(client.organization)} | headers]
        else
          headers
        end

      json_body = Jason.encode!(body) |> String.to_charlist()

      :inets.start()
      :ssl.start()

      request = {url, headers, ~c"application/json", json_body}

      # HTTP options to suppress SSL certificate logging
      http_options = [
        {:timeout, client.timeout},
        {:ssl,
         [
           {:verify, :verify_none},
           {:log_level, :none}
         ]}
      ]

      case :httpc.request(:post, request, http_options, []) do
        {:ok, {{_, 200, _}, _headers, response_body}} ->
          # Convert charlist response to binary string properly
          body_string = List.to_string(response_body)

          case Jason.decode(body_string) do
            {:ok, parsed_body} -> {:ok, parsed_body}
            {:error, reason} -> {:error, {:json_decode_error, reason}}
          end

        {:ok, {{_, status, _}, _headers, error_body}} ->
          error_string = List.to_string(error_body)
          {:error, {:http_error, status, error_string}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  defp parse_response(response_body) do
    case response_body do
      %{"choices" => choices} when is_list(choices) and length(choices) > 0 ->
        parsed_choices =
          Enum.map(choices, fn choice ->
            %{
              message: choice["message"],
              finish_reason: choice["finish_reason"]
            }
          end)

        {:ok,
         %{
           choices: parsed_choices,
           usage: response_body["usage"]
         }}

      _ ->
        {:error, {:invalid_response, response_body}}
    end
  end
end
