defmodule ReasoningWithDynamicProblems do
  @moduledoc """
  Example of using DSPy reasoning methods with dynamically generated problems
  """

  def run do
    IO.puts("\n🎲 DSPy with Dynamic Problem Generation")
    IO.puts("=" <> String.duplicate("=", 50))
    
    # Start DSPy application
    {:ok, _} = Application.ensure_all_started(:dspy)
    
    # Configure GPT-4.1 as the language model
    configure_gpt41()
    
    # Run examples with dynamic problems
    self_consistency_example()
    multi_step_example()
    reflection_example()
    program_of_thoughts_example()
  end

  defp configure_gpt41 do
    # Check for API key
    api_key = System.get_env("OPENAI_API_KEY")
    
    if api_key do
      # Create GPT-4.1 client
      gpt41_client = Dspy.LM.OpenAI.new(
        api_key: api_key,
        model: "gpt-4.1",
        timeout: 180_000
      )
      
      # Set as default LM in settings
      Dspy.Settings.configure(lm: gpt41_client)
      
      IO.puts("✓ Configured GPT-4.1 as language model")
      IO.puts("")
    else
      IO.puts("❌ Error: OPENAI_API_KEY environment variable not set")
      IO.puts("Please set your OpenAI API key:")
      IO.puts("  export OPENAI_API_KEY='your-api-key-here'")
      System.halt(1)
    end
  end

  # =========== Self-Consistency Example ===========
  def self_consistency_example do
    IO.puts("\n1️⃣ Self-Consistency with Dynamic Math Problem")
    IO.puts("-" <> String.duplicate("-", 40))
    
    # Create a math problem signature
    math_sig = Dspy.Signature.new(
      "MathProblemSolver",
      input_fields: [
        %{name: :problem, type: :string, description: "A math word problem", required: true, default: nil}
      ],
      output_fields: [
        %{name: :answer, type: :float, description: "The numerical answer", required: true, default: nil}
      ],
      instructions: "Solve the math problem step by step."
    )
    
    # Create self-consistency module
    sc_module = Dspy.SelfConsistency.new(
      math_sig,
      num_samples: 5,
      temperature: 0.7
    )
    
    # Generate a random math problem
    problem = Dspy.ProblemGenerator.generate_math_problem()
    inputs = %{problem: problem}
    
    IO.puts("Problem: #{inputs.problem}")
    
    case Dspy.Module.forward(sc_module, inputs) do
      {:ok, prediction} ->
        IO.puts("Reasoning: #{String.slice(Dspy.Prediction.get(prediction, :reasoning, "Direct calculation"), 0, 100)}...")
        IO.puts("Answer: $#{Dspy.Prediction.get(prediction, :answer)}")
        IO.puts("✓ GPT-4.1 found consistent answer across multiple attempts")
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Multi-Step Example ===========
  def multi_step_example do
    IO.puts("\n\n2️⃣ Multi-Step Reasoning with Dynamic Coding Task")
    IO.puts("-" <> String.duplicate("-", 40))
    
    # Step 1: Analyze requirements
    analyze_sig = Dspy.Signature.new(
      "RequirementsAnalyzer",
      input_fields: [
        %{name: :request, type: :string, description: "User's request", required: true, default: nil}
      ],
      output_fields: [
        %{name: :task_type, type: :string, description: "Type of task", required: true, default: nil},
        %{name: :requirements, type: :string, description: "List of requirements", required: true, default: nil}
      ]
    )
    
    # Step 2: Generate solution
    solution_sig = Dspy.Signature.new(
      "SolutionGenerator",
      input_fields: [
        %{name: :task_type, type: :string, description: "Type of task", required: true, default: nil},
        %{name: :requirements, type: :string, description: "Requirements", required: true, default: nil}
      ],
      output_fields: [
        %{name: :solution, type: :string, description: "Proposed solution", required: true, default: nil}
      ]
    )
    
    steps = [
      %{
        name: :analyze,
        signature: analyze_sig,
        description: "Analyze the request",
        depends_on: []
      },
      %{
        name: :solve,
        signature: solution_sig,
        description: "Generate solution",
        depends_on: [:task_type, :requirements]
      }
    ]
    
    ms_module = Dspy.MultiStep.new(steps)
    
    # Generate a random coding task
    task = Dspy.ProblemGenerator.generate_coding_task()
    inputs = %{request: task}
    
    IO.puts("Request: #{inputs.request}")
    
    case Dspy.Module.forward(ms_module, inputs) do
      {:ok, prediction} ->
        IO.puts("\nStep 1 - Analysis:")
        IO.puts("  Task type: #{Dspy.Prediction.get(prediction, :task_type)}")
        IO.puts("  Requirements: #{String.slice(Dspy.Prediction.get(prediction, :requirements, ""), 0, 80)}...")
        IO.puts("\nStep 2 - Solution:")
        IO.puts("  #{String.slice(Dspy.Prediction.get(prediction, :solution, ""), 0, 150)}...")
        IO.puts("\n✓ GPT-4.1 successfully completed multi-step reasoning")
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Reflection Example ===========
  def reflection_example do
    IO.puts("\n\n3️⃣ Reflection with Dynamic Logic Problem")
    IO.puts("-" <> String.duplicate("-", 40))
    
    logic_sig = Dspy.Signature.new(
      "LogicalReasoner",
      input_fields: [
        %{name: :statement, type: :string, description: "A logical statement to analyze", required: true, default: nil}
      ],
      output_fields: [
        %{name: :analysis, type: :string, description: "Logical analysis", required: true, default: nil},
        %{name: :conclusion, type: :string, description: "Final conclusion", required: true, default: nil}
      ]
    )
    
    ref_module = Dspy.Reflection.new(
      logic_sig,
      max_reflections: 2,
      reflection_prompt: "Double-check your logical reasoning for any fallacies or errors."
    )
    
    # Generate a random logic problem
    statement = Dspy.ProblemGenerator.generate_logic_problem()
    inputs = %{statement: statement}
    
    IO.puts("Statement: #{inputs.statement}")
    
    case Dspy.Module.forward(ref_module, inputs) do
      {:ok, prediction} ->
        IO.puts("\nInitial reasoning: #{String.slice(Dspy.Prediction.get(prediction, :reasoning, "Analyzing..."), 0, 100)}...")
        IO.puts("Analysis: #{String.slice(Dspy.Prediction.get(prediction, :analysis, ""), 0, 100)}...")
        IO.puts("Conclusion: #{Dspy.Prediction.get(prediction, :conclusion)}")
        IO.puts("\n✓ GPT-4.1 reflected and refined its reasoning")
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # =========== Program of Thoughts Example ===========
  def program_of_thoughts_example do
    IO.puts("\n\n4️⃣ Program of Thoughts with Dynamic Algorithm Task")
    IO.puts("-" <> String.duplicate("-", 40))
    
    algorithm_sig = Dspy.Signature.new(
      "AlgorithmDesigner",
      input_fields: [
        %{name: :task, type: :string, description: "Algorithm task", required: true, default: nil}
      ],
      output_fields: [
        %{name: :result, type: :string, description: "Algorithm result", required: true, default: nil}
      ]
    )
    
    pot_module = Dspy.ProgramOfThoughts.new(
      algorithm_sig,
      language: :elixir,
      executor: :elixir
    )
    
    # Generate a random algorithm task
    task = Dspy.ProblemGenerator.generate_algorithm_task()
    inputs = %{task: task}
    
    IO.puts("Task: #{inputs.task}")
    
    case Dspy.Module.forward(pot_module, inputs) do
      {:ok, prediction} ->
        IO.puts("\nReasoning: #{String.slice(Dspy.Prediction.get(prediction, :reasoning, ""), 0, 100)}...")
        IO.puts("\nGenerated Code:")
        IO.puts(String.slice(Dspy.Prediction.get(prediction, :code, "# No code generated"), 0, 200))
        IO.puts("\nExecution Result: #{Dspy.Prediction.get(prediction, :execution_result, "N/A")}")
        IO.puts("Final Answer: #{Dspy.Prediction.get(prediction, :result)}")
        IO.puts("\n✓ GPT-4.1 generated and executed code successfully")
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end
end

# Check if running as script
if System.get_env("MIX_ENV") != "test" do
  ReasoningWithDynamicProblems.run()
end