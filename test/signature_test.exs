defmodule DspySignatureTest do
  use ExUnit.Case

  describe "signature definition" do
    defmodule TestQA do
      use Dspy.Signature
      
      signature_description "Answer questions accurately"
      signature_instructions "Provide clear and concise answers"
      
      input_field :question, :string, "Question to answer"
      output_field :answer, :string, "Answer to the question"
    end

    test "can define signatures using DSL" do
      signature = TestQA.signature()
      
      assert signature.name == "Elixir.DspySignatureTest.TestQA"
      assert signature.description == "Answer questions accurately"
      assert signature.instructions == "Provide clear and concise answers"
      
      assert length(signature.input_fields) == 1
      assert length(signature.output_fields) == 1
      
      input_field = hd(signature.input_fields)
      assert input_field.name == :question
      assert input_field.type == :string
      
      output_field = hd(signature.output_fields)
      assert output_field.name == :answer
      assert output_field.type == :string
    end

    test "can generate prompts from signatures" do
      signature = TestQA.signature()
      prompt = Dspy.Signature.to_prompt(signature)
      
      assert prompt =~ "Instructions:"
      assert prompt =~ "Input Fields:"
      assert prompt =~ "Output Fields:"
      assert prompt =~ "Question: [input]"
      assert prompt =~ "Answer:"
    end

    test "can validate inputs" do
      signature = TestQA.signature()
      
      assert :ok = Dspy.Signature.validate_inputs(signature, %{question: "test"})
      assert {:error, {:missing_fields, [:question]}} = 
        Dspy.Signature.validate_inputs(signature, %{})
    end

    test "can parse outputs" do
      signature = TestQA.signature()
      response_text = "Answer: The answer is 42."
      
      outputs = Dspy.Signature.parse_outputs(signature, response_text)
      assert outputs.answer == "The answer is 42."
    end
  end
end