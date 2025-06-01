defmodule DspyTest do
  use ExUnit.Case
  doctest Dspy

  setup do
    # Reset settings for each test
    Dspy.configure(lm: nil, max_tokens: 2048, temperature: 0.0, cache: true)
    :ok
  end

  describe "configuration" do
    test "can configure DSPy settings" do
      lm = %Dspy.LM.OpenAI{model: "gpt-4.1", api_key: "test-key"}
      
      assert :ok = Dspy.configure(lm: lm, max_tokens: 1000)
      
      settings = Dspy.settings()
      assert settings.lm == lm
      assert settings.max_tokens == 1000
    end

    test "can get specific settings" do
      lm = %Dspy.LM.OpenAI{model: "gpt-4.1-nano", api_key: "test-key"}
      Dspy.configure(lm: lm)
      
      assert Dspy.Settings.get(:lm) == lm
    end
  end

  describe "examples and predictions" do
    test "can create examples" do
      example = Dspy.example(%{question: "What is 2+2?", answer: "4"})
      
      assert example.attrs.question == "What is 2+2?"
      assert example.attrs.answer == "4"
      assert Dspy.Example.get(example, :question) == "What is 2+2?"
    end

    test "can create predictions" do
      prediction = Dspy.prediction(%{answer: "4", reasoning: "2+2=4"})
      
      assert prediction.attrs.answer == "4"
      assert prediction.attrs.reasoning == "2+2=4"
      assert Dspy.Prediction.get(prediction, :answer) == "4"
    end
  end
end