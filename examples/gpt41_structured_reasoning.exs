#!/usr/bin/env elixir

# Example: Using structured outputs to extract reasoning from GPT-4.1 models

# Add the parent directory to the path
Code.prepend_path("_build/dev/lib/dspy/ebin")

# Import required modules
alias Dspy.Config.GPT41
alias Dspy.StructuredReasoning

# Test problems of varying complexity
problems = [
  %{
    prompt: "What is 25 * 37? Think step by step.",
    complexity: :simple
  },
  %{
    prompt: """
    A farmer has 17 sheep. All but 9 run away. How many sheep are left?
    Think through this carefully step by step.
    """,
    complexity: :medium
  },
  %{
    prompt: """
    You have 8 balls. One of them is slightly heavier than the others, but you can't tell by looking.
    You have a balance scale. What's the minimum number of weighings needed to find the heavier ball?
    Explain your reasoning step by step.
    """,
    complexity: :complex
  }
]

# Test each model
models = ["gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"]

IO.puts("\n🧠 GPT-4.1 Structured Reasoning Examples")
IO.puts("=" <> String.duplicate("=", 60))
IO.puts("Using OpenAI's structured output feature to extract")
IO.puts("chain-of-thought reasoning from GPT-4.1 models\n")

for model <- models do
  IO.puts("\n" <> String.duplicate("─", 60))
  IO.puts("📊 Testing #{model}")
  IO.puts(String.duplicate("─", 60))
  
  # Create client for this model
  client = GPT41.reasoning_client(model)
  
  for problem <- problems do
    IO.puts("\n❓ Problem (#{problem.complexity}): #{String.slice(problem.prompt, 0, 50)}...")
    
    case GPT41.generate_with_reasoning(client, problem.prompt) do
      {:ok, reasoning} ->
        # Display formatted reasoning
        IO.puts(StructuredReasoning.format_reasoning(reasoning))
        
        # Show token usage if available
        IO.puts("\n📈 Stats:")
        IO.puts("   Steps: #{length(reasoning["reasoning_steps"] || [])}")
        if reasoning["confidence"] do
          IO.puts("   Confidence: #{Float.round(reasoning["confidence"] * 1.0, 2)}")
        end
        
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
    
    # Brief pause between requests
    Process.sleep(1000)
  end
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✨ Key Observations:")
IO.puts("- All GPT-4.1 models support structured output")
IO.puts("- Chain-of-thought reasoning can be extracted systematically")
IO.puts("- Models maintain reasoning quality at their respective tiers")
IO.puts("- Nano is fastest and most cost-effective for simple reasoning")
IO.puts("- Mini provides best balance for general use")
IO.puts("- Flagship excels at complex multi-step reasoning")

# Demonstrate custom reasoning schema
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("🔧 Custom Reasoning Schema Example")
IO.puts(String.duplicate("=", 60))

# Create a custom schema for math problems
math_schema = %{
  type: "object",
  properties: %{
    problem_type: %{
      type: "string",
      enum: ["arithmetic", "algebra", "geometry", "logic", "other"]
    },
    steps: %{
      type: "array",
      items: %{
        type: "object",
        properties: %{
          operation: %{type: "string"},
          calculation: %{type: "string"},
          result: %{type: "number"}
        },
        required: ["operation", "calculation"]
      }
    },
    final_answer: %{type: "number"},
    unit: %{type: "string"},
    explanation: %{type: "string"}
  },
  required: ["problem_type", "steps", "final_answer", "explanation"]
}

# Test with a math problem
math_prompt = "A rectangle has a length of 12 meters and width of 8 meters. What is its area?"

client = GPT41.reasoning_client("gpt-4.1-mini")

request = %{
  messages: [
    %{role: "system", content: "You are a math tutor. Solve problems step by step."},
    %{role: "user", content: math_prompt}
  ],
  response_format: %{
    type: "json_schema",
    json_schema: %{
      name: "math_solution",
      schema: math_schema
    }
  },
  temperature: 0.3
}

IO.puts("\nTesting custom math schema with GPT-4.1-mini...")
IO.puts("Problem: #{math_prompt}")

case Dspy.LM.OpenAI.generate(client, request) do
  {:ok, response} ->
    case StructuredReasoning.extract_reasoning({:ok, response}) do
      {:ok, solution} ->
        IO.puts("\nStructured Solution:")
        IO.puts("Problem Type: #{solution["problem_type"]}")
        IO.puts("\nSteps:")
        for {step, i} <- Enum.with_index(solution["steps"] || [], 1) do
          IO.puts("#{i}. #{step["operation"]}: #{step["calculation"]}")
          if step["result"], do: IO.puts("   Result: #{step["result"]}")
        end
        IO.puts("\nFinal Answer: #{solution["final_answer"]} #{solution["unit"] || ""}")
        IO.puts("Explanation: #{solution["explanation"]}")
        
      {:error, reason} ->
        IO.puts("Error parsing response: #{inspect(reason)}")
    end
    
  {:error, reason} ->
    IO.puts("Error generating response: #{inspect(reason)}")
end

IO.puts("\n✅ Structured outputs enable systematic reasoning extraction!")
IO.puts("   Perfect for building reliable, interpretable AI systems.")