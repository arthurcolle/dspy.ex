# Progressive Challenges: Increasingly Difficult DSPy Examples
# This file demonstrates a progression from simple to extremely complex problems,
# showcasing the full power of DSPy's advanced reasoning capabilities.

IO.puts("=== DSPy Progressive Challenge Suite ===")
IO.puts("Building from basic to expert-level AI reasoning tasks\n")

# ==== LEVEL 1: BASIC REASONING ====

defmodule Level1.SimpleQA do
  use Dspy.Signature
  
  signature_description "Answer basic factual questions"
  
  input_field :question, :string, "Simple factual question"
  output_field :answer, :string, "Direct answer"
end

IO.puts("🟢 LEVEL 1: Basic Factual Reasoning")
IO.puts("Module: Dspy.Predict - Direct question answering")

test_cases_l1 = [
  "What is 15 + 27?",
  "What is the capital of Japan?", 
  "How many days are in February during a leap year?"
]

IO.puts("Example test cases:")
Enum.each(test_cases_l1, fn question ->
  IO.puts("  Q: #{question}")
end)

IO.puts("\nPattern: basic_predictor = Dspy.Predict.new(Level1.SimpleQA)")
IO.puts("Usage: Dspy.Module.forward(predictor, %{question: question})\n")

# ==== LEVEL 2: CHAIN OF THOUGHT ====

defmodule Level2.ReasoningQA do
  use Dspy.Signature
  
  signature_description "Solve problems with clear step-by-step reasoning"
  
  input_field :problem, :string, "Problem requiring reasoning"
  output_field :answer, :string, "Final answer"
end

IO.puts("🟡 LEVEL 2: Chain of Thought Reasoning")
IO.puts("Module: Dspy.ChainOfThought - Step-by-step reasoning")

test_cases_l2 = [
  "If a store sells 3 apples for $2, how much would 15 apples cost?",
  "Sarah is 3 times older than her brother Tom. In 5 years, she will be twice as old as Tom. How old are they now?",
  "A train leaves at 2:30 PM traveling at 60 mph. Another train leaves at 3:00 PM from the same station traveling at 80 mph in the same direction. When will the second train catch up?"
]

IO.puts("Example challenging problems:")
Enum.each(test_cases_l2, fn problem ->
  IO.puts("  Problem: #{String.slice(problem, 0, 50)}...")
end)

IO.puts("\nPattern: cot_predictor = Dspy.ChainOfThought.new(Level2.ReasoningQA)")
IO.puts("Benefit: Provides reasoning steps along with final answer\n")

# ==== LEVEL 3: SELF-CONSISTENCY ====

defmodule Level3.ComplexMath do
  use Dspy.Signature
  
  signature_description "Solve complex mathematical problems with high accuracy"
  
  input_field :problem, :string, "Complex mathematical problem"
  output_field :answer, :string, "Precise numerical answer"
end

IO.puts("🔵 LEVEL 3: Self-Consistency for Accuracy")
IO.puts("Module: Dspy.SelfConsistency - Multiple sampling for consistency")

test_cases_l3 = [
  "Find all real solutions to the equation: x^4 - 5x^2 + 6 = 0",
  "A geometric series has first term a = 3 and common ratio r = 1/2. Find the sum of the first 10 terms.",
  "Calculate the area under the curve y = x^2 - 4x + 3 from x = 0 to x = 4 using integration."
]

IO.puts("Example complex math problems:")
Enum.each(test_cases_l3, fn problem ->
  IO.puts("  #{String.slice(problem, 0, 60)}...")
end)

IO.puts("\nPattern: self_consistency = Dspy.SelfConsistency.new(Level3.ComplexMath, num_samples: 5)")
IO.puts("Benefit: Generates multiple solutions and picks most consistent\n")

# ==== LEVEL 4: MULTI-STEP REASONING ====

IO.puts("🟠 LEVEL 4: Multi-Step Business Analysis")
IO.puts("Module: Dspy.MultiStep - Sequential multi-step problem solving")

business_scenario = "TechCorp faces declining profits due to increased competition. They have $2M to invest and must choose between: expanding internationally, developing AI capabilities, acquiring a smaller competitor, or pivoting to a SaaS model. Current team: 150 employees, 60% engineers. Revenue: $15M annually, down 12% from last year."

IO.puts("Example business scenario:")
IO.puts("  #{String.slice(business_scenario, 0, 100)}...")

IO.puts("\nMulti-step process:")
IO.puts("  1. Analyze situation and key factors")
IO.puts("  2. Evaluate strategic options") 
IO.puts("  3. Make final recommendation with justification")

IO.puts("\nPattern: multi_step = Dspy.MultiStep.new(steps)")
IO.puts("Benefit: Breaks complex problems into manageable sequential steps\n")

# ==== LEVEL 5: ADAPTIVE BACKTRACKING ====

IO.puts("🔴 LEVEL 5: Adaptive Backtracking with Constraints")
IO.puts("Module: Dspy.AdaptiveBacktracking - Intelligent backtracking with memory")

ethical_dilemma = "An AI company has developed a facial recognition system that could help solve missing children cases and prevent terrorism, but it also enables mass surveillance and has shown bias against certain ethnic groups. The government wants to purchase it for national security, while privacy advocates and civil rights groups strongly oppose it. What should the company do?"

