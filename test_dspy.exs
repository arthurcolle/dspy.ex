IO.puts("Testing the implementation...")

# Configure the OpenAI client
api_key = System.get_env("OPENAI_API_KEY") || "dummy-key-for-testing"
Dspy.configure(lm: %Dspy.LM.OpenAI{
  model: "gpt-4.1",
  api_key: api_key
})

# Define the QA signature  
defmodule QA do
  use Dspy.Signature
  
  input_field :question, :string, "Question to answer"
  output_field :answer, :string, "Answer to the question"
end

# Create and test the predict module
predict = Dspy.Predict.new(QA)

case Dspy.Module.forward(predict, %{question: "What is 2+2?"}) do
  {:ok, result} -> 
    IO.puts("SUCCESS! Got result:")
    IO.inspect(result)
  {:error, reason} -> 
    IO.puts("Error occurred:")
    IO.inspect(reason)
end

