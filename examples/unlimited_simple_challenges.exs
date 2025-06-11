#!/usr/bin/env elixir

# Unlimited Simple Challenge Generator
# Continuously generates problems with increasing difficulty

defmodule UnlimitedSimpleChallenges do
  @moduledoc """
  Unlimited challenge generator that creates increasingly difficult problems
  across 8 reasoning levels and runs indefinitely.
  """

  def start do
    IO.puts("🚀 Starting Unlimited Challenge Generator")
    IO.puts("♾️  Generating problems with increasing difficulty")
    IO.puts("📈 Will run indefinitely - press Ctrl+C to stop\n")
    
    metrics = %{
      total: 0,
      level_counts: %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0, 7 => 0, 8 => 0},
      difficulty_multiplier: 1.0,
      start_time: DateTime.utc_now()
    }
    
    run_loop(metrics)
  end

  defp run_loop(metrics) do
    # Select level (progressive unlock)
    level = select_level(metrics.total)
    
    # Generate challenge
    challenge = generate_challenge(level, metrics.difficulty_multiplier)
    
    # Display
    display_challenge(challenge, metrics)
    
    # Update metrics
    updated_metrics = update_metrics(metrics, level)
    
    # Display progress
    display_progress(updated_metrics)
    
    # Continue
    Process.sleep(3000)
    run_loop(updated_metrics)
  end

  defp select_level(total) do
    cond do
      total < 10 -> Enum.random([1, 2])
      total < 25 -> Enum.random([1, 2, 3])
      total < 50 -> Enum.random([1, 2, 3, 4])
      total < 100 -> Enum.random([1, 2, 3, 4, 5, 6])
      total < 200 -> Enum.random([1, 2, 3, 4, 5, 6, 7])
      true -> Enum.random([1, 2, 3, 4, 5, 6, 7, 8])
    end
  end

  defp generate_challenge(level, difficulty) do
    template = get_template(level)
    problem = generate_problem(template, difficulty)
    
    %{
      level: level,
      problem: problem,
      difficulty: round(level * 10 * difficulty),
      timestamp: DateTime.utc_now()
    }
  end

  defp get_template(level) do
    templates = %{
      1 => [
        "What is {a} + {b}?",
        "What is the capital of {country}?",
        "How many days in {month}?",
        "What color is {object}?",
        "What year was {invention} invented?"
      ],
      2 => [
        "If {person} has {amount1} apples and buys {amount2} more, then gives away {amount3}, how many are left?",
        "A train travels {distance} km at {speed} km/h. How long does the journey take?",
        "If {workers} people can complete a job in {time} hours, how long for {new_workers} people?",
        "Calculate the area of a rectangle {length}m by {width}m, then add {extra} square meters.",
        "You invest ${principal} at {rate}% interest for {years} years. What's the final amount?"
      ],
      3 => [
        "Solve x² - {a}x + {b} = 0 using multiple methods and verify consistency.",
        "Find the limit of ({numerator})/(x² + {denominator}) as x approaches infinity using different techniques.",
        "Calculate ∫({function}) dx from {start} to {end} using multiple integration methods.",
        "Determine if the series Σ(1/(n^{power} + {constant})) converges using different tests.",
        "Find max/min of f(x,y) = {function} subject to constraint {constraint} = 0."
      ],
      4 => [
        "{company} faces {crisis} with ${budget} budget. Choose between {option1}, {option2}, {option3}. Analyze and recommend.",
        "City planning: Build {project} with ${cost} budget while balancing {interest1}, {interest2}, {interest3}.",
        "{organization} must implement {change} while maintaining {operations}. Create implementation plan.",
        "Healthcare decision: Choose {treatment1} vs {treatment2} considering {factors}. Provide recommendation.",
        "Investment strategy: Allocate ${portfolio} across {sectors} considering {risks} and {opportunities}."
      ],
      5 => [
        "AI facial recognition for missing children vs privacy rights. Address ethical concerns while considering {stakeholder1}, {stakeholder2}, {stakeholder3}.",
        "Autonomous vehicle must choose between {scenario1} and {scenario2} in emergency. Design ethical decision framework.",
        "Social media platform handling {content_issue} across cultures with different values. Balance {principle1} vs {principle2}.",
        "Resource allocation during crisis: distribute {resource} between {need1}, {need2}, {need3} fairly.",
        "AI hiring system showing bias against {group}. Fix while maintaining {requirement1} and {requirement2}."
      ],
      6 => [
        "Analyze relationship between {variable1} and {variable2} in {domain}. Design experiments, collect data, determine {relationship_type}.",
        "Build predictive model for {outcome} using {input1}, {input2}, {input3}. Compare algorithms and validate.",
        "Study {phenomenon} using computational methods. Generate hypotheses, design experiments, analyze results.",
        "Optimize {system} with constraints {constraint1}, {constraint2}. Implement multiple approaches and compare.",
        "Simulate {complex_system} behavior under {condition1}, {condition2}. Study emergent patterns."
      ],
      7 => [
        "Design innovative solution to reduce {waste_type} in {industry} while creating value for all stakeholders.",
        "Invent {technology} that revolutionizes {domain} by combining {approach1}, {approach2}, {novel_element}.",
        "Create {art_form} that teaches {concept} to {audience} using {medium1}, {medium2}, {innovation}.",
        "Design {game} that develops {skill} through {mechanic1}, {mechanic2} while maintaining engagement.",
        "Develop {platform} enabling {activity} between {group1}, {group2}, {group3} with {innovation_factor}."
      ],
      8 => [
        "Design messaging platform for {scale} users with {security}, {performance}, {reliability}. Coordinate {expert1}, {expert2}, {expert3}, {expert4}.",
        "Build {complex_system} for {critical_domain} requiring {domain1}, {domain2}, {domain3} expertise. Address {challenge1}, {challenge2}.",
        "Solve {global_problem} integrating {perspective1}, {perspective2}, {perspective3}, {perspective4} viewpoints.",
        "Create {transformation} strategy requiring {change_type1}, {change_type2}, {change_type3} coordination.",
        "Develop {innovation} combining {field1}, {field2}, {field3} to address {multifaceted_challenge}."
      ]
    }
    
    Enum.random(templates[level])
  end

  defp generate_problem(template, difficulty) do
    # Extract variables and substitute
    variables = Regex.scan(~r/\{(\w+)\}/, template, capture: :all_but_first)
                |> List.flatten()
                |> Enum.uniq()
    
    substitutions = Enum.map(variables, fn var ->
      {var, generate_value(var, difficulty)}
    end)
    
    Enum.reduce(substitutions, template, fn {var, value}, text ->
      String.replace(text, "{#{var}}", to_string(value))
    end)
  end

  defp generate_value(var, difficulty) do
    multiplier = max(1, round(difficulty))
    
    cond do
      var in ["a", "b", "amount1", "amount2", "amount3"] ->
        Enum.random(1..20) * multiplier
      
      var == "country" ->
        Enum.random(["Japan", "Brazil", "Germany", "Australia", "Canada", "India"])
      
      var == "month" ->
        Enum.random(["January", "February", "March", "April", "May", "June"])
      
      var == "object" ->
        Enum.random(["sky", "grass", "sun", "ocean", "rose", "snow"])
      
      var == "invention" ->
        Enum.random(["telephone", "computer", "airplane", "television", "internet"])
      
      var == "person" ->
        Enum.random(["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"])
      
      var in ["distance", "length", "width"] ->
        Enum.random(10..100) * multiplier
      
      var in ["speed", "rate"] ->
        Enum.random(20..80)
      
      var in ["time", "years"] ->
        Enum.random(2..10)
      
      var in ["workers", "new_workers"] ->
        Enum.random(2..12)
      
      var in ["principal", "budget", "cost", "portfolio"] ->
        amounts = [10000, 50000, 100000, 500000, 1000000]
        Enum.random(amounts) * multiplier
      
      var == "company" ->
        Enum.random(["TechCorp", "GlobalSoft", "InnovateCo", "FutureTech"])
      
      var == "crisis" ->
        Enum.random(["declining profits", "market disruption", "regulatory changes", "supply shortage"])
      
      String.contains?(var, "option") ->
        Enum.random(["cost reduction", "market expansion", "product innovation", "strategic partnership"])
      
      "organization" ->
        Enum.random(["university", "hospital", "government agency", "corporation"])
      
      "change" ->
        Enum.random(["digital transformation", "process automation", "cultural shift", "system upgrade"])
      
      "operations" ->
        Enum.random(["quality standards", "customer service", "regulatory compliance", "budget constraints"])
      
      var when String.contains?(var, "treatment") ->
        Enum.random(["surgical intervention", "medication therapy", "lifestyle changes", "monitoring protocol"])
      
      "factors" ->
        "patient age, medical history, treatment costs, success rates"
      
      var when String.contains?(var, "stakeholder") ->
        Enum.random(["parents", "privacy advocates", "law enforcement", "technology companies", "civil rights groups"])
      
      var when String.contains?(var, "scenario") ->
        Enum.random(["pedestrian safety", "passenger protection", "property damage", "traffic flow"])
      
      "content_issue" ->
        Enum.random(["hate speech", "misinformation", "political content", "cultural sensitivity"])
      
      var when String.contains?(var, "principle") ->
        Enum.random(["free speech", "user safety", "cultural respect", "platform integrity"])
      
      "resource" ->
        Enum.random(["medical supplies", "funding", "personnel", "equipment", "food aid"])
      
      var when String.contains?(var, "need") ->
        Enum.random(["emergency response", "long-term recovery", "prevention", "research", "infrastructure"])
      
      "group" ->
        Enum.random(["women", "minorities", "older workers", "recent graduates", "international candidates"])
      
      var when String.contains?(var, "requirement") ->
        Enum.random(["job relevance", "legal compliance", "efficiency", "fairness", "accuracy"])
      
      var when String.contains?(var, "variable") ->
        Enum.random(["temperature", "pressure", "concentration", "time", "frequency", "voltage"])
      
      "domain" ->
        Enum.random(["climate science", "neuroscience", "economics", "biology", "physics", "chemistry"])
      
      var when String.contains?(var, "input") ->
        Enum.random(["sensor data", "user behavior", "market conditions", "environmental factors"])
      
      "outcome" ->
        Enum.random(["system performance", "user satisfaction", "energy consumption", "success rate"])
      
      "relationship_type" ->
        Enum.random(["linear", "exponential", "logarithmic", "polynomial", "inverse"])
      
      "phenomenon" ->
        Enum.random(["neural plasticity", "market volatility", "ecosystem dynamics", "social behavior"])
      
      "system" ->
        Enum.random(["traffic network", "power grid", "supply chain", "communication system"])
      
      var when String.contains?(var, "constraint") ->
        Enum.random(["budget limit", "time deadline", "resource availability", "regulatory requirement"])
      
      "complex_system" ->
        Enum.random(["urban ecosystem", "financial market", "social network", "biological system"])
      
      var when String.contains?(var, "condition") ->
        Enum.random(["high stress", "resource scarcity", "rapid change", "external pressure"])
      
      "waste_type" ->
        Enum.random(["food waste", "plastic waste", "energy waste", "water waste", "electronic waste"])
      
      "industry" ->
        Enum.random(["restaurant", "manufacturing", "healthcare", "education", "technology"])
      
      "technology" ->
        Enum.random(["AI assistant", "renewable energy", "transportation", "communication", "medical device"])
      
      var when String.contains?(var, "approach") ->
        Enum.random(["biomimetic design", "circular economy", "collaborative platform", "adaptive system"])
      
      "novel_element" ->
        Enum.random(["quantum computing", "blockchain", "nanotechnology", "biotechnology"])
      
      "art_form" ->
        Enum.random(["interactive installation", "virtual reality", "augmented reality", "multimedia performance"])
      
      "concept" ->
        Enum.random(["sustainability", "empathy", "critical thinking", "collaboration", "innovation"])
      
      "audience" ->
        Enum.random(["children", "teenagers", "adults", "seniors", "professionals"])
      
      var when String.contains?(var, "medium") ->
        Enum.random(["visual", "auditory", "tactile", "digital", "physical"])
      
      "innovation" ->
        Enum.random(["gamification", "personalization", "social learning", "adaptive feedback"])
      
      "game" ->
        Enum.random(["puzzle game", "strategy game", "simulation", "role-playing", "cooperative game"])
      
      "skill" ->
        Enum.random(["problem-solving", "leadership", "communication", "creativity", "teamwork"])
      
      var when String.contains?(var, "mechanic") ->
        Enum.random(["progression system", "collaboration tools", "feedback loops", "challenge scaling"])
      
      "platform" ->
        Enum.random(["collaboration hub", "learning environment", "creative workspace", "innovation lab"])
      
      "activity" ->
        Enum.random(["knowledge sharing", "project collaboration", "skill development", "creative work"])
      
      var when String.contains?(var, "group") ->
        Enum.random(["researchers", "students", "professionals", "artists", "entrepreneurs"])
      
      "innovation_factor" ->
        Enum.random(["AI assistance", "blockchain verification", "VR collaboration", "real-time analytics"])
      
      "scale" ->
        scales = ["100M", "500M", "1B", "5B"]
        scale = Enum.random(scales)
        if multiplier > 1, do: "#{multiplier}#{scale}", else: scale
      
      var when String.contains?(var, "security") ->
        Enum.random(["end-to-end encryption", "zero-trust architecture", "quantum-safe crypto"])
      
      var when String.contains?(var, "performance") ->
        Enum.random(["sub-second latency", "99.99% uptime", "infinite scalability"])
      
      var when String.contains?(var, "reliability") ->
        Enum.random(["fault tolerance", "automatic recovery", "disaster resilience"])
      
      var when String.contains?(var, "expert") ->
        Enum.random(["system architect", "security specialist", "performance engineer", "reliability expert", "UX designer"])
      
      "complex_system" ->
        Enum.random(["global communication", "financial trading", "healthcare management", "education platform"])
      
      "critical_domain" ->
        Enum.random(["healthcare", "finance", "transportation", "energy", "defense"])
      
      var when String.contains?(var, "domain") ->
        Enum.random(["artificial intelligence", "cybersecurity", "data science", "cloud computing"])
      
      var when String.contains?(var, "challenge") ->
        Enum.random(["scalability", "integration", "security", "performance", "usability"])
      
      "global_problem" ->
        Enum.random(["climate change", "poverty", "disease", "inequality", "conflict"])
      
      var when String.contains?(var, "perspective") ->
        Enum.random(["scientific", "economic", "social", "political", "technological", "environmental"])
      
      "transformation" ->
        Enum.random(["digital transformation", "organizational change", "cultural evolution", "system modernization"])
      
      var when String.contains?(var, "change_type") ->
        Enum.random(["process redesign", "technology adoption", "skill development", "culture change"])
      
      var when String.contains?(var, "field") ->
        Enum.random(["artificial intelligence", "biotechnology", "nanotechnology", "quantum computing"])
      
      "multifaceted_challenge" ->
        Enum.random(["sustainable development", "aging population", "urbanization", "resource depletion"])
      
      # Default case
      _ ->
        "#{var}_#{:rand.uniform(1000)}"
    end
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
    IO.puts("🎯 Challenge ##{metrics.total + 1} | Difficulty: #{challenge.difficulty}/100")
    IO.puts("#{String.duplicate("-", 80)}")
    IO.puts("📋 PROBLEM:")
    IO.puts("#{challenge.problem}")
    IO.puts("#{String.duplicate("-", 80)}")
  end

  defp update_metrics(metrics, level) do
    new_total = metrics.total + 1
    new_level_counts = Map.update!(metrics.level_counts, level, &(&1 + 1))
    new_difficulty = calculate_difficulty_multiplier(new_total)
    
    %{
      total: new_total,
      level_counts: new_level_counts,
      difficulty_multiplier: new_difficulty,
      start_time: metrics.start_time
    }
  end

  defp calculate_difficulty_multiplier(total) do
    base = 1.0
    growth = 0.005  # 0.5% increase per challenge
    max_difficulty = 3.0
    
    new_difficulty = base + (total * growth)
    min(new_difficulty, max_difficulty)
  end

  defp display_progress(metrics) do
    elapsed = DateTime.diff(DateTime.utc_now(), metrics.start_time, :second)
    rate = if elapsed > 0, do: Float.round(metrics.total / elapsed, 2), else: 0.0
    
    IO.puts("📊 PROGRESS:")
    IO.puts("• Total Challenges: #{metrics.total}")
    IO.puts("• Difficulty Multiplier: #{Float.round(metrics.difficulty_multiplier, 2)}x")
    IO.puts("• Runtime: #{elapsed}s | Rate: #{rate} challenges/second")
    
    IO.puts("📈 LEVEL DISTRIBUTION:")
    Enum.each(1..8, fn level ->
      count = metrics.level_counts[level]
      percentage = if metrics.total > 0, do: Float.round(count / metrics.total * 100, 1), else: 0.0
      IO.puts("  Level #{level}: #{count} (#{percentage}%)")
    end)
    
    IO.puts("\n⏳ Next challenge in 3 seconds...\n")
  end
end

# Start the generator
UnlimitedSimpleChallenges.start()