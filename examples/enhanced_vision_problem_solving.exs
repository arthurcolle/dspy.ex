#!/usr/bin/env elixir

# Enhanced Vision Problem Solving Example
# Demonstrates the new capabilities:
# - No truncation with intelligent content management
# - Multiple sequential problem solving 
# - Vision/image abstraction support
# - Integration with evalscompany evaluation metrics

Mix.install([
  {:dspy, path: ".."},
  {:jason, "~> 1.4"}
])

defmodule VisionProblemSignature do
  use Dspy.Signature

  @input_fields [
    %{name: :problem_description, type: :string, description: "The problem description", required: true},
    %{name: :image_data, type: :image, description: "Visual data or diagram", required: false, vision_enabled: true},
    %{name: :context, type: :string, description: "Additional context or constraints", required: false}
  ]

  @output_fields [
    %{name: :analysis, type: :string, description: "Step-by-step analysis of the problem", required: true},
    %{name: :solution, type: :string, description: "The complete solution", required: true},
    %{name: :reasoning, type: :string, description: "Detailed reasoning process", required: true},
    %{name: :confidence, type: :number, description: "Confidence score (0-1)", required: true}
  ]

  def signature do
    Dspy.Signature.new("VisionProblemSolver",
      description: "Solve complex problems with visual elements using multi-step reasoning",
      input_fields: @input_fields,
      output_fields: @output_fields,
      instructions: """
      Analyze the given problem systematically. If images are provided, examine them carefully 
      and integrate visual information into your reasoning. Break down complex problems into 
      sequential steps and provide detailed analysis.
      """
    )
  end
end

