Mix.install([
  {:dspy, path: "."}
])

defmodule CodeGenerationAnalysisExperiment do
  @moduledoc """
  Experiment for code generation, analysis, optimization, and debugging.
  Tests the ability to understand requirements, generate code, and improve existing code.
  """

  alias Dspy.{Module, ChainOfThought, Signature, Settings, LM}

  defmodule CodeGeneration do
    use Dspy.Signature

    field :requirements, :input,
      desc: "What the code should do"

    field :language, :input,
      desc: "Programming language to use"

    field :constraints, :input,
      desc: "Any specific constraints or patterns to follow"

    field :algorithm_design, :output,
      desc: "High-level algorithm design"

    field :code, :output,
      desc: "The generated code implementation"

    field :explanation, :output,
      desc: "How the code works"

    field :complexity, :output,
      desc: "Time and space complexity analysis"
  end

  defmodule CodeAnalysis do
    use Dspy.Signature

    field :code, :input,
      desc: "Code to analyze"

    field :focus_areas, :input,
      desc: "What aspects to analyze"

    field :issues, :output,
      desc: "Potential issues or bugs found"

    field :performance, :output,
      desc: "Performance characteristics"

    field :suggestions, :output,
      desc: "Improvement suggestions"

    field :security, :output,
      desc: "Security considerations"
  end

  defmodule CodeOptimization do
    use Dspy.Signature

    field :original_code, :input,
      desc: "Code to optimize"

    field :optimization_goals, :input,
      desc: "What to optimize for (speed, memory, readability)"

    field :optimized_code, :output,
      desc: "The optimized version"

    field :changes_made, :output,
      desc: "Specific optimizations applied"

    field :performance_gain, :output,
      desc: "Expected performance improvements"

    field :trade_offs, :output,
      desc: "Any trade-offs made"
  end

  defmodule DebugAssistant do
    use Dspy.Signature

    field :buggy_code, :input,
      desc: "Code with bugs"

    field :error_description, :input,
      desc: "Error message or unexpected behavior"

    field :expected_behavior, :input,
      desc: "What should happen"

    field :bug_analysis, :output,
      desc: "Root cause analysis"

    field :fix, :output,
      desc: "The corrected code"

    field :explanation, :output,
      desc: "Why the bug occurred and how the fix works"

    field :prevention, :output,
      desc: "How to prevent similar bugs"
  end

  def run_experiment do
    IO.puts("\n💻 Code Generation & Analysis Experiment")
    IO.puts("=" <> String.duplicate("=", 50))

    # Configure GPT-4
    configure_gpt4()

    # Test different code challenges
    challenges = [
      %{
        type: :generation,
        task: %{
          requirements: """
          Implement a function that finds all possible ways to climb stairs
          where you can take 1, 2, or 3 steps at a time. The function should
          also return the actual sequences of steps, not just the count.
          """,
          language: "Elixir",
          constraints: "Use dynamic programming with memoization"
        }
      },
      %{
        type: :analysis,
        task: %{
          code: """
          def process_data(items) do
            items
            |> Enum.map(fn item ->
              result = expensive_operation(item)
              Logger.info("Processed \#{item}")
              result
            end)
            |> Enum.filter(fn x -> x != nil end)
            |> Enum.reduce(%{}, fn item, acc ->
              Map.put(acc, item.id, item)
            end)
          end
          """,
          focus_areas: "Performance, error handling, and potential bugs"
        }
      },
      %{
        type: :optimization,
        task: %{
          original_code: """
          def find_duplicates(list) do
            duplicates = []
            Enum.each(list, fn item ->
              count = Enum.count(list, fn x -> x == item end)
              if count > 1 and item not in duplicates do
                duplicates = duplicates ++ [item]
              end
            end)
            duplicates
          end
          """,
          optimization_goals: "Time complexity and Elixir idioms"
        }
      },
      %{
        type: :debug,
        task: %{
          buggy_code: """
          def binary_search(list, target) do
            do_search(list, target, 0, length(list))
          end
          
          defp do_search(_, _, low, high) when low > high, do: -1
          defp do_search(list, target, low, high) do
            mid = div(low + high, 2)
            mid_val = Enum.at(list, mid)
            
            cond do
              mid_val == target -> mid
              mid_val < target -> do_search(list, target, mid, high)
              true -> do_search(list, target, low, mid)
            end
          end
          """,
          error_description: "Function runs infinitely for some inputs",
          expected_behavior: "Should return index of target or -1 if not found"
        }
      }
    ]

    # Process each challenge
    Enum.each(challenges, fn challenge ->
      IO.puts("\n" <> String.duplicate("-", 50))
      
      case challenge.type do
        :generation ->
          IO.puts("🔨 Code Generation Challenge")
          generate_code(challenge.task)
          
        :analysis ->
          IO.puts("🔍 Code Analysis Challenge")
          analyze_code(challenge.task)
          
        :optimization ->
          IO.puts("⚡ Code Optimization Challenge")
          optimize_code(challenge.task)
          
        :debug ->
          IO.puts("🐛 Debug Challenge")
          debug_code(challenge.task)
      end
    end)

    # Bonus: Generate test cases
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("🧪 Bonus: Test Case Generation")
    generate_test_cases()

    IO.puts("\n✅ Code generation & analysis experiment complete!")
  end

  defp configure_gpt4 do
    lm = LM.init(%{
      model: "gpt-4",
      temperature: 0.3,  # Lower temperature for code generation
      max_tokens: 2000
    })
    
    Settings.configure(%{lm: lm})
  end

  defp generate_code(task) do
    module = Module.new(%{
      generate: ChainOfThought.new(%{
        signature: CodeGeneration
      })
    })

    case Module.forward(module, %{
      generate: task
    }) do
      {:ok, result} ->
        code = result.generate
        IO.puts("\n📋 Requirements: #{String.slice(task.requirements, 0..100)}...")
        IO.puts("\n🎯 Algorithm Design:")
        IO.puts(code.algorithm_design)
        IO.puts("\n💻 Generated Code:")
        IO.puts("```#{task.language}")
        IO.puts(code.code)
        IO.puts("```")
        IO.puts("\n📖 Explanation:")
        IO.puts(code.explanation)
        IO.puts("\n📊 Complexity: #{code.complexity}")
        
      {:error, error} ->
        IO.puts("❌ Code generation failed: #{error}")
    end
  end

  defp analyze_code(task) do
    module = Module.new(%{
      analyze: ChainOfThought.new(%{
        signature: CodeAnalysis
      })
    })

    case Module.forward(module, %{
      analyze: task
    }) do
      {:ok, result} ->
        analysis = result.analyze
        IO.puts("\n💻 Analyzing Code:")
        IO.puts("```elixir")
        IO.puts(task.code)
        IO.puts("```")
        IO.puts("\n⚠️  Issues Found:")
        IO.puts(analysis.issues)
        IO.puts("\n⚡ Performance Analysis:")
        IO.puts(analysis.performance)
        IO.puts("\n💡 Suggestions:")
        IO.puts(analysis.suggestions)
        IO.puts("\n🔒 Security Considerations:")
        IO.puts(analysis.security)
        
      {:error, error} ->
        IO.puts("❌ Code analysis failed: #{error}")
    end
  end

  defp optimize_code(task) do
    module = Module.new(%{
      optimize: ChainOfThought.new(%{
        signature: CodeOptimization
      })
    })

    case Module.forward(module, %{
      optimize: task
    }) do
      {:ok, result} ->
        optimization = result.optimize
        IO.puts("\n🔧 Original Code:")
        IO.puts("```elixir")
        IO.puts(task.original_code)
        IO.puts("```")
        IO.puts("\n✨ Optimized Code:")
        IO.puts("```elixir")
        IO.puts(optimization.optimized_code)
        IO.puts("```")
        IO.puts("\n📝 Changes Made:")
        IO.puts(optimization.changes_made)
        IO.puts("\n📈 Performance Gain:")
        IO.puts(optimization.performance_gain)
        IO.puts("\n⚖️  Trade-offs:")
        IO.puts(optimization.trade_offs)
        
      {:error, error} ->
        IO.puts("❌ Code optimization failed: #{error}")
    end
  end

  defp debug_code(task) do
    module = Module.new(%{
      debug: ChainOfThought.new(%{
        signature: DebugAssistant
      })
    })

    case Module.forward(module, %{
      debug: task
    }) do
      {:ok, result} ->
        debug_info = result.debug
        IO.puts("\n🐛 Buggy Code:")
        IO.puts("```elixir")
        IO.puts(task.buggy_code)
        IO.puts("```")
        IO.puts("\n❌ Error: #{task.error_description}")
        IO.puts("\n🔍 Bug Analysis:")
        IO.puts(debug_info.bug_analysis)
        IO.puts("\n✅ Fixed Code:")
        IO.puts("```elixir")
        IO.puts(debug_info.fix)
        IO.puts("```")
        IO.puts("\n📖 Explanation:")
        IO.puts(debug_info.explanation)
        IO.puts("\n🛡️  Prevention Tips:")
        IO.puts(debug_info.prevention)
        
      {:error, error} ->
        IO.puts("❌ Debug assistance failed: #{error}")
    end
  end

  defp generate_test_cases do
    test_gen_signature = Signature.define("""
    generate_tests(function_code: str, function_purpose: str) -> 
      test_cases: str,
      edge_cases: str,
      property_tests: str
    """)

    module = Module.new(%{
      test_gen: ChainOfThought.new(%{
        signature: test_gen_signature
      })
    })

    sample_function = """
    def merge_intervals(intervals) do
      intervals
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce([], fn {start, finish}, acc ->
        case acc do
          [] -> [{start, finish}]
          [{last_start, last_end} | rest] ->
            if start <= last_end do
              [{last_start, max(finish, last_end)} | rest]
            else
              [{start, finish} | acc]
            end
        end
      end)
      |> Enum.reverse()
    end
    """

    case Module.forward(module, %{
      test_gen: %{
        function_code: sample_function,
        function_purpose: "Merge overlapping intervals into non-overlapping intervals"
      }
    }) do
      {:ok, result} ->
        tests = result.test_gen
        IO.puts("\n📝 Function to Test:")
        IO.puts("```elixir")
        IO.puts(sample_function)
        IO.puts("```")
        IO.puts("\n🧪 Test Cases:")
        IO.puts(tests.test_cases)
        IO.puts("\n🔧 Edge Cases:")
        IO.puts(tests.edge_cases)
        IO.puts("\n🎲 Property-Based Tests:")
        IO.puts(tests.property_tests)
        
      {:error, error} ->
        IO.puts("❌ Test generation failed: #{error}")
    end
  end
end

# Run the experiment
CodeGenerationAnalysisExperiment.run_experiment()