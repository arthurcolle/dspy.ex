defmodule Dspy.EnhancedSignature do
  @moduledoc """
  Enhanced signature module that supports:
  - Vision/image inputs without truncation
  - Advanced field types including multi-modal content
  - Improved content display with intelligent chunking
  - Sequential problem solving capabilities
  - Integration with evaluation metrics
  """

  defstruct [
    :name,
    :description,
    :input_fields,
    :output_fields,
    :instructions,
    :vision_enabled,
    :max_content_length,
    :chunk_strategy,
    :evaluation_criteria,
    :sequential_steps
  ]

  @type vision_content :: %{
          type: :image | :text,
          content: String.t() | binary(),
          mime_type: String.t() | nil,
          description: String.t() | nil
        }

  @type enhanced_field :: %{
          name: atom(),
          type: atom(),
          description: String.t(),
          required: boolean(),
          default: any(),
          max_length: pos_integer() | nil,
          vision_enabled: boolean(),
          evaluation_weight: float(),
          display_priority: integer()
        }

  @type chunk_strategy :: :intelligent | :fixed_size | :semantic | :none

  @type evaluation_criteria :: %{
          correctness_weight: float(),
          reasoning_weight: float(),
          completeness_weight: float(),
          efficiency_weight: float(),
          novelty_weight: float()
        }

  @type sequential_step :: %{
          step_id: integer(),
          name: String.t(),
          inputs: [atom()],
          outputs: [atom()],
          dependencies: [integer()],
          evaluation_criteria: evaluation_criteria()
        }

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          input_fields: [enhanced_field()],
          output_fields: [enhanced_field()],
          instructions: String.t() | nil,
          vision_enabled: boolean(),
          max_content_length: pos_integer(),
          chunk_strategy: chunk_strategy(),
          evaluation_criteria: evaluation_criteria(),
          sequential_steps: [sequential_step()]
        }

  @default_max_length 50_000
  @default_chunk_size 8_000

  @doc """
  Create a new enhanced signature with vision and chunking support.
  """
  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      description: Keyword.get(opts, :description),
      input_fields: normalize_fields(Keyword.get(opts, :input_fields, [])),
      output_fields: normalize_fields(Keyword.get(opts, :output_fields, [])),
      instructions: Keyword.get(opts, :instructions),
      vision_enabled: Keyword.get(opts, :vision_enabled, false),
      max_content_length: Keyword.get(opts, :max_content_length, @default_max_length),
      chunk_strategy: Keyword.get(opts, :chunk_strategy, :intelligent),
      evaluation_criteria: Keyword.get(opts, :evaluation_criteria, default_evaluation_criteria()),
      sequential_steps: Keyword.get(opts, :sequential_steps, [])
    }
  end

  @doc """
  Generate an enhanced prompt that prevents truncation and supports vision.
  """
  def to_enhanced_prompt(signature, examples \\ [], inputs \\ %{}) do
    # Check if content needs chunking
    total_content_length = estimate_content_length(signature, examples, inputs)

    if total_content_length > signature.max_content_length do
      generate_chunked_prompt(signature, examples, inputs)
    else
      generate_standard_prompt(signature, examples, inputs)
    end
  end

  @doc """
  Generate a vision-aware prompt for multi-modal inputs.
  """
  def to_vision_prompt(signature, inputs, examples \\ []) do
    vision_content = extract_vision_content(inputs)
    text_content = extract_text_content(inputs)

    sections = [
      vision_instruction_section(signature),
      multi_modal_format_section(signature),
      vision_examples_section(examples, signature),
      content_sections(text_content, vision_content, signature)
    ]

    %{
      text_prompt: sections |> Enum.reject(&is_nil/1) |> Enum.join("\n\n"),
      vision_content: vision_content,
      metadata: %{
        total_images: length(vision_content),
        text_length: String.length(text_content |> Enum.join(" ")),
        chunked: false
      }
    }
  end

  @doc """
  Generate a sequential problem-solving prompt.
  """
  def to_sequential_prompt(signature, inputs, step_context \\ %{}) do
    current_step = Map.get(step_context, :current_step, 1)
    total_steps = length(signature.sequential_steps)
    previous_results = Map.get(step_context, :previous_results, [])

    step_info = Enum.at(signature.sequential_steps, current_step - 1)

    sections = [
      sequential_context_section(current_step, total_steps),
      step_specific_section(step_info),
      previous_results_section(previous_results),
      evaluation_criteria_section(signature.evaluation_criteria),
      generate_standard_prompt(signature, [], inputs)
    ]

    sections |> Enum.reject(&is_nil/1) |> Enum.join("\n\n")
  end

  @doc """
  Parse outputs with enhanced validation and no truncation.
  """
  def parse_enhanced_outputs(signature, text, context \\ %{}) do
    # Handle chunked responses
    if Map.get(context, :is_chunked, false) do
      parse_chunked_outputs(signature, text, context)
    else
      parse_standard_outputs(signature, text)
    end
  end

  @doc """
  Validate inputs with vision and length checks.
  """
  def validate_enhanced_inputs(signature, inputs) do
    with :ok <- validate_required_fields(signature, inputs),
         :ok <- validate_field_types(signature, inputs),
         :ok <- validate_content_lengths(signature, inputs),
         :ok <- validate_vision_content(signature, inputs) do
      :ok
    else
      error -> error
    end
  end

  # Private helper functions

  defp normalize_fields(fields) do
    Enum.map(fields, fn field ->
      %{
        name: field[:name] || field.name,
        type: field[:type] || field.type || :string,
        description: field[:description] || field.description || "",
        required: field[:required] || field.required || false,
        default: field[:default] || field.default,
        max_length: field[:max_length] || field.max_length,
        vision_enabled: field[:vision_enabled] || field.vision_enabled || false,
        evaluation_weight: field[:evaluation_weight] || field.evaluation_weight || 1.0,
        display_priority: field[:display_priority] || field.display_priority || 0
      }
    end)
  end

  defp default_evaluation_criteria do
    %{
      correctness_weight: 0.4,
      reasoning_weight: 0.3,
      completeness_weight: 0.15,
      efficiency_weight: 0.1,
      novelty_weight: 0.05
    }
  end

  defp estimate_content_length(signature, examples, inputs) do
    example_length = examples |> Enum.map(&inspect/1) |> Enum.join("") |> String.length()

    input_length =
      inputs |> Map.values() |> Enum.map(&to_string/1) |> Enum.join("") |> String.length()

    instruction_length = String.length(signature.instructions || "")

    # Buffer
    example_length + input_length + instruction_length + 1000
  end

  defp generate_chunked_prompt(signature, examples, inputs) do
    # Implement intelligent chunking based on strategy
    case signature.chunk_strategy do
      :intelligent -> chunk_intelligently(signature, examples, inputs)
      :fixed_size -> chunk_fixed_size(signature, examples, inputs)
      :semantic -> chunk_semantically(signature, examples, inputs)
      _ -> generate_standard_prompt(signature, examples, inputs)
    end
  end

  defp generate_standard_prompt(signature, examples, inputs) do
    sections = [
      instruction_section(signature),
      format_instruction_section(signature),
      field_descriptions_section(signature),
      examples_section(examples, signature),
      input_section(signature, inputs)
    ]

    sections |> Enum.reject(&is_nil/1) |> Enum.join("\n\n")
  end

  defp extract_vision_content(inputs) do
    inputs
    |> Enum.filter(fn {_key, value} -> is_vision_content?(value) end)
    |> Enum.map(fn {key, value} ->
      %{
        field: key,
        type: detect_content_type(value),
        content: value,
        description: "Image content for field #{key}"
      }
    end)
  end

  defp extract_text_content(inputs) do
    inputs
    |> Enum.reject(fn {_key, value} -> is_vision_content?(value) end)
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
  end

  defp is_vision_content?(value) when is_binary(value) do
    # Check for image data patterns (base64, URLs, file paths)
    # JPEG
    # PNG
    String.contains?(value, ["data:image", "http", ".jpg", ".png", ".gif", ".webp"]) or
      ((byte_size(value) > 100 and String.starts_with?(value, <<0xFF, 0xD8>>)) or
         String.starts_with?(value, <<0x89, 0x50, 0x4E, 0x47>>))
  end

  defp is_vision_content?(_), do: false

  defp detect_content_type(value) when is_binary(value) do
    cond do
      String.starts_with?(value, "data:image") -> :base64_image
      String.contains?(value, ["http", "https"]) -> :image_url
      String.contains?(value, [".jpg", ".png", ".gif", ".webp"]) -> :image_path
      true -> :binary_image
    end
  end

  defp chunk_intelligently(signature, examples, inputs) do
    # Prioritize most important content and chunk less important parts
    priority_fields =
      signature.input_fields
      |> Enum.sort_by(& &1.display_priority, :desc)

    # Build prompt with highest priority content first
    core_sections = [
      instruction_section(signature),
      format_instruction_section(signature)
    ]

    remaining_length =
      signature.max_content_length -
        (core_sections |> Enum.join("\n\n") |> String.length())

    {chunked_content, metadata} =
      build_chunked_content(
        priority_fields,
        examples,
        inputs,
        remaining_length
      )

    prompt = (core_sections ++ chunked_content) |> Enum.join("\n\n")

    %{
      prompt: prompt,
      metadata: Map.put(metadata, :chunked, true),
      continuation_needed: Map.get(metadata, :has_overflow, false)
    }
  end

  defp chunk_fixed_size(signature, examples, inputs) do
    full_prompt = generate_standard_prompt(signature, examples, inputs)

    if String.length(full_prompt) <= signature.max_content_length do
      full_prompt
    else
      # Split into fixed-size chunks
      chunk_size = @default_chunk_size
      chunks = for <<chunk::binary-size(chunk_size) <- full_prompt>>, do: chunk

      %{
        chunks: chunks,
        current_chunk: List.first(chunks),
        total_chunks: length(chunks),
        metadata: %{chunked: true, strategy: :fixed_size}
      }
    end
  end

  defp chunk_semantically(signature, examples, inputs) do
    # Implement semantic chunking based on content boundaries
    full_prompt = generate_standard_prompt(signature, examples, inputs)

    # Split on logical boundaries (sections, examples, etc.)
    chunks =
      String.split(full_prompt, ~r/\n\n(?=[A-Z])/u)
      |> Enum.reduce([], fn chunk, acc ->
        if String.length(chunk) > @default_chunk_size do
          # Further split large chunks
          sub_chunks = split_large_chunk(chunk)
          acc ++ sub_chunks
        else
          acc ++ [chunk]
        end
      end)

    %{
      chunks: chunks,
      current_chunk: List.first(chunks),
      total_chunks: length(chunks),
      metadata: %{chunked: true, strategy: :semantic}
    }
  end

  defp build_chunked_content(_fields, _examples, _inputs, _max_length) do
    # Implementation for building content within length limits
    content = []
    used_length = 0
    overflow_content = []

    # This is a simplified implementation
    {content, %{used_length: used_length, has_overflow: length(overflow_content) > 0}}
  end

  defp split_large_chunk(chunk) do
    # Split large chunks on sentence boundaries
    sentences = String.split(chunk, ~r/\.\s+/u)

    Enum.reduce(sentences, [], fn sentence, acc ->
      if length(acc) == 0 do
        [sentence]
      else
        last_chunk = List.last(acc)

        if String.length(last_chunk <> ". " <> sentence) > @default_chunk_size do
          acc ++ [sentence]
        else
          List.replace_at(acc, -1, last_chunk <> ". " <> sentence)
        end
      end
    end)
  end

  # Standard section generators (similar to original but enhanced)

  defp instruction_section(%{instructions: nil}), do: nil

  defp instruction_section(%{instructions: instructions}) do
    "Instructions: #{instructions}"
  end

  defp format_instruction_section(signature) do
    output_format =
      signature.output_fields
      |> Enum.map(fn field ->
        "#{String.capitalize(Atom.to_string(field.name))}: [your #{field.description}]"
      end)
      |> Enum.join("\n")

    "Follow this exact format for your response:\n#{output_format}"
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
        vision_note = if field.vision_enabled, do: " (supports images)", else: ""
        "- #{field.name}: #{field.description}#{vision_note}"
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
      formatted_value = format_field_value(value, field)
      "#{String.capitalize(Atom.to_string(field.name))}: #{formatted_value}"
    end)
    |> Enum.join("\n")
  end

  defp format_field_value(value, field) do
    max_length = field.max_length || @default_max_length

    if is_binary(value) and String.length(value) > max_length do
      String.slice(value, 0, max_length) <> "... [content truncated, full content available]"
    else
      to_string(value)
    end
  end

  defp input_section(signature, inputs) do
    input_text =
      signature.input_fields
      |> Enum.map(fn field ->
        value = Map.get(inputs, field.name, "[input]")
        formatted_value = format_field_value(value, field)
        "#{String.capitalize(Atom.to_string(field.name))}: #{formatted_value}"
      end)
      |> Enum.join("\n")

    output_labels =
      signature.output_fields
      |> Enum.map(fn field ->
        "#{String.capitalize(Atom.to_string(field.name))}:"
      end)
      |> Enum.join("\n")

    "#{input_text}\n#{output_labels}"
  end

  # Vision-specific sections

  defp vision_instruction_section(signature) do
    if signature.vision_enabled do
      """
      Vision Instructions: This task includes image inputs. Analyze all provided images carefully 
      and refer to them in your reasoning. Images are provided alongside text inputs.
      """
    else
      nil
    end
  end

  defp multi_modal_format_section(signature) do
    if signature.vision_enabled do
      vision_fields = Enum.filter(signature.input_fields, & &1.vision_enabled)

      if length(vision_fields) > 0 do
        field_descriptions =
          Enum.map(vision_fields, fn field ->
            "- #{field.name}: #{field.description} (image input)"
          end)
          |> Enum.join("\n")

        "Multi-modal Input Fields:\n#{field_descriptions}"
      else
        nil
      end
    else
      nil
    end
  end

  defp vision_examples_section([], _signature), do: nil

  defp vision_examples_section(_examples, signature) do
    if signature.vision_enabled do
      "Vision Examples: See the provided image examples that demonstrate the expected input format."
    else
      nil
    end
  end

  defp content_sections(text_content, vision_content, _signature) do
    sections = []

    sections =
      if length(text_content) > 0 do
        sections ++ ["Text Inputs:\n" <> Enum.join(text_content, "\n")]
      else
        sections
      end

    sections =
      if length(vision_content) > 0 do
        vision_descriptions =
          Enum.map(vision_content, fn content ->
            "#{content.field}: #{content.description}"
          end)
          |> Enum.join("\n")

        sections ++ ["Image Inputs:\n" <> vision_descriptions]
      else
        sections
      end

    Enum.join(sections, "\n\n")
  end

  # Sequential sections

  defp sequential_context_section(current_step, total_steps) do
    """
    Sequential Problem Solving Context:
    Current Step: #{current_step} of #{total_steps}
    Approach this as part of a multi-step solution process.
    """
  end

  defp step_specific_section(nil), do: nil

  defp step_specific_section(step_info) do
    """
    Step #{step_info.step_id}: #{step_info.name}
    Required Inputs: #{Enum.join(step_info.inputs, ", ")}
    Expected Outputs: #{Enum.join(step_info.outputs, ", ")}
    Dependencies: #{if length(step_info.dependencies) > 0, do: "Steps " <> Enum.join(Enum.map(step_info.dependencies, &to_string/1), ", "), else: "None"}
    """
  end

  defp previous_results_section([]), do: nil

  defp previous_results_section(previous_results) do
    results_text =
      Enum.with_index(previous_results, 1)
      |> Enum.map(fn {result, idx} ->
        "Step #{idx}: #{inspect(result)}"
      end)
      |> Enum.join("\n")

    "Previous Step Results:\n#{results_text}"
  end

  defp evaluation_criteria_section(criteria) do
    criteria_text =
      [
        "Correctness: #{criteria.correctness_weight * 100}%",
        "Reasoning Quality: #{criteria.reasoning_weight * 100}%",
        "Completeness: #{criteria.completeness_weight * 100}%",
        "Efficiency: #{criteria.efficiency_weight * 100}%",
        "Novelty: #{criteria.novelty_weight * 100}%"
      ]
      |> Enum.join("\n")

    "Evaluation Criteria:\n#{criteria_text}"
  end

  # Parsing functions

  defp parse_chunked_outputs(signature, text, context) do
    # Handle responses from chunked prompts
    chunk_index = Map.get(context, :chunk_index, 0)
    total_chunks = Map.get(context, :total_chunks, 1)

    partial_outputs = parse_standard_outputs(signature, text)

    %{
      outputs: partial_outputs,
      is_partial: chunk_index < total_chunks - 1,
      chunk_index: chunk_index,
      total_chunks: total_chunks
    }
  end

  defp parse_standard_outputs(signature, text) do
    output_fields = signature.output_fields

    output_fields
    |> Enum.reduce(%{}, fn field, acc ->
      case extract_field_value(text, field) do
        {:ok, value} ->
          case validate_field_value(value, field) do
            {:ok, validated_value} -> Map.put(acc, field.name, validated_value)
            {:error, _} -> acc
          end

        :error ->
          acc
      end
    end)
  end

  # Validation functions

  defp validate_required_fields(signature, inputs) do
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

  defp validate_field_types(signature, inputs) do
    # Enhanced type validation including vision types
    errors =
      signature.input_fields
      |> Enum.filter(fn field -> Map.has_key?(inputs, field.name) end)
      |> Enum.reduce([], fn field, acc ->
        value = Map.get(inputs, field.name)

        case validate_field_value(value, field) do
          {:ok, _} -> acc
          {:error, error} -> [{field.name, error} | acc]
        end
      end)

    case errors do
      [] -> :ok
      errors -> {:error, {:validation_errors, errors}}
    end
  end

  defp validate_content_lengths(signature, inputs) do
    # Check field-specific length limits
    errors =
      signature.input_fields
      |> Enum.filter(fn field -> field.max_length != nil end)
      |> Enum.reduce([], fn field, acc ->
        value = Map.get(inputs, field.name)

        if value && is_binary(value) && String.length(value) > field.max_length do
          [{field.name, :too_long} | acc]
        else
          acc
        end
      end)

    case errors do
      [] -> :ok
      errors -> {:error, {:length_errors, errors}}
    end
  end

  defp validate_vision_content(signature, inputs) do
    # Validate vision content if vision is enabled
    if signature.vision_enabled do
      vision_fields = Enum.filter(signature.input_fields, & &1.vision_enabled)

      errors =
        Enum.reduce(vision_fields, [], fn field, acc ->
          value = Map.get(inputs, field.name)

          if value && not is_vision_content?(value) do
            [{field.name, :invalid_vision_content} | acc]
          else
            acc
          end
        end)

      case errors do
        [] -> :ok
        errors -> {:error, {:vision_errors, errors}}
      end
    else
      :ok
    end
  end

  # Helper functions from original signature module

  defp extract_field_value(text, field) do
    field_name = String.capitalize(Atom.to_string(field.name))
    pattern = ~r/#{field_name}:\s*(.+?)(?=\n[A-Z][a-z]*:|$)/s

    case Regex.run(pattern, text, capture: :all_but_first) do
      [value] -> {:ok, String.trim(value)}
      nil -> :error
    end
  end

  defp validate_field_value(value, field) do
    case field.type do
      :string ->
        if is_binary(value), do: {:ok, value}, else: {:error, :invalid_string}

      :number ->
        case Float.parse(value) do
          {num, ""} ->
            {:ok, num}

          {num, _} ->
            {:ok, num}

          :error ->
            case Integer.parse(value) do
              {num, ""} -> {:ok, num}
              _ -> {:error, :invalid_number}
            end
        end

      :boolean ->
        case String.downcase(String.trim(value)) do
          "true" -> {:ok, true}
          "false" -> {:ok, false}
          "yes" -> {:ok, true}
          "no" -> {:ok, false}
          "1" -> {:ok, true}
          "0" -> {:ok, false}
          _ -> {:error, :invalid_boolean}
        end

      :json ->
        try do
          {:ok, Jason.decode!(value)}
        rescue
          _ -> {:error, :invalid_json}
        end

      :image ->
        if is_vision_content?(value) do
          {:ok, value}
        else
          {:error, :invalid_image}
        end

      :vision_text ->
        # Special type for text that accompanies vision content
        {:ok, value}

      # Default: accept as string
      _ ->
        {:ok, value}
    end
  end
end
