defmodule Dspy.LM do
  @moduledoc """
  Behaviour for language model clients.
  
  Defines the interface for interacting with different language model providers
  like OpenAI, Anthropic, local models, etc.
  """

  @type message :: %{
    role: String.t(),
    content: String.t()
  }

  @type request :: %{
    messages: [message()],
    max_tokens: pos_integer() | nil,
    temperature: float() | nil,
    stop: [String.t()] | nil,
    tools: [map()] | nil
  }

  @type response :: %{
    choices: [%{
      message: message(),
      finish_reason: String.t() | nil
    }],
    usage: %{
      prompt_tokens: pos_integer(),
      completion_tokens: pos_integer(),
      total_tokens: pos_integer()
    } | nil
  }

  @type t :: struct()

  @doc """
  Generate a completion from the language model.
  """
  @callback generate(lm :: t(), request :: request()) :: {:ok, response()} | {:error, any()}

  @doc """
  Check if the language model supports a specific feature.
  """
  @callback supports?(lm :: t(), feature :: atom()) :: boolean()

  @optional_callbacks [supports?: 2]

  @doc """
  Generate a completion using the configured language model.
  """
  def generate(request) do
    case Dspy.Settings.get(:lm) do
      nil -> {:error, :no_lm_configured}
      lm -> generate(lm, request)
    end
  end

  @doc """
  Generate a completion using a specific language model.
  """
  def generate(lm, request) do
    lm.__struct__.generate(lm, request)
  end

  @doc """
  Generate text from a simple prompt string.
  """
  def generate_text(prompt, opts \\ []) do
    request = %{
      messages: [%{role: "user", content: prompt}],
      max_tokens: Keyword.get(opts, :max_tokens),
      temperature: Keyword.get(opts, :temperature),
      stop: Keyword.get(opts, :stop)
    }
    
    case generate(request) do
      {:ok, response} ->
        content = get_in(response, [:choices, Access.at(0), :message, :content])
        {:ok, content}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if a language model supports a feature.
  """
  def supports?(lm, feature) do
    if function_exported?(lm.__struct__, :supports?, 2) do
      lm.__struct__.supports?(lm, feature)
    else
      false
    end
  end

  @doc """
  Create a chat message.
  """
  def message(role, content) do
    %{role: to_string(role), content: content}
  end

  @doc """
  Create a user message.
  """
  def user_message(content), do: message("user", content)

  @doc """
  Create an assistant message.
  """
  def assistant_message(content), do: message("assistant", content)

  @doc """
  Create a system message.
  """
  def system_message(content), do: message("system", content)
end