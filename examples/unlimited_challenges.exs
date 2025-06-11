#!/usr/bin/env elixir

# Unlimited Progressive Challenge Generator
# Automatically generates increasingly difficult problems across all 8 DSPy reasoning levels
# Runs indefinitely, continuously creating new challenges

defmodule UnlimitedChallengeGenerator do
  @moduledoc """
  Auto-generates unlimited progressive challenges that increase in complexity.
  Each level builds upon the previous, creating an endless stream of problems
  that test and push the boundaries of AI reasoning capabilities.
  """

  # Problem templates for each level
  @level_1_templates [
    "What is {number1} {operation} {number2}?",
    "What is the capital of {country}?",
    "How many {time_unit} are in {period}?",
    "What color do you get when you mix {color1} and {color2}?",
    "What is the {superlative} {noun} in the {category}?",
    "How many sides does a {shape} have?",
    "What year did {historical_event} happen?",
    "What is the main ingredient in {food}?",
    "What planet is {ordinal} from the sun?",
    "How many bones are in the human {body_part}?"
  ]

  @level_2_templates [
    "If a store sells {quantity1} {item} for ${price}, and you buy {quantity2} {item}, how much do you pay and how much change do you get from ${payment}?",
    "{person1} is {age_relation} {person2}. In {years} years, {person2} will be {target_age}. How old is {person1} now?",
    "A train leaves {city1} at {time} traveling at {speed1} mph toward {city2}. Another train leaves {city2} at {time2} traveling at {speed2} mph toward {city1}. If the cities are {distance} miles apart, when and where do they meet?",
    "You have a {container_size} container and need to fill it using a {tool_size1} cup and a {tool_size2} cup. What's the minimum number of operations needed?",
    "A recipe serves {original_servings} people and calls for {ingredient_amount} of {ingredient}. How much {ingredient} do you need to serve {target_servings} people?",
    "If it takes {workers1} workers {time1} hours to complete a job, how long will it take {workers2} workers to complete the same job?",
    "A car travels {distance1} miles in {time1} hours, then {distance2} miles in {time2} hours. What is the average speed for the entire trip?",
    "You invest ${principal} at {interest_rate}% annual interest. How much will you have after {years} years with compound interest?",
    "A rectangular garden is {length} feet by {width} feet. If you want to increase the area by {percentage}% by adding the same amount to both dimensions, what should the new dimensions be?",
    "If {percentage1}% of {group} are {category1} and {percentage2}% of {category1} are {subcategory}, how many {subcategory} are there in a group of {total_size}?"
  ]

  @level_3_templates [
    "Find all real solutions to the equation: {equation_type} = 0. Show multiple solution approaches and verify consistency.",
    "A complex geometric series has first term a = {first_term} and common ratio r = {ratio}. Find the sum of the first {terms} terms and determine convergence.",
    "Calculate the area under the curve y = {function} from x = {start} to x = {end} using multiple methods and compare results.",
    "Solve the optimization problem: {optimization_constraint} subject to {constraint1} and {constraint2}. Verify using different approaches.",
    "Determine if the infinite series {series_formula} converges or diverges using multiple convergence tests.",
    "Find the maximum and minimum values of {multivariable_function} subject to the constraint {constraint_equation}.",
    "Solve the differential equation {differential_equation} with initial condition {initial_condition} using multiple methods.",
    "Calculate the probability that {probability_scenario} using different probability approaches and verify consistency.",
    "Find the eigenvalues and eigenvectors of the matrix {matrix_description} using multiple computational approaches.",
    "Determine the limit of {limit_expression} as {variable} approaches {limit_point} using different limit techniques."
  ]

  @level_4_templates [
    "{company} faces {crisis_type} due to {root_cause}. They have ${budget} to invest and must choose between {option1}, {option2}, and {option3}. Each option has different {success_probability}, {timeline}, and {risk_factors}. Provide comprehensive analysis and recommendation.",
    "A {technology_type} startup is considering {business_decision} in {market_context}. Analyze market conditions, competitive landscape, financial implications, technical feasibility, and regulatory considerations. Provide multi-step strategic recommendation.",
    "{organization} needs to implement {major_change} while maintaining {critical_constraint}. Consider stakeholder impact, resource allocation, timeline management, risk mitigation, and success metrics. Develop comprehensive implementation plan.",
    "In the context of {industry_sector}, evaluate the impact of {disruptive_technology} on {market_segment}. Analyze short-term disruption, long-term transformation, winner/loser scenarios, and strategic responses.",
    "{city_type} is planning {urban_development} with budget constraints of ${budget} and must balance {competing_interest1}, {competing_interest2}, and {competing_interest3}. Develop multi-phase implementation strategy.",
    "A {healthcare_scenario} requires decision between {treatment_option1} and {treatment_option2} considering {patient_factors}, {cost_factors}, {outcome_probabilities}, and {ethical_considerations}. Provide evidence-based recommendation.",
    "{educational_institution} must address {academic_challenge} while dealing with {resource_constraint} and {stakeholder_pressure}. Design comprehensive solution addressing pedagogical, administrative, and financial aspects.",
    "Given {environmental_crisis} affecting {geographic_region}, develop intervention strategy considering {ecological_factors}, {economic_impact}, {political_constraints}, and {technological_solutions}.",
    "{global_corporation} faces {regulatory_challenge} across {number_countries} countries with different {legal_frameworks}. Design compliance strategy addressing legal, operational, and financial requirements.",
    "A {research_institution} must allocate {resource_type} across {number_projects} competing projects with different {success_probability}, {impact_potential}, and {time_horizons}. Optimize allocation strategy."
  ]

  @level_5_templates [
    "An AI company developed facial recognition that could solve missing children cases but raises privacy concerns. Address {ethical_dimension1}, {ethical_dimension2}, and {ethical_dimension3} while considering {stakeholder1}, {stakeholder2}, and {stakeholder3} perspectives. Ensure reasoning avoids {bias_type} and maintains {ethical_standard}.",
    "A pharmaceutical company must decide on {drug_pricing} for a life-saving medication in {market_context}. Balance {profit_motive}, {patient_access}, {research_costs}, and {regulatory_pressure} while meeting constraints of {accessibility_requirement} and {sustainability_requirement}.",
    "Design an AI system for {high_stakes_domain} that must be {requirement1}, {requirement2}, and {requirement3}. Address potential {failure_mode1} and {failure_mode2} while ensuring {safety_standard} and {ethical_compliance}.",
    "A {technology_platform} must handle {content_moderation_challenge} across {cultural_context1} and {cultural_context2} with different {value_system1} and {value_system2}. Develop approach that respects {cultural_sensitivity} while maintaining {platform_integrity}.",
    "In {resource_scarcity_scenario}, allocate {limited_resource} between {competing_need1}, {competing_need2}, and {competing_need3}. Consider {equity_principle}, {efficiency_principle}, and {sustainability_principle} while avoiding {allocation_bias}.",
    "A {autonomous_system} must make decisions in {moral_dilemma_scenario} involving {moral_consideration1} and {moral_consideration2}. Design decision framework that handles {edge_case1} and {edge_case2} while maintaining {moral_consistency}.",
    "Address {social_justice_issue} in {institutional_context} by balancing {progressive_approach} and {conservative_approach} while considering {historical_context}, {current_constraints}, and {future_implications}.",
    "Design {privacy_preserving_technology} for {data_sensitive_domain} that enables {beneficial_use1} and {beneficial_use2} while preventing {misuse_risk1} and {misuse_risk2}. Ensure {privacy_standard} and {transparency_requirement}.",
    "In {crisis_scenario}, coordinate response between {stakeholder1}, {stakeholder2}, and {stakeholder3} with conflicting {priority1}, {priority2}, and {priority3}. Develop approach that ensures {fairness_principle} and {effectiveness_principle}.",
    "A {decision_making_body} must choose between {policy_option1} and {policy_option2} in {political_context} while addressing {interest_group1}, {interest_group2}, and {public_interest}. Design recommendation that withstands {scrutiny_type} analysis."
  ]

  @level_6_templates [
    "Analyze the relationship between {scientific_variable1} and {scientific_variable2} in {research_domain}. Design experiments, collect data, perform statistical analysis, and determine if the relationship is {relationship_type1} or {relationship_type2}. Include computational modeling and simulation.",
    "Develop a {computational_model} to predict {outcome_variable} based on {input_variable1}, {input_variable2}, and {input_variable3}. Implement multiple algorithms, compare performance, and validate using {validation_method}. Provide executable analysis code.",
    "Investigate {scientific_phenomenon} using {methodology1} and {methodology2}. Generate testable hypotheses, design computational experiments, analyze results using {statistical_technique}, and draw evidence-based conclusions.",
    "Create a {simulation_type} simulation to study {complex_system} behavior under {condition1}, {condition2}, and {condition3}. Implement sensitivity analysis, parameter optimization, and scenario modeling with executable code.",
    "Analyze {large_dataset_type} data to identify {pattern_type} patterns related to {research_question}. Use {analysis_technique1}, {analysis_technique2}, and {machine_learning_method} to extract insights and make predictions.",
    "Design {optimization_algorithm} to solve {optimization_problem} with constraints {constraint1}, {constraint2}, and {constraint3}. Implement multiple approaches, compare efficiency, and validate solutions computationally.",
    "Study {complex_network} using {network_analysis_method} to understand {network_property1} and {network_property2}. Create computational models to predict {network_behavior} under different scenarios.",
    "Develop {predictive_model} for {time_series_data} incorporating {external_factor1}, {external_factor2}, and {seasonal_component}. Implement forecasting algorithms and validate using {validation_approach}.",
    "Analyze {experimental_data_type} from {scientific_domain} to test {scientific_hypothesis}. Use {computational_technique1} and {computational_technique2} to process data and draw statistical conclusions.",
    "Create {agent_based_model} to simulate {social_phenomenon} involving {agent_type1}, {agent_type2}, and {environmental_factor}. Study emergent behaviors and policy implications using computational experiments."
  ]

  @level_7_templates [
    "Design innovative solution to reduce {waste_type} in {industry_context} while creating value for {stakeholder1}, {stakeholder2}, and {stakeholder3}. Explore {creative_approach1}, {creative_approach2}, and {unconventional_method}. Consider {constraint1} and {constraint2}.",
    "Develop {breakthrough_technology} that revolutionizes {problem_domain} by combining {technology1}, {technology2}, and {novel_approach}. Address {technical_challenge1}, {technical_challenge2}, and {adoption_barrier}.",
    "Create {artistic_expression} that communicates {complex_concept} to {target_audience} while incorporating {cultural_element1}, {cultural_element2}, and {innovation_aspect}. Consider multiple creative pathways and artistic mediums.",
    "Design {educational_innovation} that transforms how {subject_matter} is taught by leveraging {pedagogical_approach1}, {pedagogical_approach2}, and {technology_integration}. Address {learning_challenge1} and {learning_challenge2}.",
    "Invent {product_concept} that solves {user_problem} in {market_context} using {innovative_feature1}, {innovative_feature2}, and {disruptive_element}. Explore {creative_direction1}, {creative_direction2}, and {unconventional_solution}.",
    "Develop {creative_framework} for {problem_solving_domain} that combines {methodology1}, {methodology2}, and {novel_perspective}. Design approach that handles {complexity_factor1} and {complexity_factor2}.",
    "Create {storytelling_format} that explores {philosophical_question} through {narrative_approach1}, {narrative_approach2}, and {experimental_technique}. Address {thematic_element1} and {thematic_element2}.",
    "Design {collaborative_platform} that enables {creative_activity} between {participant_type1}, {participant_type2}, and {participant_type3}. Incorporate {innovation_mechanism1} and {innovation_mechanism2}.",
    "Develop {game_concept} that teaches {complex_skill} through {gameplay_mechanic1}, {gameplay_mechanic2}, and {learning_integration}. Balance {engagement_factor} with {educational_objective}.",
    "Create {artistic_installation} that demonstrates {scientific_principle} using {interactive_element1}, {interactive_element2}, and {sensory_component}. Make {abstract_concept} tangible and engaging."
  ]

  @level_8_templates [
    "Design real-time global messaging platform supporting {user_scale}+ concurrent users with {security_requirement1}, {security_requirement2}, and {reliability_requirement}. Coordinate {expert_type1}, {expert_type2}, {expert_type3}, and {expert_type4} to address {technical_challenge1}, {technical_challenge2}, and {scalability_challenge}.",
    "Develop {complex_system} for {critical_domain} requiring expertise in {domain1}, {domain2}, {domain3}, and {domain4}. Address {system_requirement1}, {system_requirement2}, and {integration_challenge} through multi-expert collaboration.",
    "Create {innovative_solution} for {global_challenge} by integrating perspectives from {expert_background1}, {expert_background2}, {expert_background3}, and {expert_background4}. Handle {complexity_dimension1}, {complexity_dimension2}, and {interdisciplinary_challenge}.",
    "Design {advanced_technology} that combines {technical_domain1}, {technical_domain2}, and {technical_domain3} to solve {multifaceted_problem}. Coordinate {specialist1}, {specialist2}, {specialist3}, and {generalist} expertise.",
    "Develop comprehensive strategy for {organizational_transformation} requiring {change_management}, {technology_integration}, {process_optimization}, and {cultural_adaptation}. Leverage {consultant_type1}, {consultant_type2}, and {internal_expert} collaboration.",
    "Create {research_initiative} addressing {scientific_question} that spans {discipline1}, {discipline2}, {discipline3}, and {discipline4}. Design collaborative framework for {researcher_type1}, {researcher_type2}, and {practitioner_type}.",
    "Design {policy_framework} for {governance_challenge} requiring input from {policy_expert}, {technical_advisor}, {stakeholder_representative}, and {implementation_specialist}. Address {political_dimension}, {technical_dimension}, and {social_dimension}.",
    "Develop {educational_ecosystem} that transforms {learning_domain} through collaboration between {educator_type1}, {educator_type2}, {technologist}, and {learning_scientist}. Handle {pedagogical_challenge}, {technological_challenge}, and {scalability_challenge}.",
    "Create {healthcare_innovation} addressing {medical_challenge} by coordinating {medical_specialist1}, {medical_specialist2}, {biomedical_engineer}, and {health_informaticist}. Address {clinical_requirement}, {safety_requirement}, and {regulatory_requirement}.",
    "Design {environmental_solution} for {ecological_challenge} requiring collaboration between {environmental_scientist}, {policy_analyst}, {technology_developer}, and {community_organizer}. Balance {environmental_goal}, {economic_constraint}, and {social_consideration}."
  ]

  # Data pools for template variable substitution
  @data_pools %{
    numbers: 1..100 |> Enum.to_list(),
    operations: ["+", "-", "*", "/"],
    countries: ["France", "Japan", "Brazil", "Kenya", "Australia", "Norway", "India", "Chile"],
    colors: ["red", "blue", "yellow", "green", "purple", "orange", "pink", "brown"],
    shapes: ["triangle", "pentagon", "hexagon", "octagon", "decagon"],
    companies: ["TechCorp", "InnovateCo", "GlobalSoft", "NextGen Inc", "FutureTech", "SmartSystems"],
    industries: ["healthcare", "finance", "education", "manufacturing", "retail", "transportation"],
    technologies: ["AI", "blockchain", "quantum computing", "IoT", "robotics", "biotechnology"],
    problems: ["climate change", "inequality", "cybersecurity", "aging population", "urbanization", "resource scarcity"],
    constraints: ["budget limitations", "regulatory compliance", "time pressure", "stakeholder resistance", "technical complexity"],
    experts: ["system architect", "performance engineer", "security specialist", "reliability engineer", "UX designer", "data scientist"]
  }

  def start_unlimited_challenges do
    IO.puts("🚀 Starting Unlimited Progressive Challenge Generator")
    IO.puts("📈 Automatically generating increasingly difficult problems")
    IO.puts("♾️  Running in unbounded mode - press Ctrl+C to stop\n")
    
    # Initialize metrics
    metrics = %{
      total_challenges: 0,
      level_counts: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0},
      start_time: DateTime.utc_now(),
      current_difficulty_multiplier: 1.0
    }
    
    run_unlimited_loop(metrics)
  end

  defp run_unlimited_loop(metrics) do
    # Select level based on progression and difficulty
    level = select_next_level(metrics)
    
    # Generate problem for selected level
    challenge = generate_challenge_for_level(level, metrics.current_difficulty_multiplier)
    
    # Display challenge
    display_challenge(challenge, metrics)
    
    # Simulate solving (in real implementation, this would call DSPy modules)
    solution = simulate_solution(challenge)
    
    # Display solution
    display_solution(solution)
    
    # Update metrics
    updated_metrics = update_metrics(metrics, level)
    
    # Display progress
    display_progress(updated_metrics)
    
    # Brief pause before next challenge
    Process.sleep(2000)
    
    # Continue indefinitely
    run_unlimited_loop(updated_metrics)
  end

  defp select_next_level(metrics) do
    total = metrics.total_challenges
    
    cond do
      total < 10 -> Enum.random([1, 2])  # Start with basics
      total < 25 -> Enum.random([1, 2, 3])  # Add verification
      total < 50 -> Enum.random([1, 2, 3, 4])  # Add multi-step
      total < 100 -> Enum.random([1, 2, 3, 4, 5, 6])  # Add constraints and computation
      total < 200 -> Enum.random([1, 2, 3, 4, 5, 6, 7])  # Add creativity
      true -> Enum.random([1, 2, 3, 4, 5, 6, 7, 8])  # All levels
    end
  end

  defp generate_challenge_for_level(level, difficulty_multiplier) do
    template = select_template_for_level(level)
    variables = generate_variables_for_template(template, difficulty_multiplier)
    problem_text = substitute_template(template, variables)
    
    %{
      level: level,
      problem: problem_text,
      difficulty: calculate_difficulty(level, difficulty_multiplier),
      variables: variables,
      timestamp: DateTime.utc_now()
    }
  end

  defp select_template_for_level(level) do
    templates = case level do
      1 -> @level_1_templates
      2 -> @level_2_templates
      3 -> @level_3_templates
      4 -> @level_4_templates
      5 -> @level_5_templates
      6 -> @level_6_templates
      7 -> @level_7_templates
      8 -> @level_8_templates
    end
    
    Enum.random(templates)
  end

  defp generate_variables_for_template(template, difficulty_multiplier) do
    # Extract variable names from template (words in {})
    variables = Regex.scan(~r/\{(\w+)\}/, template, capture: :all_but_first)
                |> List.flatten()
                |> Enum.uniq()
    
    # Generate values for each variable
    variables
    |> Enum.map(fn var -> {var, generate_variable_value(var, difficulty_multiplier)} end)
    |> Enum.into(%{})
  end

  defp generate_variable_value(var_name, difficulty_multiplier) do
    base_value = case var_name do
      var when var in ["number1", "number2", "quantity1", "quantity2"] ->
        Enum.random(1..round(100 * difficulty_multiplier))
      
      var when var in ["operation"] ->
        Enum.random(@data_pools.operations)
      
      var when var in ["country"] ->
        Enum.random(@data_pools.countries)
      
      var when var in ["color1", "color2"] ->
        Enum.random(@data_pools.colors)
      
      var when var in ["shape"] ->
        Enum.random(@data_pools.shapes)
      
      var when var in ["company"] ->
        Enum.random(@data_pools.companies)
      
      var when var in ["industry_context", "problem_domain"] ->
        Enum.random(@data_pools.industries)
      
      var when var in ["technology_type", "breakthrough_technology"] ->
        Enum.random(@data_pools.technologies)
      
      var when var in ["global_challenge", "complex_problem"] ->
        Enum.random(@data_pools.problems)
      
      var when var in ["constraint1", "constraint2"] ->
        Enum.random(@data_pools.constraints)
      
      var when var in ["expert_type1", "expert_type2", "expert_type3", "expert_type4"] ->
        Enum.random(@data_pools.experts)
      
      var when var in ["user_scale"] ->
        scales = ["100M", "500M", "1B", "5B"]
        multiplied_scales = Enum.map(scales, fn scale -> 
          num = String.replace(scale, ~r/[MB]/, "") |> String.to_integer()
          unit = String.last(scale)
          "#{round(num * difficulty_multiplier)}#{unit}"
        end)
        Enum.random(multiplied_scales)
      
      var when var in ["budget"] ->
        budgets = [1_000_000, 5_000_000, 10_000_000, 50_000_000, 100_000_000]
        Enum.random(budgets) |> Kernel.*(difficulty_multiplier) |> round()
      
      # Generic categories for complex variables
      var when String.contains?(var, "requirement") ->
        requirements = ["high availability", "scalability", "security", "performance", "reliability", "usability"]
        Enum.random(requirements)
      
      var when String.contains?(var, "challenge") ->
        challenges = ["technical complexity", "resource constraints", "time pressure", "stakeholder alignment", "regulatory compliance"]
        Enum.random(challenges)
      
      var when String.contains?(var, "approach") ->
        approaches = ["innovative methodology", "collaborative framework", "systematic analysis", "iterative development", "evidence-based strategy"]
        Enum.random(approaches)
      
      var when String.contains?(var, "factor") ->
        factors = ["market dynamics", "technological readiness", "organizational culture", "regulatory environment", "competitive landscape"]
        Enum.random(factors)
      
      # Default fallback
      _ ->
        "#{var}_#{:rand.uniform(1000)}"
    end
    
    base_value
  end

  defp substitute_template(template, variables) do
    Enum.reduce(variables, template, fn {var, value}, acc ->
      String.replace(acc, "{#{var}}", to_string(value))
    end)
  end

  defp calculate_difficulty(level, difficulty_multiplier) do
    base_difficulty = level * 10
    final_difficulty = base_difficulty * difficulty_multiplier
    round(final_difficulty)
  end

  defp display_challenge(challenge, metrics) do
    level_names = %{
      1 => "Basic Factual Reasoning",
      2 => "Chain of Thought Reasoning", 
      3 => "Self-Consistency Verification",
      4 => "Multi-Step Analysis",
      5 => "Adaptive Backtracking",
      6 => "Program of Thoughts",
      7 => "Tree of Thoughts",
      8 => "Mass Collaboration"
    }
    
    level_icons = %{
      1 => "🟢", 2 => "🟡", 3 => "🔵", 4 => "🟠", 
      5 => "🔴", 6 => "⚫", 7 => "🌟", 8 => "🚀"
    }
    
    IO.puts("#{String.duplicate("=", 80)}")
    IO.puts("#{level_icons[challenge.level]} LEVEL #{challenge.level}: #{level_names[challenge.level]}")
    IO.puts("🎯 Challenge ##{metrics.total_challenges + 1} | Difficulty: #{challenge.difficulty}/100")
    IO.puts("#{String.duplicate("-", 80)}")
    IO.puts("📋 PROBLEM:")
    IO.puts("#{challenge.problem}")
    IO.puts("#{String.duplicate("-", 80)}")
  end

  defp simulate_solution(challenge) do
    # In a real implementation, this would call the appropriate DSPy module
    # For now, we'll simulate the solution process
    
    processing_time = :rand.uniform(2000) + 500  # 0.5-2.5 seconds
    Process.sleep(processing_time)
    
    solution_quality = case challenge.level do
      level when level <= 2 -> Enum.random(85..98)
      level when level <= 4 -> Enum.random(75..92)
      level when level <= 6 -> Enum.random(65..87)
      level when level <= 8 -> Enum.random(55..82)
    end
    
    %{
      approach: get_approach_for_level(challenge.level),
      quality_score: solution_quality,
      processing_time_ms: processing_time,
      reasoning_steps: generate_reasoning_steps(challenge.level),
      confidence: solution_quality + Enum.random(-10..5)
    }
  end

  defp get_approach_for_level(level) do
    approaches = %{
      1 => "Direct factual retrieval and basic computation",
      2 => "Step-by-step reasoning with intermediate conclusions", 
      3 => "Multiple solution paths with consistency verification",
      4 => "Sequential multi-step analysis with constraint checking",
      5 => "Adaptive reasoning with backtracking on constraint violations",
      6 => "Combined natural language reasoning with computational analysis",
      7 => "Parallel exploration of multiple creative solution paths",
      8 => "Multi-agent collaboration with specialized expert perspectives"
    }
    
    approaches[level]
  end

  defp generate_reasoning_steps(level) do
    base_steps = level * 2
    actual_steps = base_steps + :rand.uniform(level)
    
    1..actual_steps
    |> Enum.map(fn i -> "Step #{i}: #{generate_step_description(level, i)}" end)
  end

  defp generate_step_description(level, step_num) do
    step_types = case level do
      1 -> ["Identify key information", "Apply basic operation", "Verify result"]
      2 -> ["Break down problem", "Analyze relationships", "Calculate intermediate result", "Verify logic"]
      3 -> ["Generate solution approach", "Cross-verify with alternative method", "Check consistency"]
      4 -> ["Analyze situation", "Identify constraints", "Evaluate options", "Make recommendation"]
      5 -> ["Explore approach", "Check constraints", "Backtrack if needed", "Refine solution"]
      6 -> ["Design analysis", "Implement computation", "Interpret results", "Validate findings"]
      7 -> ["Generate creative ideas", "Explore possibility space", "Evaluate innovations", "Synthesize solutions"]
      8 -> ["Coordinate expert input", "Integrate perspectives", "Resolve conflicts", "Build consensus"]
    end
    
    selected_type = Enum.at(step_types, rem(step_num - 1, length(step_types)))
    "#{selected_type} (complexity level #{level})"
  end

  defp display_solution(solution) do
    IO.puts("🧠 SOLUTION APPROACH:")
    IO.puts("#{solution.approach}")
    IO.puts("")
    IO.puts("📊 METRICS:")
    IO.puts("• Quality Score: #{solution.quality_score}/100")
    IO.puts("• Confidence: #{solution.confidence}%")
    IO.puts("• Processing Time: #{solution.processing_time_ms}ms")
    IO.puts("• Reasoning Steps: #{length(solution.reasoning_steps)}")
    IO.puts("")
    IO.puts("🔍 REASONING PROCESS:")
    Enum.each(solution.reasoning_steps, fn step -> IO.puts("  #{step}") end)
    IO.puts("")
  end

  defp update_metrics(metrics, level) do
    %{
      total_challenges: metrics.total_challenges + 1,
      level_counts: Map.update!(metrics.level_counts, level, &(&1 + 1)),
      start_time: metrics.start_time,
      current_difficulty_multiplier: calculate_new_difficulty_multiplier(metrics.total_challenges + 1)
    }
  end

  defp calculate_new_difficulty_multiplier(total_challenges) do
    # Gradually increase difficulty over time
    base_multiplier = 1.0
    growth_rate = 0.01  # 1% increase per challenge
    max_multiplier = 5.0
    
    new_multiplier = base_multiplier + (total_challenges * growth_rate)
    min(new_multiplier, max_multiplier)
  end

  defp display_progress(metrics) do
    elapsed = DateTime.diff(DateTime.utc_now(), metrics.start_time, :second)
    rate = if elapsed > 0, do: Float.round(metrics.total_challenges / elapsed, 2), else: 0.0
    
    IO.puts("📈 PROGRESS SUMMARY:")
    IO.puts("• Total Challenges: #{metrics.total_challenges}")
    IO.puts("• Runtime: #{elapsed} seconds")
    IO.puts("• Rate: #{rate} challenges/second")
    IO.puts("• Current Difficulty Multiplier: #{Float.round(metrics.current_difficulty_multiplier, 2)}x")
    IO.puts("")
    IO.puts("📊 LEVEL DISTRIBUTION:")
    Enum.each(1..8, fn level ->
      count = metrics.level_counts[level]
      percentage = if metrics.total_challenges > 0, do: Float.round(count / metrics.total_challenges * 100, 1), else: 0.0
      IO.puts("  Level #{level}: #{count} challenges (#{percentage}%)")
    end)
    IO.puts("")
    IO.puts("⏱️  Next challenge in 2 seconds...")
    IO.puts("")
  end
end

# Start the unlimited challenge generator
UnlimitedChallengeGenerator.start_unlimited_challenges()