defmodule EnhancedVisionExample do
  def run do
    IO.puts("\n🚀 Enhanced DSPy Vision Problem Solving Demo")
    IO.puts("=" |> String.duplicate(50))
    
    # Configure OpenAI with vision support
    lm = Dspy.LM.OpenAI.new(
      model: "gpt-4.1",  # Vision-capable model
      api_key: System.get_env("OPENAI_API_KEY")
    )
    
    Dspy.Settings.put(:lm, lm)
    
    # Test 1: No Truncation - Large Problem
    IO.puts("\n📝 Test 1: Large Problem without Truncation")
    test_large_problem()
    
    # Test 2: Sequential Problem Solving
    IO.puts("\n🔄 Test 2: Sequential Multi-Step Problem Solving")
    test_sequential_solving()
    
    # Test 3: Vision Integration
    IO.puts("\n👁️ Test 3: Vision/Image Problem Solving")
    test_vision_problem()
    
    # Test 4: CBLE-style Evaluation
    IO.puts("\n📊 Test 4: Advanced Evaluation Metrics")
    test_evaluation_metrics()
    
    IO.puts("\n✅ All enhanced capabilities demonstrated!")
  end
  
  defp test_large_problem do
    # Create a very large problem that would normally be truncated
    large_context = """
    This is a comprehensive systems design problem that involves multiple components and considerations.
    
    Background: You are designing a distributed microservices architecture for a large e-commerce platform 
    that needs to handle millions of requests per day. The system must support:
    
    1. User Management: Registration, authentication, profile management, preferences
    2. Product Catalog: Search, filtering, recommendations, inventory tracking
    3. Shopping Cart: Session management, persistence, real-time updates
    4. Order Processing: Payment processing, fraud detection, order fulfillment
    5. Shipping: Logistics optimization, tracking, delivery scheduling
    6. Customer Service: Chat support, ticket management, knowledge base
    7. Analytics: Real-time monitoring, business intelligence, performance metrics
    8. Security: Data encryption, access control, audit logging, compliance
    
    Technical Requirements:
    - 99.9% uptime
    - Sub-100ms response times for 95% of requests
    - Support for 10x traffic spikes during sales events
    - GDPR and PCI DSS compliance
    - Multi-region deployment
    - Auto-scaling capabilities
    - Disaster recovery with RPO < 1 hour
    
    Constraints:
    - Budget limitations require cost optimization
    - Legacy systems must be gradually migrated
    - Team has limited expertise in certain technologies
    - Regulatory requirements vary by geographic region
    - Integration with existing third-party services required
    
    Current Infrastructure:
    - Monolithic application on legacy servers
    - MySQL database with performance bottlenecks
    - Limited monitoring and observability
    - Manual deployment processes
    - No containerization or orchestration
    
    Please provide a comprehensive solution that addresses all these requirements while managing the complexity and constraints.
    """ |> String.duplicate(3)  # Make it even larger
    
    # Create enhanced signature with content chunking
    enhanced_signature = Dspy.EnhancedSignature.new("LargeSystemDesign",
      description: "Design large-scale systems without content truncation",
      input_fields: [
        %{name: :requirements, type: :string, description: "Complete system requirements", 
          required: true, max_length: 50_000}
      ],
      output_fields: [
        %{name: :architecture_design, type: :string, description: "Complete architectural design", required: true},
        %{name: :implementation_plan, type: :string, description: "Step-by-step implementation plan", required: true}
      ],
      max_content_length: 100_000,
      chunk_strategy: :intelligent
    )
    
    # Create solver with chunking enabled
    solver = Dspy.SequentialVisionSolver.new(enhanced_signature,
      content_chunking: true,
      evaluation_config: %{
        enable_step_scoring: true,
        enable_reasoning_analysis: true,
        enable_efficiency_tracking: true
      }
    )
    
    inputs = %{requirements: large_context}
    
    case Dspy.Module.forward(solver, inputs) do
      {:ok, prediction} ->
        result = prediction.attrs
        IO.puts("✅ Large problem processed successfully!")
        IO.puts("Architecture length: #{String.length(result.final_outputs[:architecture_design] || "")}")
        IO.puts("Implementation length: #{String.length(result.final_outputs[:implementation_plan] || "")}")
        IO.puts("Reasoning coherence: #{result.overall_metrics.reasoning_coherence}")
        
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end
  
  defp test_sequential_solving do
    # Define sequential steps for complex problem solving
    sequential_steps = [
      %{step_id: 1, name: "Problem Decomposition", 
        inputs: [:problem_description], outputs: [:sub_problems],
        dependencies: []},
      %{step_id: 2, name: "Solution Strategy", 
        inputs: [:sub_problems], outputs: [:strategy],
        dependencies: [1]},
      %{step_id: 3, name: "Implementation Details", 
        inputs: [:strategy], outputs: [:implementation],
        dependencies: [2]},
      %{step_id: 4, name: "Validation and Testing", 
        inputs: [:implementation], outputs: [:validation],
        dependencies: [3]}
    ]
    
    enhanced_signature = Dspy.EnhancedSignature.new("SequentialMathSolver",
      description: "Solve complex mathematical problems using sequential reasoning",
      input_fields: [
        %{name: :problem_description, type: :string, description: "Mathematical problem to solve", required: true}
      ],
      output_fields: [
        %{name: :final_answer, type: :string, description: "Final numerical or algebraic answer", required: true},
        %{name: :solution_steps, type: :string, description: "All solution steps", required: true}
      ],
      sequential_steps: sequential_steps,
      evaluation_criteria: %{
        correctness_weight: 0.4,
        reasoning_weight: 0.35,
        completeness_weight: 0.15,
        efficiency_weight: 0.1
      }
    )
    
    solver = Dspy.SequentialVisionSolver.new(enhanced_signature,
      sequential_steps: sequential_steps,
      evaluation_config: %{
        enable_step_scoring: true,
        enable_reasoning_analysis: true,
        enable_efficiency_tracking: true
      }
    )
    
    inputs = %{
      problem_description: """
      A cylindrical water tank has a radius of 3 meters and a height of 8 meters. 
      Water is being pumped into the tank at a rate of 2 cubic meters per minute, 
      while simultaneously being drained at a rate proportional to the current height 
      of water (drain rate = 0.5h cubic meters per minute, where h is height in meters).
      
      Find:
      1. The differential equation describing the water height over time
      2. The equilibrium water height
      3. The time to reach 95% of equilibrium height starting from empty
      4. The maximum height if the inflow rate doubles suddenly at t=10 minutes
      """
    }
    
    case Dspy.Module.forward(solver, inputs) do
      {:ok, prediction} ->
        result = prediction.attrs
        IO.puts("✅ Sequential problem solved!")
        IO.puts("Steps completed: #{length(result.step_results)}")
        IO.puts("Overall reasoning coherence: #{result.overall_metrics.reasoning_coherence}")
        IO.puts("Step efficiency: #{result.overall_metrics.step_efficiency}")
        IO.puts("Recommendation: #{result.recommendation}")
        
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end
  
  defp test_vision_problem do
    # Create a vision-enabled signature
    vision_signature = Dspy.EnhancedSignature.new("VisionGeometry",
      description: "Solve geometry problems using visual analysis",
      input_fields: [
        %{name: :problem_text, type: :string, description: "Geometry problem description", required: true},
        %{name: :diagram, type: :image, description: "Geometric diagram or figure", 
          required: false, vision_enabled: true}
      ],
      output_fields: [
        %{name: :visual_analysis, type: :vision_text, description: "Analysis of the visual elements", required: true},
        %{name: :solution_method, type: :string, description: "Method to solve the problem", required: true},
        %{name: :calculations, type: :string, description: "Step-by-step calculations", required: true},
        %{name: :final_answer, type: :string, description: "Final numerical answer with units", required: true}
      ],
      vision_enabled: true
    )
    
    solver = Dspy.SequentialVisionSolver.new(vision_signature,
      vision_enabled: true,
      evaluation_config: %{
        enable_vision_assessment: true,
        enable_reasoning_analysis: true
      }
    )
    
    # Simulate image input (in real use, this would be actual image data)
    inputs = %{
      problem_text: """
      In the given triangle ABC, angle B is 90 degrees, side AB = 6 cm, and side BC = 8 cm.
      Find the area of triangle ABC and the length of the hypotenuse AC.
      Also determine the angles A and C.
      """,
      diagram: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMgAAADI..." # Simulated base64 image
    }
    
    case Dspy.Module.forward(solver, inputs) do
      {:ok, prediction} ->
        result = prediction.attrs
        IO.puts("✅ Vision problem solved!")
        
        if Map.has_key?(result, :vision_analysis) do
          IO.puts("Vision integration score: #{result.vision_analysis[:vision_reference_score] || 0}")
          IO.puts("Vision items processed: #{result.vision_analysis[:total_vision_items] || 0}")
        end
        
        IO.puts("Overall vision integration: #{result.overall_metrics.vision_integration}")
        
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end
  
  defp test_evaluation_metrics do
    # Test the advanced evaluation metrics from evalscompany
    solver = Dspy.SequentialVisionSolver.new(VisionProblemSignature.signature(),
      evaluation_config: %{
        enable_step_scoring: true,
        enable_reasoning_analysis: true,
        enable_vision_assessment: true,
        enable_efficiency_tracking: true,
        enable_multi_signal_rewards: true
      }
    )
    
    # Example response for evaluation
    sample_response = """
    To solve this customs broker examination question, I need to analyze the trade documentation carefully.
    
    First, I'll examine the commercial invoice to identify the country of origin and harmonized code.
    The invoice shows that the goods are manufactured in China with HS code 8471.30.0100.
    
    Second, I need to determine the applicable duty rate. According to the current tariff schedule,
    electronic computing machines fall under Chapter 84, and the specific rate depends on the 
    trade agreement status between the US and China.
    
    Third, I'll calculate the customs value using the transaction value method, which includes
    the price paid plus any assists, royalties, and proceeds that are not included in the price.
    
    Therefore, the total duty calculation is: Customs Value × Duty Rate = $50,000 × 7.5% = $3,750.
    
    The mathematical expressions involved are straightforward percentage calculations, but the
    conceptual understanding requires knowledge of customs regulations and trade classifications.
    """
    
    evaluation_result = Dspy.SequentialVisionSolver.evaluate_reasoning_quality(
      solver, sample_response
    )
    
    IO.puts("📊 Evaluation Metrics Results:")
    IO.puts("Reasoning Coherence: #{evaluation_result.metrics.reasoning_coherence}")
    IO.puts("Conceptual Understanding: #{evaluation_result.metrics.conceptual_understanding}")
    IO.puts("Solution Optimality: #{evaluation_result.metrics.solution_optimality}")
    IO.puts("Symbolic Manipulation: #{evaluation_result.metrics.symbolic_manipulation}")
    IO.puts("Reasoning Depth: #{evaluation_result.metrics.reasoning_depth}")
    IO.puts("Creativity: #{evaluation_result.metrics.creativity}")
    
    IO.puts("\n📈 Detailed Analysis:")
    IO.puts("Reasoning Steps: #{evaluation_result.detailed_analysis.step_count}")
    IO.puts("Mathematical Expressions: #{length(evaluation_result.detailed_analysis.mathematical_expressions)}")
    IO.puts("Complexity Score: #{evaluation_result.detailed_analysis.complexity_score}")
  end
end

# Run the example
EnhancedVisionExample.run()