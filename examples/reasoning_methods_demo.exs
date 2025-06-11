# Load dependencies
Mix.install([
  {:dspy, path: Path.expand("..", __DIR__)},
  {:jason, "~> 1.2"},
  {:gen_stage, "~> 1.2"}
])

# Start the application
Application.ensure_all_started(:dspy)

# Configure DSPy with OpenAI
Dspy.configure(lm: Dspy.LM.OpenAI.new(
  model: "gpt-4.1-mini",
  api_key: System.get_env("OPENAI_API_KEY")
))

defmodule ReasoningMethodsDemo do
  @moduledoc """
  Demonstration of DSPy reasoning methods with clear examples.
  
  This file shows how to use each reasoning method and what makes them unique.
  Note: Requires LM configuration to run actual examples.
  """

  def run do
    IO.puts("\n🧠 DSPy Reasoning Methods Demo")
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("Note: These examples show the structure. Configure an LM to run them.")
    
    demo_self_consistency()
    demo_multi_step()
    demo_reflection()
    demo_program_of_thoughts()
    demo_self_correcting_cot()
    demo_tree_of_thoughts()
  end

  # =========== 1. Self-Consistency ===========
  def demo_self_consistency do
    IO.puts("\n\n1️⃣ SELF-CONSISTENCY")
    IO.puts("-" <> String.duplicate("-", 50))
    IO.puts("Purpose: Generate multiple reasoning paths and select the most consistent answer")
    IO.puts("Best for: Math problems, factual questions where consistency matters\n")
    
    IO.puts("Example Problem: 'If a train travels 120 miles in 2 hours, what's its speed?'")
    IO.puts("\nHow it works:")
    IO.puts("1. Generates 5 different reasoning attempts:")
    IO.puts("   - Attempt 1: 120 miles ÷ 2 hours = 60 mph")
    IO.puts("   - Attempt 2: Distance/Time = 120/2 = 60 mph")
    IO.puts("   - Attempt 3: Speed = 120 miles / 2 hours = 60 mph")
    IO.puts("   - Attempt 4: v = d/t = 120/2 = 60 mph")
    IO.puts("   - Attempt 5: 120 miles in 2 hours means 60 miles per hour")
    IO.puts("2. All attempts agree on 60 mph → High confidence answer!")
    
    IO.puts("\nCode structure:")
    IO.puts("""
    # Define signature
    speed_calc = Dspy.Signature.new("SpeedCalculator",
      input_fields: [%{name: :problem, type: :string, ...}],
      output_fields: [%{name: :speed, type: :float, ...}]
    )
    
    # Create module with multiple samples
    sc_module = Dspy.SelfConsistency.new(speed_calc,
      num_samples: 5,        # Generate 5 attempts
      temperature: 0.7       # Some variation in reasoning
    )
    
    # Run and get most consistent answer
    {:ok, prediction} = Dspy.Module.forward(sc_module, inputs)
    """)
  end

  # =========== 2. Multi-Step ===========
  def demo_multi_step do
    IO.puts("\n\n2️⃣ MULTI-STEP")
    IO.puts("-" <> String.duplicate("-", 50))
    IO.puts("Purpose: Break complex problems into sequential steps")
    IO.puts("Best for: Problems requiring multiple stages of computation\n")
    
    IO.puts("Example Problem: 'Calculate total cost with tax and discount'")
    IO.puts("\nStep-by-step breakdown:")
    IO.puts("Step 1: Extract values → Item: $100, Tax: 8%, Discount: 20%")
    IO.puts("Step 2: Apply discount → $100 - 20% = $80")
    IO.puts("Step 3: Calculate tax → $80 × 8% = $6.40")
    IO.puts("Step 4: Final total → $80 + $6.40 = $86.40")
    
    IO.puts("\nCode structure:")
    IO.puts("""
    # Define steps with dependencies
    steps = [
      %{name: :extract, signature: extract_sig, depends_on: []},
      %{name: :discount, signature: discount_sig, depends_on: [:price, :discount_rate]},
      %{name: :tax, signature: tax_sig, depends_on: [:discounted_price, :tax_rate]},
      %{name: :total, signature: total_sig, depends_on: [:discounted_price, :tax_amount]}
    ]
    
    # Create multi-step module
    ms_module = Dspy.MultiStep.new(steps)
    
    # Each step automatically receives outputs from previous steps
    {:ok, prediction} = Dspy.Module.forward(ms_module, inputs)
    """)
  end

  # =========== 3. Reflection ===========
  def demo_reflection do
    IO.puts("\n\n3️⃣ REFLECTION")
    IO.puts("-" <> String.duplicate("-", 50))
    IO.puts("Purpose: Generate answer, then reflect and potentially revise")
    IO.puts("Best for: Complex reasoning where self-checking improves accuracy\n")
    
    IO.puts("Example Problem: 'Is it safe to swim if lightning was seen 5 seconds ago?'")
    IO.puts("\nReflection process:")
    IO.puts("Initial answer: 'Yes, lightning is 5 seconds away, that's far enough.'")
    IO.puts("\nReflection: 'Wait, let me reconsider...'")
    IO.puts("- Lightning travels at light speed (instantaneous)")
    IO.puts("- Thunder travels at ~1,100 ft/sec")
    IO.puts("- 5 seconds = ~1 mile away")
    IO.puts("- Lightning can strike 10+ miles from storm")
    IO.puts("\nRevised answer: 'No, absolutely not safe. Wait 30 minutes after last thunder.'")
    
    IO.puts("\nCode structure:")
    IO.puts("""
    # Create reflection module
    ref_module = Dspy.Reflection.new(safety_sig,
      max_reflections: 2,
      reflection_prompt: "Check safety guidelines and reconsider"
    )
    
    # Automatically reflects and improves answer
    {:ok, prediction} = Dspy.Module.forward(ref_module, inputs)
    """)
  end

  # =========== 4. Program of Thoughts ===========
  def demo_program_of_thoughts do
    IO.puts("\n\n4️⃣ PROGRAM OF THOUGHTS")
    IO.puts("-" <> String.duplicate("-", 50))
    IO.puts("Purpose: Combine natural language reasoning with executable code")
    IO.puts("Best for: Mathematical/algorithmic problems requiring computation\n")
    
    IO.puts("Example Problem: 'Find the 10th Fibonacci number'")
    IO.puts("\nProgram of Thoughts approach:")
    IO.puts("Reasoning: 'Fibonacci sequence starts with 0, 1. Each number is sum of previous two.'")
    IO.puts("\nGenerated code:")
    IO.puts("""
    def fibonacci(n) do
      case n do
        0 -> 0
        1 -> 1
        _ -> fibonacci(n-1) + fibonacci(n-2)
      end
    end
    
    fibonacci(10)
    """)
    IO.puts("Execution result: 55")
    
    IO.puts("\nCode structure:")
    IO.puts("""
    # Create PoT module
    pot_module = Dspy.ProgramOfThoughts.new(fib_sig,
      language: :elixir,
      executor: :elixir
    )
    
    # Generates reasoning + code + executes
    {:ok, prediction} = Dspy.Module.forward(pot_module, inputs)
    # prediction.reasoning = "Fibonacci explanation..."
    # prediction.code = "def fibonacci(n)..."
    # prediction.execution_result = "55"
    """)
  end

  # =========== 5. Self-Correcting Chain of Thought ===========
  def demo_self_correcting_cot do
    IO.puts("\n\n5️⃣ SELF-CORRECTING CHAIN OF THOUGHT")
    IO.puts("-" <> String.duplicate("-", 50))
    IO.puts("Purpose: Chain of thought reasoning with confidence scores and self-correction")
    IO.puts("Best for: Problems where initial reasoning might have errors\n")
    
    IO.puts("Example Problem: 'A bat and ball cost $1.10. Bat costs $1 more than ball. What's the ball cost?'")
    IO.puts("\nSelf-correcting process:")
    IO.puts("Initial reasoning: 'Bat costs $1 more, so bat = $1, ball = $0.10'")
    IO.puts("Confidence: 0.6 (below threshold)")
    IO.puts("\nSelf-correction triggered:")
    IO.puts("- Let ball = x")
    IO.puts("- Then bat = x + $1")
    IO.puts("- Total: x + (x + $1) = $1.10")
    IO.puts("- 2x + $1 = $1.10")
    IO.puts("- 2x = $0.10")
    IO.puts("- x = $0.05")
    IO.puts("\nCorrected answer: Ball = $0.05, Bat = $1.05")
    IO.puts("New confidence: 0.95")
    
    IO.puts("\nCode structure:")
    IO.puts("""
    # Create self-correcting CoT
    sccot_module = Dspy.SelfCorrectingCoT.new(math_sig,
      max_corrections: 2,
      correction_threshold: 0.8  # Correct if confidence < 0.8
    )
    
    # Automatically self-corrects low-confidence answers
    {:ok, prediction} = Dspy.Module.forward(sccot_module, inputs)
    """)
  end

  # =========== 6. Tree of Thoughts ===========
  def demo_tree_of_thoughts do
    IO.puts("\n\n6️⃣ TREE OF THOUGHTS")
    IO.puts("-" <> String.duplicate("-", 50))
    IO.puts("Purpose: Explore multiple reasoning paths in parallel, like a decision tree")
    IO.puts("Best for: Creative problem-solving, strategy games, open-ended challenges\n")
    
    IO.puts("Example Problem: 'Design a water conservation system for a school'")
    IO.puts("\nTree exploration:")
    IO.puts("Root: Water conservation system needed")
    IO.puts("├─ Branch 1: Reduce consumption")
    IO.puts("│  ├─ Low-flow fixtures")
    IO.puts("│  └─ Behavior change campaigns")
    IO.puts("├─ Branch 2: Reuse water")
    IO.puts("│  ├─ Greywater recycling")
    IO.puts("│  └─ Rainwater harvesting")
    IO.puts("└─ Branch 3: Smart monitoring")
    IO.puts("   ├─ Leak detection sensors")
    IO.puts("   └─ Usage analytics dashboard")
    IO.puts("\nBest path selected: Combination of rainwater harvesting + smart monitoring")
    
    IO.puts("\nCode structure:")
    IO.puts("""
    # Create Tree of Thoughts module
    tot_module = Dspy.TreeOfThoughts.new(design_sig,
      num_thoughts: 3,           # 3 branches at each level
      max_depth: 3,              # Explore 3 levels deep
      evaluation_strategy: :value_based
    )
    
    # Explores tree and selects best path
    {:ok, prediction} = Dspy.Module.forward(tot_module, inputs)
    """)
  end
end

# Run the demo
ReasoningMethodsDemo.run()