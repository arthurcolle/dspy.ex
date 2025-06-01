# DSPy for Elixir

Elixir implementation of DSPy - a framework for algorithmically optimizing language model prompts and weights.

DSPy provides a unified interface for composing LM programs with automatic optimization, bringing the power of systematic prompt engineering to the Elixir ecosystem.

## Features

- 🎯 **Type-safe signatures** - Define input/output interfaces with validation
- 🧩 **Composable modules** - Build complex programs from simple components  
- 🤔 **Chain of Thought** - Built-in step-by-step reasoning capabilities
- 🔌 **Multiple LM providers** - Support for OpenAI GPT-4.1 variants and more
- ⚡ **Fault tolerance** - Supervision trees for robust production deployment
- 🧪 **Comprehensive testing** - Full test suite with mock providers

## Quick Start

### Installation

Add `dspy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dspy, "~> 0.1.0"}
  ]
end
```

### Basic Usage

```elixir
# Configure with GPT-4.1 (most capable)
Dspy.configure(lm: %Dspy.LM.OpenAI{
  model: "gpt-4.1",
  api_key: System.get_env("OPENAI_API_KEY")
})

# Define a signature
defmodule QA do
  use Dspy.Signature
  
  input_field :question, :string, "Question to answer"
  output_field :answer, :string, "Answer to the question"
end

# Create and use a prediction module
predict = Dspy.Predict.new(QA)
{:ok, result} = Dspy.Module.forward(predict, %{question: "What is 2+2?"})

IO.puts(result.attrs.answer)  # "4"
```

### Chain of Thought Reasoning

```elixir
# Use Chain of Thought for step-by-step reasoning
cot = Dspy.ChainOfThought.new(QA)
{:ok, result} = Dspy.Module.forward(cot, %{question: "Solve: 15 + 27 * 3"})

IO.puts(result.attrs.reasoning)  # Shows step-by-step work
IO.puts(result.attrs.answer)     # Final answer
```

## GPT-4.1 Model Variants

DSPy supports all GPT-4.1 variants to optimize for your specific needs:

### gpt-4.1 - Maximum Capability
```elixir
Dspy.configure(lm: %Dspy.LM.OpenAI{model: "gpt-4.1"})
```
**Best for:** Complex reasoning, analysis, creative tasks, research

### gpt-4.1-mini - Balanced Performance  
```elixir
Dspy.configure(lm: %Dspy.LM.OpenAI{model: "gpt-4.1-mini"})
```
**Best for:** General applications, moderate complexity, production workloads

### gpt-4.1-nano - Speed & Economy
```elixir
Dspy.configure(lm: %Dspy.LM.OpenAI{model: "gpt-4.1-nano"})
```
**Best for:** Simple tasks, classifications, high-volume processing

## Examples

See the `examples/` directory for comprehensive usage examples:

- `basic_usage.exs` - Getting started with predictions and reasoning
- `model_comparison.exs` - Comparing GPT-4.1 variants for different tasks

## Core Components

### Signatures
Define typed interfaces for your LM calls:

```elixir
defmodule Summarizer do
  use Dspy.Signature
  
  signature_description "Summarize text concisely"
  signature_instructions "Focus on key points and main ideas"
  
  input_field :text, :string, "Text to summarize"
  input_field :max_length, :integer, "Maximum summary length", required: false
  output_field :summary, :string, "Concise summary"
  output_field :key_points, :string, "Bullet points of main ideas"
end
```

### Modules
Composable building blocks:

```elixir
# Basic prediction
predict = Dspy.Predict.new(Summarizer)

# Chain of thought reasoning
cot = Dspy.ChainOfThought.new(Summarizer)

# With few-shot examples
examples = [
  Dspy.example(%{
    text: "Long article text...",
    summary: "Brief summary...",
    key_points: "• Point 1\n• Point 2"
  })
]

few_shot = Dspy.Predict.new(Summarizer, examples: examples)
```

### Configuration
Global settings management:

```elixir
# Configure language model and parameters
Dspy.configure(
  lm: %Dspy.LM.OpenAI{
    model: "gpt-4.1-mini",
    api_key: System.get_env("OPENAI_API_KEY"),
    timeout: 30_000
  },
  max_tokens: 2048,
  temperature: 0.1,
  cache: true
)

# Get current settings
settings = Dspy.settings()
```

## Architecture

DSPy follows Elixir best practices:

- **GenServer-based configuration** for thread-safe global state
- **Behaviour-driven design** for extensible components  
- **Supervision trees** for fault tolerance
- **Functional composition** with pipeline operators
- **Pattern matching** for elegant error handling

## Testing

Run the test suite:

```bash
mix test
```

The library includes comprehensive tests with mock LM providers for reliable CI/CD.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality  
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

Based on the excellent [DSPy framework](https://github.com/stanfordnlp/dspy) by Stanford NLP Group.