defmodule ReasoningMethodsShowcase do
  @moduledoc """
  Comprehensive examples showcasing all DSPy reasoning methods.
  
  Each example demonstrates a different reasoning approach:
  - SelfConsistency: Multiple reasoning paths, selecting most consistent answer
  - MultiStep: Breaking down complex problems into sequential steps
  - Reflection: Generate answer, then reflect and improve
  - ProgramOfThoughts: Combine reasoning with executable code
  - SelfCorrectingCoT: Chain of thought with self-correction
  - TreeOfThoughts: Explore multiple reasoning paths in tree structure
  """

  def run do
    IO.puts("\n🧠 DSPy Reasoning Methods Showcase")
    IO.puts("=" <> String.duplicate("=", 50))
    
    # Start DSPy application
    {:ok, _} = Application.ensure_all_started(:dspy)
    
    # Run each example
    self_consistency_example()
    multi_step_example()
    reflection_example()
    program_of_thoughts_example()
    self_correcting_cot_example()
    tree_of_thoughts_example()
  end

  # =========== Self-Consistency Example ===========
  def self_consistency_example do
    IO.puts("\n\n1️⃣ Self-Consistency Example")
    IO.puts("-" <> String.duplicate("-", 40))
    IO.puts("Problem: Calculate the average of three test scores")
    
    # Define a signature for calculating averages
    average_sig = Dspy.Signature.new(
      "AverageCalculator",
      input_fields: [
        %{name: :scores, type: :string, description: "Three test scores separated by commas", required: true, default: nil}
      ],
      output_fields: [
        %{name: :average, type: :float, description: "The calculated average", required: true, default: nil}
      ],
      instructions: """
      Calculate the average of the given test scores.
      Show your work clearly.
      """
    )
    
    # Create self-consistency module
    sc_module = Dspy.SelfConsistency.new(
      average_sig,
      num_samples: 5,
      temperature: 0.7
    )
    
    # Run the module
    inputs = %{scores: "85, 92, 78"}
    
    case Dspy.Module.forward(sc_module, inputs) do
      {:ok, prediction} ->
        IO.puts("Input scores: #{inputs.scores}")
        IO.puts("Reasoning: #{prediction.reasoning}")
        IO.puts("Average (most consistent): #{prediction.average}")
        IO.puts("✓ Self-consistency successfully found the most reliable answer")
        
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Multi-Step Example ===========
  def multi_step_example do
    IO.puts("\n\n2️⃣ Multi-Step Example")
    IO.puts("-" <> String.duplicate("-", 40))
    IO.puts("Problem: Calculate compound interest")
    
    # Define signatures for each step
    step1_sig = Dspy.Signature.new(
      "Step1ExtractValues",
      input_fields: [
        %{name: :problem, type: :string, description: "The compound interest problem", required: true, default: nil}
      ],
      output_fields: [
        %{name: :principal, type: :float, description: "Initial amount", required: true, default: nil},
        %{name: :rate, type: :float, description: "Interest rate as decimal", required: true, default: nil},
        %{name: :time, type: :integer, description: "Time in years", required: true, default: nil}
      ],
      instructions: "Extract the values from the problem statement"
    )
    
    step2_sig = Dspy.Signature.new(
      "Step2CalculateInterest",
      input_fields: [
        %{name: :principal, type: :float, description: "Principal amount", required: true, default: nil},
        %{name: :rate, type: :float, description: "Interest rate", required: true, default: nil},
        %{name: :time, type: :integer, description: "Time period", required: true, default: nil}
      ],
      output_fields: [
        %{name: :compound_interest, type: :float, description: "The calculated compound interest", required: true, default: nil},
        %{name: :total_amount, type: :float, description: "Principal + interest", required: true, default: nil}
      ],
      instructions: "Calculate compound interest using A = P(1 + r)^t"
    )
    
    # Define the steps
    steps = [
      %{
        name: :extract,
        signature: step1_sig,
        description: "Extract values from problem",
        depends_on: []
      },
      %{
        name: :calculate,
        signature: step2_sig,
        description: "Calculate compound interest",
        depends_on: [:principal, :rate, :time]
      }
    ]
    
    # Create multi-step module
    ms_module = Dspy.MultiStep.new(steps)
    
    # Run the module
    inputs = %{
      problem: "Calculate compound interest on $1000 at 5% annual rate for 3 years"
    }
    
    case Dspy.Module.forward(ms_module, inputs) do
      {:ok, prediction} ->
        IO.puts("Problem: #{inputs.problem}")
        IO.puts("Step 1 - Extracted: P=$#{prediction.principal}, r=#{prediction.rate}, t=#{prediction.time}")
        IO.puts("Step 2 - Calculated: Interest=$#{prediction.compound_interest}")
        IO.puts("Total amount: $#{prediction.total_amount}")
        IO.puts("✓ Multi-step reasoning successfully broke down the problem")
        
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Reflection Example ===========
  def reflection_example do
    IO.puts("\n\n3️⃣ Reflection Example")
    IO.puts("-" <> String.duplicate("-", 40))
    IO.puts("Problem: Solve a word problem with potential pitfalls")
    
    word_problem_sig = Dspy.Signature.new(
      "WordProblemSolver",
      input_fields: [
        %{name: :problem, type: :string, description: "A word problem to solve", required: true, default: nil}
      ],
      output_fields: [
        %{name: :answer, type: :string, description: "The solution to the problem", required: true, default: nil}
      ],
      instructions: """
      Solve the word problem step by step.
      Be careful about units and assumptions.
      """
    )
    
    # Create reflection module
    ref_module = Dspy.Reflection.new(
      word_problem_sig,
      max_reflections: 2
    )
    
    # Run the module
    inputs = %{
      problem: "A train travels 60 km in 45 minutes. What is its speed in km/h?"
    }
    
    case Dspy.Module.forward(ref_module, inputs) do
      {:ok, prediction} ->
        IO.puts("Problem: #{inputs.problem}")
        IO.puts("Initial reasoning: #{prediction.reasoning}")
        IO.puts("Reflection: #{Map.get(prediction, :reflection, "Confirmed correct")}")
        IO.puts("Final answer: #{prediction.answer}")
        IO.puts("✓ Reflection helped verify and improve the answer")
        
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Program of Thoughts Example ===========
  def program_of_thoughts_example do
    IO.puts("\n\n4️⃣ Program of Thoughts Example")
    IO.puts("-" <> String.duplicate("-", 40))
    IO.puts("Problem: Calculate factorial using code generation")
    
    factorial_sig = Dspy.Signature.new(
      "FactorialCalculator",
      input_fields: [
        %{name: :number, type: :integer, description: "Number to calculate factorial for", required: true, default: nil}
      ],
      output_fields: [
        %{name: :result, type: :integer, description: "The factorial result", required: true, default: nil}
      ],
      instructions: "Calculate the factorial of the given number"
    )
    
    # Create PoT module
    pot_module = Dspy.ProgramOfThoughts.new(
      factorial_sig,
      language: :elixir,
      executor: :elixir
    )
    
    # Run the module
    inputs = %{number: 6}
    
    case Dspy.Module.forward(pot_module, inputs) do
      {:ok, prediction} ->
        IO.puts("Calculate: #{inputs.number}!")
        IO.puts("\nReasoning: #{prediction.reasoning}")
        IO.puts("\nGenerated code:")
        IO.puts(prediction.code)
        IO.puts("\nExecution result: #{prediction.execution_result}")
        IO.puts("Final answer: #{prediction.result}")
        IO.puts("✓ Program of Thoughts generated and executed code successfully")
        
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Self-Correcting CoT Example ===========
  def self_correcting_cot_example do
    IO.puts("\n\n5️⃣ Self-Correcting Chain of Thought Example")
    IO.puts("-" <> String.duplicate("-", 40))
    IO.puts("Problem: Logic puzzle requiring careful reasoning")
    
    logic_puzzle_sig = Dspy.Signature.new(
      "LogicPuzzleSolver",
      input_fields: [
        %{name: :puzzle, type: :string, description: "A logic puzzle to solve", required: true, default: nil}
      ],
      output_fields: [
        %{name: :solution, type: :string, description: "The solution to the puzzle", required: true, default: nil}
      ],
      instructions: """
      Solve the logic puzzle step by step.
      Check your reasoning carefully.
      """
    )
    
    # Create self-correcting CoT module
    sccot_module = Dspy.SelfCorrectingCoT.new(
      logic_puzzle_sig,
      max_corrections: 2,
      correction_threshold: 0.8
    )
    
    # Run the module
    inputs = %{
      puzzle: "If all roses are flowers, and some flowers fade quickly, can we conclude that some roses fade quickly?"
    }
    
    case Dspy.Module.forward(sccot_module, inputs) do
      {:ok, prediction} ->
        IO.puts("Puzzle: #{inputs.puzzle}")
        IO.puts("\nReasoning: #{prediction.reasoning}")
        IO.puts("Confidence: #{prediction.confidence}")
        IO.puts("Solution: #{prediction.solution}")
        IO.puts("✓ Self-correcting CoT checked its own reasoning")
        
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Tree of Thoughts Example ===========
  def tree_of_thoughts_example do
    IO.puts("\n\n6️⃣ Tree of Thoughts Example")
    IO.puts("-" <> String.duplicate("-", 40))
    IO.puts("Problem: Creative problem solving with multiple approaches")
    
    creative_problem_sig = Dspy.Signature.new(
      "CreativeProblemSolver",
      input_fields: [
        %{name: :challenge, type: :string, description: "A creative challenge to solve", required: true, default: nil}
      ],
      output_fields: [
        %{name: :solution, type: :string, description: "The most creative solution", required: true, default: nil}
      ],
      instructions: """
      Think of creative solutions to this challenge.
      Consider multiple different approaches.
      """
    )
    
    # Create ToT module
    tot_module = Dspy.TreeOfThoughts.new(
      creative_problem_sig,
      num_thoughts: 3,
      max_depth: 2,
      evaluation_strategy: :value_based
    )
    
    # Run the module
    inputs = %{
      challenge: "How can we reduce plastic waste in oceans?"
    }
    
    case Dspy.Module.forward(tot_module, inputs) do
      {:ok, prediction} ->
        IO.puts("Challenge: #{inputs.challenge}")
        IO.puts("\nThought exploration: #{Map.get(prediction, :thought, "Multiple paths explored")}")
        IO.puts("Best reasoning path: #{prediction.reasoning}")
        IO.puts("Solution: #{prediction.solution}")
        IO.puts("✓ Tree of Thoughts explored multiple solution paths")
        
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end
end

# Run all examples
ReasoningMethodsShowcase.run()