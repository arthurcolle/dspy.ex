defmodule Dspy.Config.GPT41 do
  @moduledoc """
  Configuration presets for using GPT-4.1 with DSPy.

  Provides easy setup for different GPT-4.1 model variants:
  - gpt-4.1 (flagship)
  - gpt-4.1-mini (cost-optimized)
  - gpt-4.1-nano (ultra cost-optimized)

  Includes support for structured reasoning extraction using OpenAI's
  structured output feature.
  """

  alias Dspy.StructuredReasoning

  @doc """
  Configure DSPy to use GPT-4.1 flagship model.
  Best for complex reasoning tasks requiring maximum capability.
  """
  def configure_flagship(opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")

    if api_key do
      client =
        Dspy.LM.OpenAI.new(
          api_key: api_key,
          model: "gpt-4.1",
          timeout: Keyword.get(opts, :timeout, 120_000),
          organization: Keyword.get(opts, :organization)
        )

      Dspy.Settings.configure(lm: client)

      {:ok,
       %{
         model: "gpt-4.1",
         type: :flagship,
         capabilities: [:text, :vision, :tools, :structured_output],
         client: client
       }}
    else
      {:error, :missing_api_key}
    end
  end

  @doc """
  Configure DSPy to use GPT-4.1-mini.
  Balanced performance and cost for most reasoning tasks.
  """
  def configure_mini(opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")

    if api_key do
      client =
        Dspy.LM.OpenAI.new(
          api_key: api_key,
          model: "gpt-4.1-mini",
          timeout: Keyword.get(opts, :timeout, 90_000),
          organization: Keyword.get(opts, :organization)
        )

      Dspy.Settings.configure(lm: client)

      {:ok,
       %{
         model: "gpt-4.1-mini",
         type: :cost_optimized,
         capabilities: [:text, :vision, :tools, :structured_output],
         client: client
       }}
    else
      {:error, :missing_api_key}
    end
  end

  @doc """
  Configure DSPy to use GPT-4.1-nano.
  Most cost-effective for simple reasoning tasks.
  """
  def configure_nano(opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")

    if api_key do
      client =
        Dspy.LM.OpenAI.new(
          api_key: api_key,
          model: "gpt-4.1-nano",
          timeout: Keyword.get(opts, :timeout, 60_000),
          organization: Keyword.get(opts, :organization)
        )

      Dspy.Settings.configure(lm: client)

      {:ok,
       %{
         model: "gpt-4.1-nano",
         type: :ultra_cost_optimized,
         capabilities: [:text, :tools, :structured_output],
         client: client
       }}
    else
      {:error, :missing_api_key}
    end
  end

  @doc """
  Configure DSPy with the most appropriate GPT-4.1 variant based on task complexity.

  Options:
  - :complexity - :high, :medium, :low (default: :medium)
  - :budget - :premium, :balanced, :economy (default: :balanced)
  """
  def configure_auto(opts \\ []) do
    complexity = Keyword.get(opts, :complexity, :medium)
    budget = Keyword.get(opts, :budget, :balanced)

    model =
      case {complexity, budget} do
        {:high, _} -> :flagship
        {:low, :economy} -> :nano
        {:low, _} -> :mini
        {_, :premium} -> :flagship
        {_, :economy} -> :nano
        _ -> :mini
      end

    case model do
      :flagship -> configure_flagship(opts)
      :mini -> configure_mini(opts)
      :nano -> configure_nano(opts)
    end
  end

  @doc """
  Generate with structured reasoning using any GPT-4.1 model.

  This function uses OpenAI's structured output feature to extract
  chain-of-thought reasoning steps and final results.

  ## Examples

      {:ok, config} = Dspy.Config.GPT41.configure_mini()
      {:ok, reasoning} = Dspy.Config.GPT41.generate_with_reasoning(
        config.client,
        "What is 25 * 37? Think step by step."
      )
      
      IO.puts(Dspy.StructuredReasoning.format_reasoning(reasoning))
  """
  def generate_with_reasoning(client, prompt, opts \\ []) do
    # Create structured reasoning request
    request = StructuredReasoning.create_reasoning_request(prompt, opts)

    # Add model-specific settings based on the client's model
    settings =
      case client.model do
        "gpt-4.1" -> %{temperature: 0.7, max_tokens: 4096}
        "gpt-4.1-mini" -> %{temperature: 0.7, max_tokens: 2048}
        "gpt-4.1-nano" -> %{temperature: 0.7, max_tokens: 1024}
        _ -> %{temperature: 0.7, max_tokens: 2048}
      end

    # Merge with user options
    request =
      request
      |> Map.put(:temperature, Keyword.get(opts, :temperature, settings.temperature))
      |> Map.put(:max_tokens, Keyword.get(opts, :max_tokens, settings.max_tokens))

    # Generate response
    case Dspy.LM.OpenAI.generate(client, request) do
      {:ok, response} ->
        # Extract reasoning from response
        StructuredReasoning.extract_reasoning({:ok, response})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Create a client configured for structured reasoning.
  """
  def reasoning_client(model \\ "gpt-4.1-mini", opts \\ []) do
    api_key = Keyword.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")

    unless model in ["gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"] do
      raise ArgumentError,
            "Invalid model: #{model}. Must be one of: gpt-4.1, gpt-4.1-mini, gpt-4.1-nano"
    end

    Dspy.LM.OpenAI.new(
      api_key: api_key,
      model: model,
      timeout: Keyword.get(opts, :timeout, 90_000),
      organization: Keyword.get(opts, :organization)
    )
  end

  @doc """
  Get information about GPT-4.1 models.
  """
  def model_info do
    %{
      "gpt-4.1" => %{
        name: "GPT-4.1 Flagship",
        description: "Most capable model with vision and tool support",
        best_for: "Complex reasoning, multi-modal tasks, advanced problem solving",
        relative_cost: :high,
        speed: :medium,
        context_window: 128_000,
        supports_structured_output: true
      },
      "gpt-4.1-mini" => %{
        name: "GPT-4.1 Mini",
        description: "Balanced performance and cost",
        best_for: "General reasoning, most DSPy applications",
        relative_cost: :medium,
        speed: :fast,
        context_window: 128_000,
        supports_structured_output: true
      },
      "gpt-4.1-nano" => %{
        name: "GPT-4.1 Nano",
        description: "Ultra cost-optimized, text-only",
        best_for: "Simple reasoning, high-volume tasks",
        relative_cost: :low,
        speed: :very_fast,
        context_window: 64_000,
        supports_structured_output: true
      }
    }
  end

  @doc """
  Print model comparison table.
  """
  def print_comparison do
    IO.puts("\n📊 GPT-4.1 Model Comparison")
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("Model         | Cost | Speed      | Context | Structured | Best For")
    IO.puts("-" <> String.duplicate("-", 70))
    IO.puts("gpt-4.1       | $$$  | Medium     | 128K    | ✓          | Complex reasoning")
    IO.puts("gpt-4.1-mini  | $$   | Fast       | 128K    | ✓          | General use")
    IO.puts("gpt-4.1-nano  | $    | Very Fast  | 64K     | ✓          | Simple tasks")
    IO.puts("")
  end
end
