defmodule DspyPredictTest do
  use ExUnit.Case

  defmodule MockLM do
    @behaviour Dspy.LM
    defstruct []

    def generate(_lm, request) do
      # Extract the question from the prompt
      _prompt = hd(request.messages).content
      
      response = %{
        choices: [
          %{
            message: %{
              role: "assistant",
              content: "Answer: 4"
            },
            finish_reason: "stop"
          }
        ],
        usage: %{
          prompt_tokens: 10,
          completion_tokens: 5,
          total_tokens: 15
        }
      }
      
      {:ok, response}
    end

    def supports?(_lm, _feature), do: true
  end

  defmodule TestQA do
    use Dspy.Signature
    
    input_field :question, :string, "Question to answer"
    output_field :answer, :string, "Answer to the question"
  end

  setup do
    # Configure with mock LM
    mock_lm = %MockLM{}
    Dspy.configure(lm: mock_lm)
    
    :ok
  end

  describe "predict module" do
    test "can create predict modules" do
      predict = Dspy.Predict.new(TestQA)
      
      assert predict.signature.name == "Elixir.DspyPredictTest.TestQA"
      assert predict.examples == []
      assert predict.max_retries == 3
    end

    test "can forward predictions" do
      predict = Dspy.Predict.new(TestQA)
      inputs = %{question: "What is 2+2?"}
      
      assert {:ok, prediction} = Dspy.Module.forward(predict, inputs)
      assert prediction.attrs.answer == "4"
    end

    test "validates inputs before prediction" do
      predict = Dspy.Predict.new(TestQA)
      
      assert {:error, {:missing_fields, [:question]}} = 
        Dspy.Module.forward(predict, %{})
    end
  end

  describe "chain of thought module" do
    test "can create chain of thought modules" do
      cot = Dspy.ChainOfThought.new(TestQA)
      
      # Should add reasoning field to output
      reasoning_field = Enum.find(cot.signature.output_fields, & &1.name == :reasoning)
      assert reasoning_field != nil
      assert reasoning_field.description =~ "step by step"
    end

    test "generates enhanced prompts with reasoning instructions" do
      cot = Dspy.ChainOfThought.new(TestQA)
      
      # The reasoning field should be added with step-by-step description
      reasoning_field = Enum.find(cot.signature.output_fields, & &1.name == :reasoning)
      assert reasoning_field.description =~ "step by step"
      
      # Verify that output fields include reasoning
      field_names = Enum.map(cot.signature.output_fields, & &1.name)
      assert :reasoning in field_names
      assert :answer in field_names
    end
  end
end