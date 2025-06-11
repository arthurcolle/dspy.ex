# Mix.install([
#   {:dspy, path: "."}
# ])

defmodule CreativeProblemSolvingExperiment do
  @moduledoc """
  Experiment exploring creative and unconventional problem-solving approaches.
  Tests the ability to generate novel solutions and think outside the box.
  """

  alias Dspy.{Module, ChainOfThought, Predict, Signature, Settings, LM}

  defmodule CreativeChallenge do
    use Dspy.Signature

    field :problem, :input,
      desc: "A problem requiring creative thinking"

    field :constraints, :input,
      desc: "Any constraints or limitations"

    field :brainstorm, :output,
      desc: "Wild, unconventional ideas (at least 5)"

    field :feasibility_analysis, :output,
      desc: "Which ideas could actually work and why"

    field :creative_solution, :output,
      desc: "Most creative yet practical solution"

    field :innovation_score, :output,
      desc: "Self-rated creativity score (1-10) with justification"
  end

  defmodule MetaphoricalThinking do
    use Dspy.Signature

    field :problem, :input,
      desc: "The problem to solve"

    field :domain, :input,
      desc: "A completely different domain to draw inspiration from"

    field :metaphor, :output,
      desc: "How the problem is like something in the other domain"

    field :insights, :output,
      desc: "Insights gained from the metaphor"

    field :solution, :output,
      desc: "Solution inspired by the metaphorical thinking"
  end

  defmodule ReverseEngineering do
    use Dspy.Signature

    field :desired_outcome, :input,
      desc: "What we want to achieve"

    field :current_state, :input,
      desc: "Where we are now"

    field :backwards_steps, :output,
      desc: "Working backwards from outcome to current state"

    field :forward_plan, :output,
      desc: "The plan rebuilt going forward"

    field :unexpected_paths, :output,
      desc: "Surprising connections discovered"
  end

  def run_experiment do
    IO.puts("\n🎨 Creative Problem Solving Experiment")
    IO.puts("=" <> String.duplicate("=", 50))

    # Configure GPT-4 with higher temperature for creativity
    configure_creative_mode()

    # Creative challenges
    challenges = [
      %{
        problem: """
        A small island nation wants to become carbon negative within 5 years
        but has limited land area and relies heavily on tourism.
        """,
        constraints: "Cannot harm tourism industry, limited space, limited budget"
      },
      %{
        problem: """
        Design a way to teach quantum physics concepts to 8-year-old children
        that makes the subject intuitive and fun.
        """,
        constraints: "No complex math, must be hands-on, under 30 minutes"
      },
      %{
        problem: """
        Create a system where procrastination actually helps productivity
        rather than hinders it.
        """,
        constraints: "Must work for different personality types, no external rewards"
      },
      %{
        problem: """
        Solve urban loneliness without using technology or organized events.
        """,
        constraints: "Passive system, works for introverts, zero maintenance"
      }
    ]

    # Inspiration domains for metaphorical thinking
    domains = ["ant colonies", "jazz improvisation", "immune systems", "cooking", "gardening"]

    Enum.each(challenges, fn challenge ->
      IO.puts("\n" <> String.duplicate("=", 50))
      IO.puts("🎯 Challenge: #{String.slice(challenge.problem, 0..100)}...")
      IO.puts("🚧 Constraints: #{challenge.constraints}")

      # Method 1: Direct creative brainstorming
      IO.puts("\n📝 Method 1: Creative Brainstorming")
      brainstorm_solutions(challenge)

      # Method 2: Metaphorical thinking
      domain = Enum.random(domains)
      IO.puts("\n🌟 Method 2: Metaphorical Thinking (using #{domain})")
      metaphorical_approach(challenge, domain)

      # Method 3: Reverse engineering
      IO.puts("\n⏮️  Method 3: Reverse Engineering")
      reverse_engineer_solution(challenge)

      # Combine approaches
      IO.puts("\n🔀 Synthesizing approaches...")
      synthesize_creative_solution(challenge)
    end)

    # Bonus: Generate a completely novel problem
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("🆕 Bonus: Generating a novel problem to solve...")
    generate_novel_problem()

    IO.puts("\n✅ Creative problem solving experiment complete!")
  end

  defp configure_creative_mode do
    lm = LM.OpenAI.new([
      model: "gpt-4.1",
      temperature: 0.9,  # Higher temperature for creativity
      max_tokens: 1500
    ])
    
    Settings.configure(%{lm: lm})
  end

  defp brainstorm_solutions(challenge) do
    cot = ChainOfThought.new(CreativeChallenge)

    case ChainOfThought.forward(cot, %{
      problem: challenge.problem,
      constraints: challenge.constraints
    }) do
      {:ok, result} ->
        IO.puts("\n💡 Brainstormed Ideas:")
        IO.puts(result[:brainstorm])
        IO.puts("\n✅ Most Creative Solution:")
        IO.puts(result[:creative_solution])
        IO.puts("\n🎨 Innovation Score: #{result[:innovation_score]}")
        
      {:error, error} ->
        IO.puts("❌ Brainstorming failed: #{inspect(error)}")
    end
  end

  defp metaphorical_approach(challenge, domain) do
    cot = ChainOfThought.new(MetaphoricalThinking)

    case ChainOfThought.forward(cot, %{
      problem: challenge.problem,
      domain: domain
    }) do
      {:ok, result} ->
        IO.puts("\n🔄 Metaphor: #{result[:metaphor]}")
        IO.puts("\n💡 Insights: #{result[:insights]}")
        IO.puts("\n🎯 Metaphor-inspired Solution:")
        IO.puts(result[:solution])
        
      {:error, error} ->
        IO.puts("❌ Metaphorical thinking failed: #{inspect(error)}")
    end
  end

  defp reverse_engineer_solution(challenge) do
    # Extract desired outcome from problem
    desired_outcome = "A perfect solution to: #{challenge.problem}"
    current_state = "Current situation with constraints: #{challenge.constraints}"

    cot = ChainOfThought.new(ReverseEngineering)

    case ChainOfThought.forward(cot, %{
      desired_outcome: desired_outcome,
      current_state: current_state
    }) do
      {:ok, result} ->
        IO.puts("\n⏪ Backward Steps:")
        IO.puts(result[:backwards_steps])
        IO.puts("\n⏩ Forward Plan:")
        IO.puts(result[:forward_plan])
        IO.puts("\n🌟 Unexpected Discoveries:")
        IO.puts(result[:unexpected_paths])
        
      {:error, error} ->
        IO.puts("❌ Reverse engineering failed: #{inspect(error)}")
    end
  end

  defp synthesize_creative_solution(challenge) do
    synthesis_signature = Signature.define("synthesize_solution(problem: str, constraints: str) -> reasoning: str, integrated_solution: str, key_innovations: str, implementation_steps: str")

    cot = ChainOfThought.new(synthesis_signature)

    case ChainOfThought.forward(cot, %{
      problem: challenge.problem,
      constraints: challenge.constraints
    }) do
      {:ok, result} ->
        IO.puts("\n🔀 Synthesizing approaches...")
        IO.puts(result[:reasoning])
        IO.puts("\n🎯 Integrated Creative Solution:")
        IO.puts(result[:integrated_solution])
        IO.puts("\n⭐ Key Innovations:")
        IO.puts(result[:key_innovations])
        IO.puts("\n📋 Implementation Steps:")
        IO.puts(result[:implementation_steps])
        
      {:error, error} ->
        IO.puts("❌ Synthesis failed: #{inspect(error)}")
    end
  end

  defp generate_novel_problem do
    novel_problem_signature = Signature.define("generate_novel_problem() -> problem_statement: str, why_novel: str, potential_impact: str, creative_constraints: str")

    cot = ChainOfThought.new(novel_problem_signature)

    case ChainOfThought.forward(cot, %{}) do
      {:ok, result} ->
        IO.puts("\n🆕 Novel Problem:")
        IO.puts(result[:problem_statement])
        IO.puts("\n❓ Why It's Novel:")
        IO.puts(result[:why_novel])
        IO.puts("\n💥 Potential Impact:")
        IO.puts(result[:potential_impact])
        IO.puts("\n🎨 Creative Constraints:")
        IO.puts(result[:creative_constraints])
        
      {:error, error} ->
        IO.puts("❌ Novel problem generation failed: #{inspect(error)}")
    end
  end
end

# Run the experiment
CreativeProblemSolvingExperiment.run_experiment()