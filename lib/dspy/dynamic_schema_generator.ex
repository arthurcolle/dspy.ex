defmodule Dspy.DynamicSchemaGenerator do
  @moduledoc """
  Dynamic schema generation similar to Python's Pydantic models.

  This module provides:
  - Runtime struct generation with validation
  - Type checking and coercion
  - Automatic serialization/deserialization
  - Schema introspection and documentation
  - Integration with the structured decomposition system
  """

  use Dspy.Module
  alias Dspy.{LM, Prediction}

  defstruct [
    :schema_definitions,
    :validation_rules,
    :type_registry,
    :compilation_options,
    :generated_modules
  ]

  @type field_spec :: %{
          name: atom(),
          type: atom() | String.t(),
          required: boolean(),
          default: any(),
          validation: list(),
          description: String.t()
        }

  @type schema_spec :: %{
          name: String.t(),
          fields: [field_spec()],
          validations: list(),
          metadata: map()
        }

  @type t :: %__MODULE__{
          schema_definitions: map(),
          validation_rules: map(),
          type_registry: map(),
          compilation_options: keyword(),
          generated_modules: list()
        }

  # === SCHEMA GENERATION SIGNATURES ===

  defmodule SchemaAnalysisSignature do
    @moduledoc """
    Signature for analyzing raw specifications and generating schema definitions.

    Takes raw data or specifications and produces structured field definitions
    with appropriate types, validations, and relationships.
    """
    use Dspy.Signature

    input_field(:raw_specification, :json, "Raw specification or example data to analyze")
    input_field(:target_format, :string, "Target format (struct, protocol, behaviour, schema)")
    input_field(:existing_types, :json, "Existing type definitions to reference")
    input_field(:validation_requirements, :json, "Validation requirements and constraints")

    output_field(:schema_name, :string, "Name for the generated schema")

    output_field(
      :field_definitions,
      :json,
      "Detailed field definitions with types and validations"
    )

    output_field(:relationships, :json, "Relationships to other schemas")
    output_field(:validation_logic, :code, "Generated validation code")
    output_field(:serialization_code, :code, "Serialization/deserialization code")
  end

  defmodule TypeMappingSignature do
    @moduledoc """
    Signature for mapping types between different platforms and languages.

    Converts type definitions from source formats to Elixir types with
    appropriate validation, coercion, and serialization functions.
    """
    use Dspy.Signature

    input_field(:source_type_info, :json, "Source type information to map")
    input_field(:target_platform, :string, "Target platform (elixir, json, graphql, etc.)")
    input_field(:existing_mappings, :json, "Existing type mappings for reference")

    output_field(:elixir_type, :string, "Mapped Elixir type")
    output_field(:validation_function, :code, "Type validation function")
    output_field(:coercion_function, :code, "Type coercion function")
    output_field(:serialization_function, :code, "Serialization function")
    output_field(:example_values, :json, "Example valid values for this type")
  end

  # === MAIN INTERFACE ===

  def new(opts \\ []) do
    %__MODULE__{
      schema_definitions: %{},
      validation_rules: %{},
      type_registry: build_default_type_registry(),
      compilation_options: Keyword.get(opts, :compilation, []),
      generated_modules: []
    }
  end

  @impl true
  def forward(generator, inputs) do
    with {:ok, schema_analysis} <- analyze_schema_requirements(generator, inputs),
         {:ok, type_mappings} <- resolve_type_mappings(generator, schema_analysis),
         {:ok, generated_code} <- generate_schema_code(generator, schema_analysis, type_mappings),
         {:ok, compiled_module} <- compile_schema_module(generator, generated_code),
         {:ok, validation_results} <- validate_generated_schema(generator, compiled_module) do
      # Update generator state
      updated_generator = %{
        generator
        | schema_definitions:
            Map.put(generator.schema_definitions, schema_analysis.schema_name, schema_analysis),
          generated_modules: [compiled_module | generator.generated_modules]
      }

      prediction_attrs = %{
        schema_name: schema_analysis.schema_name,
        generated_module: compiled_module,
        field_definitions: schema_analysis.field_definitions,
        validation_results: validation_results,
        generated_code: generated_code,
        generator_state: updated_generator
      }

      prediction = Prediction.new(prediction_attrs)
      {:ok, prediction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # === SCHEMA ANALYSIS ===

  defp analyze_schema_requirements(generator, inputs) do
    analysis_inputs = %{
      raw_specification: Map.get(inputs, :specification, %{}),
      target_format: Map.get(inputs, :format, "struct"),
      existing_types: Map.keys(generator.type_registry),
      validation_requirements: Map.get(inputs, :validation, %{})
    }

    signature = SchemaAnalysisSignature.new()

    case LM.generate_structured_output(signature, analysis_inputs) do
      {:ok, analysis} ->
        # Parse and validate the field definitions
        case parse_field_definitions(analysis.field_definitions) do
          {:ok, parsed_fields} ->
            updated_analysis = %{analysis | field_definitions: parsed_fields}
            {:ok, updated_analysis}

          {:error, reason} ->
            {:error, {:field_parsing_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:schema_analysis_failed, reason}}
    end
  end

  defp parse_field_definitions(field_definitions) when is_list(field_definitions) do
    parsed_fields = Enum.map(field_definitions, &parse_field_definition/1)

    if Enum.any?(parsed_fields, &match?({:error, _}, &1)) do
      errors = Enum.filter(parsed_fields, &match?({:error, _}, &1))
      {:error, {:field_parsing_errors, errors}}
    else
      {:ok, Enum.map(parsed_fields, fn {:ok, field} -> field end)}
    end
  end

  defp parse_field_definitions(field_definitions) when is_map(field_definitions) do
    # Convert map format to list format
    field_list =
      Enum.map(field_definitions, fn {name, spec} ->
        Map.put(spec, :name, name)
      end)

    parse_field_definitions(field_list)
  end

  defp parse_field_definition(field_def) when is_map(field_def) do
    with {:ok, name} <- extract_field_name(field_def),
         {:ok, type} <- extract_field_type(field_def),
         {:ok, opts} <- extract_field_options(field_def) do
      field_spec = %{
        name: name,
        type: type,
        required: Map.get(opts, :required, false),
        default: Map.get(opts, :default, nil),
        validation: Map.get(opts, :validation, []),
        description: Map.get(opts, :description, "")
      }

      {:ok, field_spec}
    else
      {:error, reason} -> {:error, {:invalid_field_definition, field_def, reason}}
    end
  end

  defp extract_field_name(%{name: name}) when is_atom(name), do: {:ok, name}
  defp extract_field_name(%{name: name}) when is_binary(name), do: {:ok, String.to_atom(name)}
  defp extract_field_name(%{"name" => name}) when is_binary(name), do: {:ok, String.to_atom(name)}
  defp extract_field_name(_), do: {:error, :missing_field_name}

  defp extract_field_type(%{type: type}) when is_atom(type), do: {:ok, type}
  defp extract_field_type(%{type: type}) when is_binary(type), do: {:ok, String.to_atom(type)}
  defp extract_field_type(%{"type" => type}) when is_binary(type), do: {:ok, String.to_atom(type)}
  defp extract_field_type(_), do: {:error, :missing_field_type}

  defp extract_field_options(field_def) do
    opts = %{
      required: Map.get(field_def, :required, Map.get(field_def, "required", false)),
      default: Map.get(field_def, :default, Map.get(field_def, "default")),
      validation: Map.get(field_def, :validation, Map.get(field_def, "validation", [])),
      description: Map.get(field_def, :description, Map.get(field_def, "description", ""))
    }

    {:ok, opts}
  end

  # === TYPE MAPPING ===

  defp resolve_type_mappings(generator, schema_analysis) do
    type_mappings =
      Enum.map(schema_analysis.field_definitions, fn field ->
        mapping_inputs = %{
          source_type_info: %{
            type: field.type,
            validation: field.validation,
            required: field.required
          },
          target_platform: "elixir",
          existing_mappings: generator.type_registry
        }

        signature = TypeMappingSignature.new()

        case LM.generate_structured_output(signature, mapping_inputs) do
          {:ok, mapping} ->
            {:ok, {field.name, mapping}}

          {:error, reason} ->
            {:error, {:type_mapping_failed, field.name, reason}}
        end
      end)

    # Check for any mapping errors
    errors = Enum.filter(type_mappings, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      successful_mappings = Enum.map(type_mappings, fn {:ok, mapping} -> mapping end)
      {:ok, Map.new(successful_mappings)}
    else
      {:error, {:type_mapping_errors, errors}}
    end
  end

  # === CODE GENERATION ===

  defp generate_schema_code(_generator, schema_analysis, type_mappings) do
    _module_name = String.to_atom("Elixir." <> schema_analysis.schema_name)

    # Generate the module code
    module_code = """
    defmodule #{schema_analysis.schema_name} do
      @moduledoc \"\"\"
      Dynamically generated schema module.
      
      Generated at: #{DateTime.utc_now()}
      Field count: #{length(schema_analysis.field_definitions)}
      \"\"\"
      
      use Ecto.Schema
      import Ecto.Changeset
      
      @type t :: %__MODULE__{
        #{generate_type_definitions(schema_analysis.field_definitions, type_mappings)}
      }
      
      schema "#{Macro.underscore(schema_analysis.schema_name)}" do
        #{generate_field_definitions(schema_analysis.field_definitions, type_mappings)}
        
        timestamps()
      end
      
      @doc "Creates a changeset for validation"
      def changeset(struct, attrs \\\\ %{}) do
        struct
        |> cast(attrs, #{generate_cast_fields(schema_analysis.field_definitions)})
        |> validate_required(#{generate_required_fields(schema_analysis.field_definitions)})
        #{generate_custom_validations(schema_analysis.field_definitions, type_mappings)}
      end
      
      @doc "Creates and validates a new instance"
      def new(attrs \\\\ %{}) do
        changeset = %__MODULE__{} |> changeset(attrs)
        
        if changeset.valid? do
          {:ok, Ecto.Changeset.apply_changes(changeset)}
        else
          {:error, changeset}
        end
      end
      
      @doc "Converts to map representation"
      def to_map(%__MODULE__{} = struct) do
        struct
        |> Map.from_struct()
        |> Map.drop([:__meta__])
      end
      
      @doc "Schema introspection"
      def __schema_info__ do
        %{
          name: "#{schema_analysis.schema_name}",
          fields: #{inspect(schema_analysis.field_definitions)},
          generated_at: #{inspect(DateTime.utc_now())},
          type_mappings: #{inspect(type_mappings)}
        }
      end
      
      #{generate_serialization_functions(schema_analysis, type_mappings)}
    end
    """

    {:ok, module_code}
  end

  defp generate_type_definitions(field_definitions, type_mappings) do
    field_definitions
    |> Enum.map(fn field ->
      elixir_type = get_in(type_mappings, [field.name, :elixir_type]) || "any()"
      nullable_type = if field.required, do: elixir_type, else: "#{elixir_type} | nil"
      "#{field.name}: #{nullable_type}"
    end)
    |> Enum.join(",\n        ")
  end

  defp generate_field_definitions(field_definitions, _type_mappings) do
    field_definitions
    |> Enum.map(fn field ->
      ecto_type = map_to_ecto_type(field.type)
      null_option = if field.required, do: "", else: ", null: true"
      default_option = if field.default, do: ", default: #{inspect(field.default)}", else: ""

      "field :#{field.name}, :#{ecto_type}#{null_option}#{default_option}"
    end)
    |> Enum.join("\n        ")
  end

  defp generate_cast_fields(field_definitions) do
    field_names = Enum.map(field_definitions, & &1.name)
    inspect(field_names)
  end

  defp generate_required_fields(field_definitions) do
    required_fields =
      field_definitions
      |> Enum.filter(& &1.required)
      |> Enum.map(& &1.name)

    inspect(required_fields)
  end

  defp generate_custom_validations(field_definitions, type_mappings) do
    field_definitions
    |> Enum.map(fn field ->
      validations = field.validation || []

      if Enum.empty?(validations) do
        ""
      else
        validation_code = get_in(type_mappings, [field.name, :validation_function]) || ""
        if validation_code != "", do: "\n        |> #{validation_code}", else: ""
      end
    end)
    |> Enum.join("")
  end

  defp generate_serialization_functions(schema_analysis, type_mappings) do
    """

    @doc "Serialize to JSON"
    def to_json(%__MODULE__{} = struct) do
      struct
      |> to_map()
      |> Jason.encode()
    end

    @doc "Deserialize from JSON"
    def from_json(json_string) when is_binary(json_string) do
      case Jason.decode(json_string) do
        {:ok, data} -> from_map(data)
        {:error, reason} -> {:error, {:json_decode_failed, reason}}
      end
    end

    @doc "Create from map data"
    def from_map(data) when is_map(data) do
      # Apply type coercion for each field
      coerced_data = #{generate_coercion_logic(schema_analysis.field_definitions, type_mappings)}
      
      new(coerced_data)
    end
    """
  end

  defp generate_coercion_logic(field_definitions, type_mappings) do
    coercion_steps =
      Enum.map(field_definitions, fn field ->
        coercion_func = get_in(type_mappings, [field.name, :coercion_function])

        if coercion_func do
          """
          #{field.name}: apply_coercion(data, :#{field.name}, #{coercion_func})
          """
        else
          """
          #{field.name}: Map.get(data, "#{field.name}", Map.get(data, :#{field.name}))
          """
        end
      end)

    """
    %{
      #{Enum.join(coercion_steps, ",\n      ")}
    }
    """
  end

  # === COMPILATION ===

  defp compile_schema_module(generator, module_code) do
    try do
      # Compile the module code
      [{module, _binary}] = Code.compile_string(module_code)

      {:ok,
       %{
         module: module,
         code: module_code,
         compiled_at: DateTime.utc_now(),
         compilation_options: generator.compilation_options
       }}
    rescue
      error -> {:error, {:compilation_failed, Exception.message(error)}}
    end
  end

  defp validate_generated_schema(_generator, compiled_module) do
    module = compiled_module.module

    validation_checks = [
      validate_module_structure(module),
      validate_schema_functions(module),
      validate_type_compliance(module),
      validate_serialization_roundtrip(module)
    ]

    failed_checks =
      Enum.filter(validation_checks, fn
        {:ok, _} -> false
        {:error, _} -> true
      end)

    if Enum.empty?(failed_checks) do
      {:ok,
       %{
         status: :passed,
         checks: validation_checks,
         validated_at: DateTime.utc_now()
       }}
    else
      {:ok,
       %{
         status: :failed,
         checks: validation_checks,
         failures: failed_checks,
         validated_at: DateTime.utc_now()
       }}
    end
  end

  # === VALIDATION HELPERS ===

  defp validate_module_structure(module) do
    required_functions = [:new, :changeset, :to_map, :__schema_info__]

    missing_functions =
      Enum.filter(required_functions, fn func ->
        not function_exported?(module, func, 1)
      end)

    if Enum.empty?(missing_functions) do
      {:ok, :module_structure_valid}
    else
      {:error, {:missing_functions, missing_functions}}
    end
  end

  defp validate_schema_functions(module) do
    try do
      # Test basic functionality
      {:ok, instance} = module.new(%{})
      _map = module.to_map(instance)
      _info = module.__schema_info__()

      {:ok, :schema_functions_valid}
    rescue
      error -> {:error, {:schema_function_error, Exception.message(error)}}
    end
  end

  defp validate_type_compliance(module) do
    try do
      # Get schema info and validate type definitions
      schema_info = module.__schema_info__()

      # Check if all declared fields are accessible
      field_names = Enum.map(schema_info.fields, & &1.name)
      {:ok, test_instance} = module.new(%{})

      accessible_fields =
        Enum.filter(field_names, fn field ->
          Map.has_key?(test_instance, field)
        end)

      if length(accessible_fields) == length(field_names) do
        {:ok, :type_compliance_valid}
      else
        missing_fields = field_names -- accessible_fields
        {:error, {:inaccessible_fields, missing_fields}}
      end
    rescue
      error -> {:error, {:type_compliance_error, Exception.message(error)}}
    end
  end

  defp validate_serialization_roundtrip(module) do
    if function_exported?(module, :to_json, 1) and function_exported?(module, :from_json, 1) do
      try do
        # Test serialization roundtrip
        {:ok, original} = module.new(%{})
        {:ok, json} = module.to_json(original)
        {:ok, deserialized} = module.from_json(json)

        if module.to_map(original) == module.to_map(deserialized) do
          {:ok, :serialization_roundtrip_valid}
        else
          {:error, :serialization_roundtrip_mismatch}
        end
      rescue
        error -> {:error, {:serialization_error, Exception.message(error)}}
      end
    else
      {:ok, :serialization_not_implemented}
    end
  end

  # === UTILITY FUNCTIONS ===

  defp build_default_type_registry do
    %{
      string: %{elixir_type: "String.t()", ecto_type: :string},
      integer: %{elixir_type: "integer()", ecto_type: :integer},
      float: %{elixir_type: "float()", ecto_type: :float},
      boolean: %{elixir_type: "boolean()", ecto_type: :boolean},
      datetime: %{elixir_type: "DateTime.t()", ecto_type: :utc_datetime},
      uuid: %{elixir_type: "String.t()", ecto_type: :binary_id},
      json: %{elixir_type: "map()", ecto_type: :map},
      array: %{elixir_type: "list()", ecto_type: {:array, :string}}
    }
  end

  defp map_to_ecto_type(type) when is_atom(type) do
    case type do
      :string -> :string
      :integer -> :integer
      :number -> :float
      :float -> :float
      :boolean -> :boolean
      :datetime -> :utc_datetime
      :date -> :date
      :time -> :time
      :uuid -> :binary_id
      :json -> :map
      :array -> {:array, :string}
      # Default fallback
      _ -> :string
    end
  end

  defp map_to_ecto_type(type) when is_binary(type) do
    type |> String.to_atom() |> map_to_ecto_type()
  end

  # === PUBLIC API ===

  @doc """
  Generate a schema from a specification map.

  ## Examples

      iex> spec = %{
      ...>   name: "User",
      ...>   fields: [
      ...>     %{name: :email, type: :string, required: true},
      ...>     %{name: :age, type: :integer, required: false, default: 0}
      ...>   ]
      ...> }
      iex> {:ok, prediction} = Dspy.DynamicSchemaGenerator.generate_schema(spec)
      iex> User = prediction.attrs.generated_module.module
      iex> {:ok, user} = User.new(%{email: "test@example.com", age: 25})
  """
  def generate_schema(specification) do
    generator = new()
    forward(generator, %{specification: specification})
  end

  @doc """
  Generate multiple related schemas with automatic relationship resolution.
  """
  def generate_schema_set(specifications) when is_list(specifications) do
    generator = new()

    # Process schemas in dependency order
    Enum.reduce_while(specifications, {:ok, []}, fn spec, {:ok, acc} ->
      case forward(generator, %{specification: spec}) do
        {:ok, prediction} -> {:cont, {:ok, [prediction | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Analyze an existing module and generate a compatible schema specification.
  """
  def reverse_engineer_schema(module) when is_atom(module) do
    if function_exported?(module, :__struct__, 0) do
      struct_data = module.__struct__()

      field_specs =
        struct_data
        |> Map.keys()
        |> Enum.reject(&(&1 == :__struct__))
        |> Enum.map(fn field_name ->
          %{
            name: field_name,
            type: infer_type_from_value(Map.get(struct_data, field_name)),
            required: Map.get(struct_data, field_name) != nil,
            default: Map.get(struct_data, field_name)
          }
        end)

      specification = %{
        name: module |> Module.split() |> List.last(),
        fields: field_specs,
        source_module: module
      }

      {:ok, specification}
    else
      {:error, {:not_a_struct_module, module}}
    end
  end

  defp infer_type_from_value(nil), do: :string
  defp infer_type_from_value(value) when is_binary(value), do: :string
  defp infer_type_from_value(value) when is_integer(value), do: :integer
  defp infer_type_from_value(value) when is_float(value), do: :float
  defp infer_type_from_value(value) when is_boolean(value), do: :boolean
  defp infer_type_from_value(value) when is_list(value), do: :array
  defp infer_type_from_value(value) when is_map(value), do: :json
  defp infer_type_from_value(%DateTime{}), do: :datetime
  defp infer_type_from_value(_), do: :string
end