IO.puts("Example ethical dilemma:")
IO.puts("  #{String.slice(ethical_dilemma, 0, 100)}...")

IO.puts("\nConstraint functions:")
IO.puts("  - requires_multiple_perspectives/2")
IO.puts("  - avoids_oversimplification/2")

IO.puts("\nPattern: ethical_analyzer = Dspy.AdaptiveBacktracking.new(signature, constraints)")
IO.puts("Benefit: Ensures reasoning meets quality standards through backtracking\n")

# ==== LEVEL 6: PROGRAM OF THOUGHTS ====

IO.puts("⚫ LEVEL 6: Program of Thoughts for Scientific Analysis")
IO.puts("Module: Dspy.ProgramOfThoughts - Reasoning combined with executable code")

scientific_problem = "Does the relationship between temperature and plant growth rate follow a linear or exponential pattern? Data: Daily temperature readings (°C) and growth measurements (cm) for 30 days: Temps range from 15-35°C, growth from 0.5-4.2 cm/day"

IO.puts("Example scientific research question:")
IO.puts("  #{String.slice(scientific_problem, 0, 100)}...")

IO.puts("\nPattern: scientific_pot = Dspy.ProgramOfThoughts.new(signature, executor: :elixir)")
IO.puts("Benefit: Combines natural language reasoning with computational analysis\n")

# ==== LEVEL 7: TREE OF THOUGHTS ====

IO.puts("🌟 LEVEL 7: Tree of Thoughts for Creative Innovation")
IO.puts("Module: Dspy.TreeOfThoughts - Tree exploration of reasoning paths")

innovation_challenge = "Design a solution to reduce food waste in urban restaurants while creating value for all stakeholders. Must be implementable within 6 months, cost under $50K per restaurant, integrate with existing POS systems, comply with health regulations, and generate measurable ROI within 1 year."

IO.puts("Example innovation challenge:")
IO.puts("  #{String.slice(innovation_challenge, 0, 100)}...")

IO.puts("\nPattern: creative_tot = Dspy.TreeOfThoughts.new(signature, num_thoughts: 4, max_depth: 3)")
IO.puts("Benefit: Explores multiple creative reasoning paths in parallel\n")

# ==== LEVEL 8: MASS COLLABORATION ====

IO.puts("🚀 LEVEL 8: Mass Collaboration for System Design")
IO.puts("Module: Dspy.MassCollaboration - Multiple specialized agents collaborating")

system_requirements = "Design a real-time global messaging platform supporting 100M+ concurrent users, with end-to-end encryption, multimedia sharing, group chats up to 10K members, cross-platform compatibility, 99.99% uptime, sub-100ms message delivery, GDPR compliance, and ability to scale from 1M to 1B users over 2 years. Budget: $50M initial, $20M annual operating."

IO.puts("Example system design challenge:")
IO.puts("  #{String.slice(system_requirements, 0, 100)}...")

IO.puts("\nSpecialized agents:")
IO.puts("  - System Architect: Overall design patterns")
IO.puts("  - Performance Engineer: Scalability and optimization")
IO.puts("  - Security Specialist: Cybersecurity and encryption")
IO.puts("  - Reliability Engineer: Monitoring and fault tolerance")

IO.puts("\nPattern: mass_collab = Dspy.MassCollaboration.new(agents: agents, collaboration_rounds: 3)")
IO.puts("Benefit: Leverages multiple expert perspectives for complex problems\n")

# ==== PROGRESSION SUMMARY ====

IO.puts(String.duplicate("=", 60))
IO.puts("🎯 PROGRESSIVE CHALLENGE COMPLETE")
IO.puts(String.duplicate("=", 60))
IO.puts("✅ Level 1: Basic factual reasoning (Dspy.Predict)")
IO.puts("✅ Level 2: Chain of thought for multi-step problems (Dspy.ChainOfThought)") 
IO.puts("✅ Level 3: Self-consistency for accuracy (Dspy.SelfConsistency)")
IO.puts("✅ Level 4: Multi-step reasoning for complex analysis (Dspy.MultiStep)")
IO.puts("✅ Level 5: Adaptive backtracking with constraints (Dspy.AdaptiveBacktracking)")
IO.puts("✅ Level 6: Program of thoughts for computation (Dspy.ProgramOfThoughts)")
IO.puts("✅ Level 7: Tree of thoughts for creativity (Dspy.TreeOfThoughts)")
IO.puts("✅ Level 8: Mass collaboration for expertise (Dspy.MassCollaboration)")

IO.puts("\n🧠 COGNITIVE COMPLEXITY PROGRESSION:")
IO.puts("   Basic → Reasoning → Verification → Planning → Adaptation → Computation → Creativity → Collaboration")

IO.puts("\n💡 Key Insights:")
IO.puts("   • Each level builds upon previous capabilities")
IO.puts("   • Problems become increasingly complex and nuanced")
IO.puts("   • Solutions require more sophisticated reasoning strategies")
IO.puts("   • Advanced levels combine multiple reasoning approaches")
IO.puts("   • Final levels simulate expert-level collaborative problem solving")

IO.puts("\n🚀 This demonstrates DSPy's capability to handle problems ranging from")
IO.puts("   simple facts to complex multi-agent collaborative reasoning tasks.")