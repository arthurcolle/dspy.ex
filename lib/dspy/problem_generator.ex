defmodule Dspy.ProblemGenerator do
  @moduledoc """
  Generates random problems for DSPy examples
  """

  @doc """
  Generate a random math word problem
  """
  def generate_math_problem do
    templates = [
      fn -> discount_tax_problem() end,
      fn -> fraction_problem() end,
      fn -> percentage_problem() end,
      fn -> compound_interest_problem() end,
      fn -> mixture_problem() end
    ]

    Enum.random(templates).()
  end

  @doc """
  Generate a random logical reasoning problem
  """
  def generate_logic_problem do
    templates = [
      fn -> syllogism_problem() end,
      fn -> conditional_problem() end,
      fn -> set_problem() end,
      fn -> paradox_problem() end
    ]

    Enum.random(templates).()
  end

  @doc """
  Generate a random coding task
  """
  def generate_coding_task do
    templates = [
      fn -> algorithm_task() end,
      fn -> data_structure_task() end,
      fn -> string_manipulation_task() end,
      fn -> validation_task() end
    ]

    Enum.random(templates).()
  end

  @doc """
  Generate a random algorithm task
  """
  def generate_algorithm_task do
    templates = [
      fn -> prime_calculation_task() end,
      fn -> fibonacci_task() end,
      fn -> sorting_task() end,
      fn -> search_task() end
    ]

    Enum.random(templates).()
  end

  # Private helper functions for math problems
  defp discount_tax_problem do
    price = Enum.random(50..500)
    discount = Enum.random(5..30)
    tax = Enum.random(5..15)

    "A store offers a #{discount}% discount on a $#{price} item, then adds #{tax}% sales tax. What's the final price?"
  end

  defp fraction_problem do
    num1 = Enum.random(1..20)
    den1 = Enum.random(2..10)
    num2 = Enum.random(1..20)
    den2 = Enum.random(2..10)
    operation = Enum.random(["add", "subtract", "multiply"])

    "Calculate: #{num1}/#{den1} #{operation} #{num2}/#{den2}. Express your answer as a decimal."
  end

  defp percentage_problem do
    total = Enum.random(100..1000)
    percent1 = Enum.random(10..40)
    percent2 = Enum.random(10..30)

    "A company has #{total} employees. #{percent1}% work in sales and #{percent2}% work in marketing. How many employees work in other departments?"
  end

  defp compound_interest_problem do
    principal = Enum.random(1000..10000)
    rate = Enum.random(2..8)
    years = Enum.random(2..5)

    "Calculate the compound interest on $#{principal} invested at #{rate}% annual interest for #{years} years, compounded annually."
  end

  defp mixture_problem do
    quantity1 = Enum.random(2..10)
    concentration1 = Enum.random(10..40)
    quantity2 = Enum.random(2..10)
    concentration2 = Enum.random(50..90)

    "Mix #{quantity1} liters of #{concentration1}% solution with #{quantity2} liters of #{concentration2}% solution. What's the concentration of the resulting mixture?"
  end

  # Private helper functions for logic problems
  defp syllogism_problem do
    subjects = ["dogs", "cats", "birds", "fish", "reptiles", "mammals", "insects"]

    properties = [
      "can fly",
      "are nocturnal",
      "live in water",
      "have fur",
      "lay eggs",
      "are carnivorous",
      "are warm-blooded"
    ]

    subject1 = Enum.random(subjects)
    subject2 = Enum.random(subjects -- [subject1])
    property = Enum.random(properties)

    "All #{subject1} #{property}. Some #{subject2} are #{subject1}. Therefore, some #{subject2} #{property}. Is this reasoning valid?"
  end

  defp conditional_problem do
    conditions = [
      "If it rains, the ground gets wet. The ground is wet.",
      "If a number is prime, it has no divisors other than 1 and itself. 15 has divisors other than 1 and itself.",
      "If you study hard, you will pass the exam. You didn't pass the exam.",
      "If all swans are white, then a black bird cannot be a swan. We found a black swan."
    ]

    problem = Enum.random(conditions)
    "#{problem} What can we conclude?"
  end

  defp set_problem do
    total = Enum.random(50..200)
    set_a = Enum.random(20..80)
    set_b = Enum.random(20..80)
    both = Enum.random(5..(min(set_a, set_b) - 5))

    "In a group of #{total} people, #{set_a} like coffee, #{set_b} like tea, and #{both} like both. How many like neither?"
  end

  defp paradox_problem do
    paradoxes = [
      "A barber shaves all those who do not shave themselves. Who shaves the barber?",
      "This statement is false. Is the statement true or false?",
      "If a crocodile steals a child and promises to return it if the parent correctly guesses what the crocodile will do, what happens if the parent says 'You will not return my child'?",
      "Can an omnipotent being create a stone so heavy that they cannot lift it?"
    ]

    Enum.random(paradoxes) <> " Analyze this paradox."
  end

  # Private helper functions for coding tasks
  defp algorithm_task do
    algorithms = [
      "implement a function to find the nth Fibonacci number using dynamic programming",
      "create a function to check if a string is a palindrome, ignoring spaces and punctuation",
      "write a function to find all prime factors of a given number",
      "implement binary search for a sorted array",
      "create a function to reverse a linked list"
    ]

    Enum.random(algorithms)
  end

  defp data_structure_task do
    tasks = [
      "implement a stack using two queues",
      "create a binary search tree with insert and search operations",
      "design a LRU (Least Recently Used) cache with get and put operations",
      "implement a min heap with insert and extract operations",
      "create a hash table with collision handling"
    ]

    Enum.random(tasks)
  end

  defp string_manipulation_task do
    tasks = [
      "write a function to find the longest common subsequence of two strings",
      "implement a function to compress a string using run-length encoding",
      "create a function to find all anagrams of a word in a list of words",
      "write a function to convert Roman numerals to integers",
      "implement a function to validate and parse IP addresses"
    ]

    Enum.random(tasks)
  end

  defp validation_task do
    tasks = [
      "create a function to validate email addresses with proper error handling",
      "implement a password strength checker with specific requirements",
      "write a function to validate credit card numbers using the Luhn algorithm",
      "create a function to validate and parse JSON without using built-in parsers",
      "implement a URL validator that checks protocol, domain, and path"
    ]

    Enum.random(tasks)
  end

  # Private helper functions for algorithm tasks
  defp prime_calculation_task do
    n = Enum.random(3..10)
    operations = ["sum", "product", "sum of squares", "alternating sum"]
    operation = Enum.random(operations)

    "Calculate the #{operation} of the first #{n} prime numbers"
  end

  defp fibonacci_task do
    n = Enum.random(10..25)

    variations = [
      "Find the #{n}th Fibonacci number",
      "Calculate the sum of the first #{n} Fibonacci numbers",
      "Find all even Fibonacci numbers less than #{n * 100}",
      "Calculate the ratio of the #{n}th to #{n - 1}th Fibonacci number"
    ]

    Enum.random(variations)
  end

  defp sorting_task do
    size = Enum.random(5..15)

    constraints = [
      "sort an array of #{size} integers in ascending order",
      "sort an array of #{size} strings by length, then alphabetically",
      "sort an array of #{size} numbers, but keep even numbers before odd numbers",
      "implement a stable sort for an array of #{size} elements with custom comparison"
    ]

    Enum.random(constraints)
  end

  defp search_task do
    size = Enum.random(10..50)

    targets = [
      "find the two numbers in an array of #{size} elements that sum to a target value",
      "find the kth largest element in an unsorted array of #{size} elements",
      "find the longest increasing subsequence in an array of #{size} elements",
      "find all triplets in an array of #{size} elements that sum to zero"
    ]

    Enum.random(targets)
  end
end
