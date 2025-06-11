Mix.install([
  {:dspy, path: "."}
])

defmodule MultiHopReasoningExperiment do
  @moduledoc """
  Experiment demonstrating complex multi-hop reasoning where conclusions
  depend on chaining multiple inference steps together.
  """

  alias Dspy.{Module, ChainOfThought, Signature, Settings, LM}

  defmodule FactExtraction do
    use Dspy.Signature

    field :context, :input,
      desc: "Text containing multiple related facts"

    field :facts, :output,
      desc: "List of extracted facts numbered 1, 2, 3..."

    field :relationships, :output,
      desc: "How the facts relate to each other"
  end

  defmodule InferenceStep do
    use Dspy.Signature

    field :facts, :input,
      desc: "Known facts from previous steps"

    field :question, :input,
      desc: "What we need to determine"

    field :inference, :output,
      desc: "Logical inference from the facts"

    field :new_fact, :output,
      desc: "New fact derived from inference"

    field :confidence, :output,
      desc: "Confidence in this inference (1-10)"
  end

  defmodule FinalConclusion do
    use Dspy.Signature

    field :all_facts, :input,
      desc: "All facts including derived ones"

    field :original_question, :input,
      desc: "The original question to answer"

    field :reasoning_chain, :output,
      desc: "Step-by-step reasoning chain"

    field :conclusion, :output,
      desc: "Final answer to the question"

    field :assumptions, :output,
      desc: "Any assumptions made"
  end

  def run_experiment do
    IO.puts("\n🔗 Multi-Hop Reasoning Experiment")
    IO.puts("=" <> String.duplicate("=", 50))

    # Configure GPT-4
    configure_gpt4()

    # Test scenarios requiring multi-hop reasoning
    scenarios = [
      %{
        context: """
        The museum is open from 9 AM to 5 PM on weekdays.
        Sarah works at the bank from 9 AM to 6 PM Monday through Friday.
        The bank is closed on weekends and holidays.
        Tomorrow is Saturday.
        The museum has extended hours until 8 PM on weekends.
        Sarah wants to visit the museum tomorrow.
        """,
        question: "What time can Sarah visit the museum tomorrow, and for how long?"
      },
      %{
        context: """
        All birds in the sanctuary can fly except penguins.
        Penguins are excellent swimmers.
        Charlie is a bird in the sanctuary who cannot swim.
        Birds that can fly need special permits to leave the sanctuary.
        Swimming birds have access to the pond area.
        The sanctuary has three zones: sky zone, land zone, and water zone.
        """,
        question: "Which zones can Charlie access and does Charlie need a permit to leave?"
      },
      %{
        context: """
        In the programming competition, Team A finished before Team B.
        Team C finished after Team D but before Team E.
        Team B finished before Team D.
        There were exactly 5 teams in the competition.
        The winning team gets a gold trophy.
        The last place team must organize next year's event.
        """,
        question: "Which team won the gold trophy and which team must organize next year's event?"
      },
      %{
        context: """
        The library charges $2 per day for overdue books.
        Maximum fine per book is $20.
        John borrowed 3 books on January 1st for a 2-week loan.
        Today is January 25th.
        One of John's books was renewed for another 2 weeks on January 14th.
        Renewed books reset their due date from the renewal date.
        """,
        question: "How much does John owe in fines today?"
      }
    ]

    Enum.each(scenarios, &process_scenario/1)

    IO.puts("\n✅ Multi-hop reasoning experiment complete!")
  end

  defp configure_gpt4 do
    lm = LM.init(%{
      model: "gpt-4",
      temperature: 0.2,  # Lower temperature for logical reasoning
      max_tokens: 1500
    })
    
    Settings.configure(%{lm: lm})
  end

  defp process_scenario(scenario) do
    IO.puts("\n" <> String.duplicate("-", 50))
    IO.puts("📚 Context:")
    IO.puts(scenario.context)
    IO.puts("\n❓ Question: #{scenario.question}")
    IO.puts("\n🔍 Starting multi-hop reasoning...\n")

    # Step 1: Extract facts
    facts_result = extract_facts(scenario.context)
    
    if facts_result do
      IO.puts("📋 Extracted Facts:")
      IO.puts(facts_result.facts)
      IO.puts("\n🔗 Relationships:")
      IO.puts(facts_result.relationships)

      # Step 2: Perform multiple inference steps
      {derived_facts, inference_chain} = perform_inferences(
        facts_result.facts,
        scenario.question
      )

      # Step 3: Draw final conclusion
      conclusion = draw_conclusion(
        facts_result.facts <> "\n\nDerived facts:\n" <> derived_facts,
        scenario.question,
        inference_chain
      )

      if conclusion do
        IO.puts("\n🎯 Final Conclusion:")
        IO.puts(conclusion.conclusion)
        IO.puts("\n📊 Reasoning Chain:")
        IO.puts(conclusion.reasoning_chain)
        
        if conclusion.assumptions && String.length(conclusion.assumptions) > 0 do
          IO.puts("\n⚠️  Assumptions:")
          IO.puts(conclusion.assumptions)
        end
      end
    end
  end

  defp extract_facts(context) do
    module = Module.new(%{
      extract: ChainOfThought.new(%{
        signature: FactExtraction
      })
    })

    case Module.forward(module, %{
      extract: %{context: context}
    }) do
      {:ok, result} -> result.extract
      {:error, error} ->
        IO.puts("❌ Fact extraction failed: #{error}")
        nil
    end
  end

  defp perform_inferences(facts, question, max_hops \\ 4) do
    inference_module = Module.new(%{
      infer: ChainOfThought.new(%{
        signature: InferenceStep
      })
    })

    # Perform multiple inference hops
    {derived_facts, chain} = Enum.reduce(1..max_hops, {[], []}, fn hop, {facts_acc, chain_acc} ->
      all_facts = facts <> "\n" <> Enum.join(facts_acc, "\n")
      
      IO.puts("\n🔄 Inference Hop #{hop}:")
      
      case Module.forward(inference_module, %{
        infer: %{
          facts: all_facts,
          question: question
        }
      }) do
        {:ok, result} ->
          inference = result.infer
          
          if inference.confidence && confidence_high_enough?(inference.confidence) do
            IO.puts("   💡 Inference: #{inference.inference}")
            IO.puts("   📌 New fact: #{inference.new_fact}")
            IO.puts("   📊 Confidence: #{inference.confidence}")
            
            {facts_acc ++ [inference.new_fact], chain_acc ++ [inference.inference]}
          else
            IO.puts("   🔚 No more high-confidence inferences")
            {facts_acc, chain_acc}
          end
          
        {:error, _} ->
          IO.puts("   ⚠️  Inference failed")
          {facts_acc, chain_acc}
      end
    end)

    {Enum.join(derived_facts, "\n"), Enum.join(chain, " → ")}
  end

  defp confidence_high_enough?(confidence_str) do
    case Integer.parse(confidence_str) do
      {conf, _} -> conf >= 7
      _ -> false
    end
  end

  defp draw_conclusion(all_facts, question, inference_chain) do
    module = Module.new(%{
      conclude: ChainOfThought.new(%{
        signature: FinalConclusion
      })
    })

    case Module.forward(module, %{
      conclude: %{
        all_facts: all_facts,
        original_question: question,
        reasoning_chain: inference_chain
      }
    }) do
      {:ok, result} -> result.conclude
      {:error, error} ->
        IO.puts("❌ Conclusion failed: #{error}")
        nil
    end
  end
end

# Run the experiment
MultiHopReasoningExperiment.run_experiment()