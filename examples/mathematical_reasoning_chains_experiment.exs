# Remove Mix.install as we're inside a Mix project

defmodule MathematicalReasoningChainsExperiment do
  @moduledoc """
  Experiment demonstrating complex mathematical reasoning with step-by-step chains.
  Tests symbolic manipulation, proof construction, and mathematical intuition.
  """

  alias Dspy.{Module, ChainOfThought, Signature, Settings, LM}

  defmodule MathProblemSolving do
    use Dspy.Signature

    field :problem, :input,
      desc: "Mathematical problem statement"

    field :domain, :input,
      desc: "Mathematical domain (algebra, calculus, etc.)"

    field :approach, :output,
      desc: "Strategy for solving the problem"

    field :steps, :output,
      desc: "Step-by-step solution with justification"

    field :answer, :output,
      desc: "Final answer in appropriate form"

    field :verification, :output,
      desc: "How to verify the answer is correct"
  end

  defmodule ProofConstruction do
    use Dspy.Signature

    field :theorem, :input,
      desc: "Statement to prove"

    field :given, :input,
      desc: "Given information or axioms"

    field :proof_strategy, :output,
      desc: "Overall proof approach (direct, contradiction, induction, etc.)"

    field :proof, :output,
      desc: "Formal proof with clear logical steps"

    field :key_insight, :output,
      desc: "The crucial insight that makes the proof work"
  end

  defmodule PatternRecognition do
    use Dspy.Signature

    field :sequence, :input,
      desc: "Mathematical sequence or pattern"

    field :observations, :output,
      desc: "Patterns noticed in the data"

    field :formula, :output,
      desc: "General formula or rule"

    field :proof_of_formula, :output,
      desc: "Why the formula works"

    field :predictions, :output,
      desc: "Next terms or values predicted"
  end

  defmodule MathematicalModeling do
    use Dspy.Signature

    field :scenario, :input,
      desc: "Real-world scenario to model"

    field :constraints, :input,
      desc: "Known constraints or limitations"

    field :variables, :output,
      desc: "Key variables and their meanings"

    field :equations, :output,
      desc: "Mathematical equations modeling the scenario"

    field :solution_method, :output,
      desc: "How to solve the system"

    field :interpretation, :output,
      desc: "What the solution means in context"
  end

  def run_experiment do
    IO.puts("\n🔢 Mathematical Reasoning Chains Experiment")
    IO.puts("=" <> String.duplicate("=", 50))

    # Configure GPT-4 for mathematical reasoning
    configure_math_mode()

    # Test different types of mathematical reasoning
    
    # 1. Complex problem solving
    IO.puts("\n📐 Part 1: Multi-Step Problem Solving")
    problem_solving_tests()

    # 2. Proof construction
    IO.puts("\n📜 Part 2: Proof Construction")
    proof_construction_tests()

    # 3. Pattern recognition
    IO.puts("\n🔍 Part 3: Pattern Recognition")
    pattern_recognition_tests()

    # 4. Mathematical modeling
    IO.puts("\n🏗️  Part 4: Mathematical Modeling")
    mathematical_modeling_tests()

    # 5. Combined challenge
    IO.puts("\n🎯 Part 5: Combined Mathematical Challenge")
    combined_challenge()

    IO.puts("\n✅ Mathematical reasoning experiment complete!")
  end

  defp configure_math_mode do
    lm = Dspy.LM.OpenAI.new([
      model: "gpt-4.1",
      temperature: 0.2,  # Low temperature for precision
      max_tokens: 2000,
      timeout: 180_000   # 3 minutes for complex mathematical reasoning
    ])
    
    Settings.configure(%{lm: lm})
  end

  defp problem_solving_tests do
    problems = [
      %{
        problem: """
        Find all real solutions to the equation:
        x^4 - 5x^3 + 5x^2 + 5x - 6 = 0
        """,
        domain: "Algebra"
      },
      %{
        problem: """
        Evaluate the integral:
        ∫ (x * ln(x)) / (1 + x^2)^2 dx
        """,
        domain: "Calculus"
      },
      %{
        problem: """
        A sequence is defined by a₁ = 1, a₂ = 1, and 
        aₙ = aₙ₋₁ + aₙ₋₂ + n for n ≥ 3.
        Find a closed form expression for aₙ.
        """,
        domain: "Sequences and Series"
      }
    ]

    solver = ChainOfThought.new(MathProblemSolving)

    Enum.each(problems, fn prob ->
      IO.puts("\n" <> String.duplicate("-", 40))
      IO.puts("Problem: #{prob.problem}")
      
      case Module.forward(solver, prob) do
        {:ok, prediction} ->
          IO.puts("\n🎯 Approach: #{prediction.attrs.approach}")
          IO.puts("\n📝 Solution Steps:")
          IO.puts(prediction.attrs.steps)
          IO.puts("\n✅ Answer: #{prediction.attrs.answer}")
          IO.puts("\n🔍 Verification:")
          IO.puts(prediction.attrs.verification)
          
        {:error, error} ->
          IO.puts("❌ Solution failed: #{inspect(error)}")
      end
    end)
  end

  defp proof_construction_tests do
    theorems = [
      %{
        theorem: "For any prime p > 2, p² - 1 is divisible by 24",
        given: "p is a prime number greater than 2"
      },
      %{
        theorem: "The sum of the angles in any triangle is 180 degrees",
        given: "Euclidean geometry axioms"
      },
      %{
        theorem: "√2 is irrational",
        given: "Properties of integers and rational numbers"
      }
    ]

    prover = ChainOfThought.new(ProofConstruction)

    Enum.each(theorems, fn thm ->
      IO.puts("\n" <> String.duplicate("-", 40))
      IO.puts("Theorem: #{thm.theorem}")
      
      case Module.forward(prover, thm) do
        {:ok, prediction} ->
          IO.puts("\n📋 Proof Strategy: #{prediction.attrs.proof_strategy}")
          IO.puts("\n📝 Proof:")
          IO.puts(prediction.attrs.proof)
          IO.puts("\n💡 Key Insight: #{prediction.attrs.key_insight}")
          
        {:error, error} ->
          IO.puts("❌ Proof failed: #{inspect(error)}")
      end
    end)
  end

  defp pattern_recognition_tests do
    patterns = [
      %{
        sequence: "1, 1, 2, 3, 5, 8, 13, 21, ..."
      },
      %{
        sequence: "2, 6, 12, 20, 30, 42, 56, 72, ..."
      },
      %{
        sequence: "1, 11, 121, 1331, 14641, ..."
      }
    ]

    recognizer = ChainOfThought.new(PatternRecognition)

    Enum.each(patterns, fn pattern ->
      IO.puts("\n" <> String.duplicate("-", 40))
      IO.puts("Sequence: #{pattern.sequence}")
      
      case Module.forward(recognizer, pattern) do
        {:ok, prediction} ->
          IO.puts("\n👁️  Observations:")
          IO.puts(prediction.attrs.observations)
          IO.puts("\n📐 Formula: #{prediction.attrs.formula}")
          IO.puts("\n📝 Proof:")
          IO.puts(prediction.attrs.proof_of_formula)
          IO.puts("\n🔮 Predictions: #{prediction.attrs.predictions}")
          
        {:error, error} ->
          IO.puts("❌ Pattern recognition failed: #{inspect(error)}")
      end
    end)
  end

  defp mathematical_modeling_tests do
    scenarios = [
      %{
        scenario: """
        A water tank is being filled by one pipe and emptied by another.
        The filling pipe adds 50 liters per minute. The emptying rate
        depends on the water level: it empties at 0.1 * h liters per minute,
        where h is the height of water in cm. The tank has a circular base
        with radius 1 meter.
        """,
        constraints: "Tank height is 2 meters maximum"
      },
      %{
        scenario: """
        A population of rabbits grows exponentially but is limited by
        available food. The growth rate decreases as the population
        approaches the carrying capacity of 10,000 rabbits. Foxes
        hunt the rabbits at a rate proportional to both populations.
        """,
        constraints: "Initial populations: 100 rabbits, 10 foxes"
      }
    ]

    modeler = ChainOfThought.new(MathematicalModeling)

    Enum.each(scenarios, fn scenario ->
      IO.puts("\n" <> String.duplicate("-", 40))
      IO.puts("Scenario: #{String.slice(scenario.scenario, 0..100)}...")
      
      case Module.forward(modeler, scenario) do
        {:ok, prediction} ->
          IO.puts("\n📊 Variables:")
          IO.puts(prediction.attrs.variables)
          IO.puts("\n📐 Equations:")
          IO.puts(prediction.attrs.equations)
          IO.puts("\n🔧 Solution Method:")
          IO.puts(prediction.attrs.solution_method)
          IO.puts("\n💭 Interpretation:")
          IO.puts(prediction.attrs.interpretation)
          
        {:error, error} ->
          IO.puts("❌ Modeling failed: #{inspect(error)}")
      end
    end)
  end

  defp combined_challenge do
    challenge_signature = Signature.define("""
    solve_olympiad_problem(problem: str) -> 
      understanding: str,
      key_observations: str,
      solution_path: str,
      complete_solution: str,
      elegance_rating: str
    """)

    olympiad_solver = ChainOfThought.new(challenge_signature, [
      reasoning: """
      This is an Olympiad-style problem requiring:
      1. Deep understanding of the problem
      2. Creative insights
      3. Rigorous mathematical reasoning
      4. Elegant solution if possible
      """
    ])

    problem = """
    Let f(x) be a polynomial with integer coefficients such that
    f(0) = 0, f(1) = 1, and f(n) divides f(n²) for all integers n.
    Prove that f(x) = x for all x.
    """

    IO.puts("\n🏆 Olympiad Challenge:")
    IO.puts(problem)

    case Module.forward(olympiad_solver, %{problem: problem}) do
      {:ok, prediction} ->
        IO.puts("\n🧠 Understanding:")
        IO.puts(prediction.attrs.understanding)
        IO.puts("\n🔍 Key Observations:")
        IO.puts(prediction.attrs.key_observations)
        IO.puts("\n🛤️  Solution Path:")
        IO.puts(prediction.attrs.solution_path)
        IO.puts("\n📝 Complete Solution:")
        IO.puts(prediction.attrs.complete_solution)
        IO.puts("\n✨ Elegance Rating: #{prediction.attrs.elegance_rating}")
        
      {:error, error} ->
        IO.puts("❌ Olympiad challenge failed: #{inspect(error)}")
    end
  end
end

# Run the experiment
MathematicalReasoningChainsExperiment.run_experiment()