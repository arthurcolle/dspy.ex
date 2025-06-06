defmodule Dspy.Signature.DSL do
  @moduledoc """
  DSL for defining DSPy signatures using macros.
  """

  @doc """
  Define a field for the signature.
  """
  defmacro field(name, direction, opts \\ []) do
    quote do
      field_spec = %{
        name: unquote(name),
        type: :string,
        description: Keyword.get(unquote(opts), :desc, ""),
        required: Keyword.get(unquote(opts), :required, true),
        default: Keyword.get(unquote(opts), :default)
      }
      
      case unquote(direction) do
        :input ->
          @input_fields field_spec
        :output ->
          @output_fields field_spec
      end
    end
  end

  @doc """
  Define an input field for the signature.
  """
  defmacro input_field(name, type, description \\ "", opts \\ []) do
    quote do
      @input_fields %{
        name: unquote(name),
        type: unquote(type),
        description: unquote(description),
        required: Keyword.get(unquote(opts), :required, true),
        default: Keyword.get(unquote(opts), :default)
      }
    end
  end

  @doc """
  Define an output field for the signature.
  """
  defmacro output_field(name, type, description \\ "", opts \\ []) do
    quote do
      @output_fields %{
        name: unquote(name),
        type: unquote(type),
        description: unquote(description),
        required: Keyword.get(unquote(opts), :required, true),
        default: Keyword.get(unquote(opts), :default)
      }
    end
  end

  @doc """
  Set the signature description.
  """
  defmacro signature_description(desc) do
    quote do
      @signature_description unquote(desc)
    end
  end

  @doc """
  Set signature instructions.
  """
  defmacro signature_instructions(instructions) do
    quote do
      @signature_instructions unquote(instructions)
    end
  end

  defmacro __before_compile__(env) do
    input_fields = Module.get_attribute(env.module, :input_fields) |> Enum.reverse()
    output_fields = Module.get_attribute(env.module, :output_fields) |> Enum.reverse()
    description = Module.get_attribute(env.module, :signature_description)
    instructions = Module.get_attribute(env.module, :signature_instructions)

    quote do
      def signature do
        Dspy.Signature.new(
          Atom.to_string(__MODULE__),
          description: unquote(description),
          input_fields: unquote(Macro.escape(input_fields)),
          output_fields: unquote(Macro.escape(output_fields)),
          instructions: unquote(instructions)
        )
      end

      def new do
        signature()
      end

      def input_fields, do: unquote(Macro.escape(input_fields))
      def output_fields, do: unquote(Macro.escape(output_fields))
    end
  end
end
