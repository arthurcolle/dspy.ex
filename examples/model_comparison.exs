# GPT-4.1 Model Variant Comparison Examples

defmodule ModelComparison do
  @moduledoc """
  Examples demonstrating when to use different GPT-4.1 variants:
  
  - gpt-4.1: Maximum capability, complex reasoning, highest cost
  - gpt-4.1-mini: Balanced performance/cost, good for most tasks  
  - gpt-4.1-nano: Fast responses, simple tasks, lowest cost
  """

  # Define a complex reasoning signature
  defmodule ComplexReasoning do
    use Dspy.Signature
    
    signature_description "Analyze complex scenarios with multi-step reasoning"
    signature_instructions "Break down the problem systematically and consider multiple factors"
    
    input_field :scenario, :string, "Complex scenario to analyze"
    output_field :analysis, :string, "Detailed step-by-step analysis"
    output_field :conclusion, :string, "Final conclusion with confidence level"
  end

  # Define a simple classification task
  defmodule SimpleClassification do
    use Dspy.Signature
    
    signature_description "Classify text into predefined categories"
    
    input_field :text, :string, "Text to classify"
    output_field :category, :string, "One of: positive, negative, neutral"
    output_field :confidence, :string, "High, medium, or low confidence"
  end

  def run_comparison do
    models = [
      {"gpt-4.1", "Best for complex reasoning and analysis"},
      {"gpt-4.1-mini", "Good balance for most applications"}, 
      {"gpt-4.1-nano", "Fast and economical for simple tasks"}
    ]

    Enum.each(models, fn {model, description} ->
      IO.puts("\n=== Testing #{model} ===")
      IO.puts(description)
      
      # Configure the model with appropriate timeout
      timeout = case model do
        "gpt-4.1" -> 180_000       # 3 minutes for complex reasoning
        "gpt-4.1-mini" -> 120_000  # 2 minutes
        "gpt-4.1-nano" -> 90_000   # 1.5 minutes
      end
      
      Dspy.configure(lm: %Dspy.LM.OpenAI{
        model: model,
        api_key: System.get_env("OPENAI_API_KEY"),
        timeout: timeout
      })
      
      # Test complex reasoning (gpt-4.1 excels here)
      test_complex_reasoning()
      
      # Test simple classification (all models work well)
      test_simple_classification()
    end)
  end

  defp test_complex_reasoning do
    IO.puts("\n--- Complex Reasoning Task ---")
    
    complex_module = Dspy.ChainOfThought.new(ComplexReasoning)
    
    scenario = """
    A startup has limited resources and must choose between two strategies:
    A) Invest heavily in R&D for a breakthrough product (high risk, high reward)
    B) Focus on incremental improvements to existing products (low risk, steady growth)
    The market is highly competitive, the team is experienced but small, and 
    they have 18 months of runway remaining.
    """
    
    case Dspy.Module.forward(complex_module, %{scenario: scenario}) do
      {:ok, prediction} ->
        IO.puts("Analysis: #{String.slice(prediction.attrs.analysis, 0, 200)}...")
        IO.puts("Conclusion: #{prediction.attrs.conclusion}")
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  defp test_simple_classification do
    IO.puts("\n--- Simple Classification Task ---")
    
    classifier = Dspy.Predict.new(SimpleClassification)
    
    texts = [
      "I absolutely love this product! It exceeded my expectations.",
      "The service was terrible and the staff was rude.",
      "The weather is cloudy today with a chance of rain."
    ]
    
    Enum.each(texts, fn text ->
      case Dspy.Module.forward(classifier, %{text: text}) do
        {:ok, prediction} ->
          IO.puts("Text: #{String.slice(text, 0, 50)}...")
          IO.puts("Category: #{prediction.attrs.category} (#{prediction.attrs.confidence})")
        {:error, reason} ->
          IO.puts("Error: #{inspect(reason)}")
      end
    end)
  end
end

# Usage recommendations based on model capabilities:

IO.puts("""
🚀 GPT-4.1 Model Selection Guide:

📊 gpt-4.1 - Use for:
  - Complex reasoning and analysis
  - Multi-step problem solving
  - Creative writing and ideation
  - Code review and architecture decisions
  - Research and summarization of complex topics

⚖️ gpt-4.1-mini - Use for:
  - General Q&A and chat applications
  - Content generation and editing
  - Data extraction and transformation
  - Moderate complexity reasoning
  - Most production applications

⚡ gpt-4.1-nano - Use for:
  - Simple classifications and labels
  - Basic text processing
  - Quick factual questions
  - High-volume, low-complexity tasks
  - Cost-sensitive applications

Example configuration for each use case:
""")

# High-complexity research assistant
research_config = %Dspy.LM.OpenAI{
  model: "gpt-4.1",
  api_key: System.get_env("OPENAI_API_KEY"),
  timeout: 60_000  # Longer timeout for complex tasks
}

# General-purpose chatbot
chatbot_config = %Dspy.LM.OpenAI{
  model: "gpt-4.1-mini", 
  api_key: System.get_env("OPENAI_API_KEY"),
  timeout: 30_000  # Standard timeout
}

# High-volume classifier
classifier_config = %Dspy.LM.OpenAI{
  model: "gpt-4.1-nano",
  api_key: System.get_env("OPENAI_API_KEY"), 
  timeout: 10_000  # Fast responses needed
}

IO.inspect([research_config, chatbot_config, classifier_config], label: "Configurations")

# Uncomment to run the comparison:
# ModelComparison.run_comparison()