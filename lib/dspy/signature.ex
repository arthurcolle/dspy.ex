defmodule Dspy.Signature do
  @moduledoc """
  Define typed input/output interfaces for language model calls.
  
  Signatures specify the expected inputs and outputs for DSPy modules,
  including field types, descriptions, and validation rules.
  """

  defstruct [:name, :description, :input_fields, :output_fields, :instructions]

  @type field :: %{
    name: atom(),
    type: atom(),
    description: String.t(),
    required: boolean(),
    default: any()
  }

  @type t :: %__MODULE__{
    name: String.t(),
    description: String.t() | nil,
    input_fields: [field()],
    output_fields: [field()],
    instructions: String.t() | nil
  }

  @doc """
  Create a new signature.
  """
  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      description: Keyword.get(opts, :description),
      input_fields: Keyword.get(opts, :input_fields, []),
      output_fields: Keyword.get(opts, :output_fields, []),
      instructions: Keyword.get(opts, :instructions)
    }
  end

  @doc """
  Generate a prompt template from the signature.
  """
  def to_prompt(signature, examples \\ []) do
    sections = [
      instruction_section(signature),
      field_descriptions_section(signature),
      examples_section(examples, signature),
      input_section(signature)
    ]

    sections
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  @doc """
  Validate inputs against the signature.
  """
  def validate_inputs(signature, inputs) do
    required_fields = 
      signature.input_fields
      |> Enum.filter(& &1.required)
      |> Enum.map(& &1.name)

    missing_fields = required_fields -- Map.keys(inputs)

    case missing_fields do
      [] -> :ok
      missing -> {:error, {:missing_fields, missing}}
    end
  end

  @doc """
  Parse outputs according to the signature.
  """
  def parse_outputs(signature, text) do
    output_fields = signature.output_fields
    
    output_fields
    |> Enum.reduce(%{}, fn field, acc ->
      case extract_field_value(text, field) do
        {:ok, value} -> Map.put(acc, field.name, value)
        :error -> acc
      end
    end)
  end

  defp instruction_section(%{instructions: nil}), do: nil
  defp instruction_section(%{instructions: instructions}) do
    "Instructions: #{instructions}"
  end

  defp field_descriptions_section(signature) do
    input_desc = describe_fields("Input", signature.input_fields)
    output_desc = describe_fields("Output", signature.output_fields)
    
    [input_desc, output_desc]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp describe_fields(_label, []), do: nil
  defp describe_fields(label, fields) do
    field_lines = 
      fields
      |> Enum.map(fn field ->
        "- #{field.name}: #{field.description}"
      end)
      |> Enum.join("\n")
      
    "#{label} Fields:\n#{field_lines}"
  end

  defp examples_section([], _signature), do: nil
  defp examples_section(examples, signature) do
    example_text = 
      examples
      |> Enum.with_index(1)
      |> Enum.map(fn {example, idx} ->
        format_example(example, signature, idx)
      end)
      |> Enum.join("\n\n")
      
    "Examples:\n\n#{example_text}"
  end

  defp format_example(example, signature, idx) do
    input_text = format_fields(example, signature.input_fields)
    output_text = format_fields(example, signature.output_fields)
    
    "Example #{idx}:\n#{input_text}\n#{output_text}"
  end

  defp format_fields(example, fields) do
    fields
    |> Enum.map(fn field ->
      value = Map.get(example.attrs || example, field.name, "")
      "#{String.capitalize(Atom.to_string(field.name))}: #{value}"
    end)
    |> Enum.join("\n")
  end

  defp input_section(signature) do
    placeholder_inputs = 
      signature.input_fields
      |> Enum.map(fn field ->
        "#{String.capitalize(Atom.to_string(field.name))}: [input]"
      end)
      |> Enum.join("\n")
      
    output_labels = 
      signature.output_fields
      |> Enum.map(fn field ->
        "#{String.capitalize(Atom.to_string(field.name))}:"
      end)
      |> Enum.join("\n")
      
    "#{placeholder_inputs}\n#{output_labels}"
  end

  defp extract_field_value(text, field) do
    field_name = String.capitalize(Atom.to_string(field.name))
    pattern = ~r/#{field_name}:\s*(.+?)(?=\n[A-Z][a-z]*:|$)/s
    
    case Regex.run(pattern, text, capture: :all_but_first) do
      [value] -> {:ok, String.trim(value)}
      nil -> :error
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Dspy.Signature.DSL

      Module.register_attribute(__MODULE__, :input_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :output_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :signature_description, [])
      Module.register_attribute(__MODULE__, :signature_instructions, [])

      @before_compile Dspy.Signature.DSL
    end
  end
end