defmodule Dspy.EndpointDiscovery do
  @moduledoc """
  Endpoint discovery and automatic route generation system.

  Similar to the Python self-scaffolding FastAPI generation, this module provides:
  - Automatic endpoint discovery from specifications
  - Dynamic route generation with parameter validation
  - OpenAPI-style documentation generation
  - Middleware and plug integration
  - Real-time route registration and modification
  """

  use Dspy.Module
  alias Dspy.{LM, Prediction}

  defstruct [
    :router_module,
    :endpoint_registry,
    :route_specifications,
    :middleware_stack,
    :documentation_generator,
    :validation_enabled,
    :live_reload_enabled
  ]

  @type endpoint_spec :: %{
          path: String.t(),
          method: atom(),
          handler: atom() | function(),
          request_schema: module() | nil,
          response_schema: module() | nil,
          middleware: list(),
          documentation: map()
        }

  @type t :: %__MODULE__{
          router_module: module(),
          endpoint_registry: map(),
          route_specifications: list(endpoint_spec()),
          middleware_stack: list(),
          documentation_generator: module(),
          validation_enabled: boolean(),
          live_reload_enabled: boolean()
        }

  # === ENDPOINT DISCOVERY SIGNATURES ===

  defmodule EndpointAnalysisSignature do
    @moduledoc """
    Signature for analyzing API specifications and discovering endpoints.

    Processes API specifications to extract endpoint definitions, route patterns,
    middleware requirements, and validation rules.
    """
    use Dspy.Signature

    input_field(:api_specification, :json, "API specification or OpenAPI document to analyze")
    input_field(:existing_endpoints, :json, "Existing endpoint definitions for reference")
    input_field(:target_framework, :string, "Target framework (phoenix, plug, custom)")
    input_field(:routing_conventions, :json, "Routing conventions and patterns to follow")

    output_field(:discovered_endpoints, :json, "Discovered endpoint definitions")
    output_field(:route_patterns, :json, "Route patterns and parameter extraction rules")
    output_field(:middleware_requirements, :json, "Required middleware for each endpoint")
    output_field(:validation_rules, :json, "Parameter and body validation rules")
    output_field(:documentation_metadata, :json, "Documentation and OpenAPI metadata")
  end

  defmodule RouteGenerationSignature do
    @moduledoc """
    Signature for generating route and handler code from endpoint definitions.

    Creates complete route implementations including handlers, validation,
    middleware integration, and tests.
    """
    use Dspy.Signature

    input_field(:endpoint_definition, :json, "Single endpoint definition to generate")
    input_field(:router_context, :json, "Router context and existing routes")
    input_field(:schema_definitions, :json, "Available schema definitions")
    input_field(:generation_strategy, :string, "Code generation strategy")

    output_field(:route_code, :code, "Generated route definition code")
    output_field(:handler_code, :code, "Generated handler function code")
    output_field(:validation_code, :code, "Parameter and body validation code")
    output_field(:middleware_code, :code, "Middleware integration code")
    output_field(:test_code, :code, "Generated test code for the endpoint")
  end

  defmodule MiddlewareAnalysisSignature do
    @moduledoc """
    Signature for analyzing and configuring middleware stacks.

    Determines required middleware based on endpoint requirements,
    security policies, and performance considerations.
    """
    use Dspy.Signature

    input_field(:endpoint_requirements, :json, "Endpoint security and processing requirements")
    input_field(:available_middleware, :json, "Available middleware modules and plugs")
    input_field(:security_policies, :json, "Security policies and authentication requirements")

    output_field(:middleware_stack, :json, "Recommended middleware stack configuration")
    output_field(:custom_middleware_needed, :json, "Custom middleware that needs to be created")
    output_field(:security_configuration, :json, "Security configuration and policies")
    output_field(:performance_optimizations, :json, "Performance optimization recommendations")
  end

  # === MAIN INTERFACE ===

  def new(opts \\ []) do
    %__MODULE__{
      router_module: Keyword.get(opts, :router_module, __MODULE__.DynamicRouter),
      endpoint_registry: %{},
      route_specifications: [],
      middleware_stack: Keyword.get(opts, :middleware, []),
      documentation_generator:
        Keyword.get(opts, :doc_generator, __MODULE__.DocumentationGenerator),
      validation_enabled: Keyword.get(opts, :validation, true),
      live_reload_enabled: Keyword.get(opts, :live_reload, true)
    }
  end

  @impl true
  def forward(discoverer, inputs) do
    with {:ok, endpoint_analysis} <- analyze_api_specification(discoverer, inputs),
         {:ok, route_definitions} <- generate_route_definitions(discoverer, endpoint_analysis),
         {:ok, middleware_config} <-
           analyze_middleware_requirements(discoverer, endpoint_analysis),
         {:ok, generated_router} <-
           generate_router_module(discoverer, route_definitions, middleware_config),
         {:ok, documentation} <- generate_documentation(discoverer, route_definitions) do
      # Update discoverer state
      updated_discoverer = %{
        discoverer
        | endpoint_registry: build_endpoint_registry(route_definitions),
          route_specifications: route_definitions,
          middleware_stack: middleware_config.middleware_stack
      }

      # Register routes if live reload is enabled
      if discoverer.live_reload_enabled do
        register_routes_dynamically(generated_router, route_definitions)
      end

      prediction_attrs = %{
        discovered_endpoints: endpoint_analysis.discovered_endpoints,
        generated_routes: route_definitions,
        router_module: generated_router,
        middleware_configuration: middleware_config,
        documentation: documentation,
        discoverer_state: updated_discoverer
      }

      prediction = Prediction.new(prediction_attrs)
      {:ok, prediction}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # === ENDPOINT ANALYSIS ===

  # Helper function to generate structured output using LM
  defp generate_structured_output(signature, inputs) do
    # Build prompt from signature and inputs
    system_prompt = build_system_prompt(signature)
    user_prompt = build_user_prompt(signature, inputs)

    # Create request with JSON output format
    request = %{
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ],
      temperature: 0.7
    }

    # Generate and parse response
    case LM.generate(request) do
      {:ok, response} ->
        parse_structured_response(response, signature)
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_system_prompt(signature) do
    output_fields = signature.output_fields
    field_descriptions = Enum.map(output_fields, fn {name, %{description: desc}} ->
      "- #{name}: #{desc}"
    end)
    
    """
    You are a helpful assistant that generates structured JSON output.
    You must respond with a valid JSON object containing these fields:
    #{Enum.join(field_descriptions, "\n")}
    """
  end

  defp build_user_prompt(_signature, inputs) do
    input_data = Enum.map(inputs, fn {key, value} ->
      "#{key}: #{Jason.encode!(value)}"
    end)
    
    """
    Based on the following inputs, generate the required output:
    
    #{Enum.join(input_data, "\n")}
    
    Respond with a valid JSON object.
    """
  end

  defp parse_structured_response(response, signature) do
    content = get_in(response, [:choices, Access.at(0), :message, :content]) || ""
    
    case Jason.decode(content) do
      {:ok, parsed} ->
        # Convert to struct based on signature output fields
        output_data = Enum.reduce(signature.output_fields, %{}, fn {name, _field}, acc ->
          Map.put(acc, name, Map.get(parsed, Atom.to_string(name)))
        end)
        {:ok, output_data}
        
      {:error, _} ->
        {:error, :invalid_json_response}
    end
  end

  defp analyze_api_specification(discoverer, inputs) do
    analysis_inputs = %{
      api_specification: Map.get(inputs, :specification, %{}),
      existing_endpoints: Map.keys(discoverer.endpoint_registry),
      target_framework: Map.get(inputs, :framework, "phoenix"),
      routing_conventions: Map.get(inputs, :conventions, build_default_conventions())
    }

    signature = EndpointAnalysisSignature.signature()

    case generate_structured_output(signature, analysis_inputs) do
      {:ok, analysis} ->
        # Validate and normalize the discovered endpoints
        case normalize_endpoint_definitions(analysis.discovered_endpoints) do
          {:ok, normalized_endpoints} ->
            updated_analysis = %{analysis | discovered_endpoints: normalized_endpoints}
            {:ok, updated_analysis}

          {:error, reason} ->
            {:error, {:endpoint_normalization_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:endpoint_analysis_failed, reason}}
    end
  end

  defp normalize_endpoint_definitions(endpoints) when is_list(endpoints) do
    normalized = Enum.map(endpoints, &normalize_single_endpoint/1)

    errors = Enum.filter(normalized, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(normalized, fn {:ok, endpoint} -> endpoint end)}
    else
      {:error, {:normalization_errors, errors}}
    end
  end

  defp normalize_single_endpoint(endpoint_def) when is_map(endpoint_def) do
    with {:ok, path} <- extract_endpoint_path(endpoint_def),
         {:ok, method} <- extract_endpoint_method(endpoint_def),
         {:ok, handler} <- extract_endpoint_handler(endpoint_def),
         {:ok, schemas} <- extract_endpoint_schemas(endpoint_def) do
      normalized = %{
        path: path,
        method: method,
        handler: handler,
        request_schema: Map.get(schemas, :request),
        response_schema: Map.get(schemas, :response),
        middleware: Map.get(endpoint_def, :middleware, []),
        documentation: Map.get(endpoint_def, :documentation, %{}),
        parameters: extract_path_parameters(path),
        validation: Map.get(endpoint_def, :validation, %{})
      }

      {:ok, normalized}
    else
      {:error, reason} -> {:error, {:invalid_endpoint_definition, endpoint_def, reason}}
    end
  end

  defp extract_endpoint_path(%{path: path}) when is_binary(path), do: {:ok, path}
  defp extract_endpoint_path(%{"path" => path}) when is_binary(path), do: {:ok, path}
  defp extract_endpoint_path(_), do: {:error, :missing_path}

  defp extract_endpoint_method(%{method: method}) when is_atom(method), do: {:ok, method}

  defp extract_endpoint_method(%{method: method}) when is_binary(method),
    do: {:ok, String.to_atom(method)}

  defp extract_endpoint_method(%{"method" => method}) when is_binary(method),
    do: {:ok, String.to_atom(method)}

  defp extract_endpoint_method(_), do: {:error, :missing_method}

  defp extract_endpoint_handler(%{handler: handler}) when is_atom(handler), do: {:ok, handler}
  defp extract_endpoint_handler(%{handler: handler}) when is_function(handler), do: {:ok, handler}

  defp extract_endpoint_handler(%{"handler" => handler}) when is_binary(handler) do
    {:ok, String.to_atom(handler)}
  end

  defp extract_endpoint_handler(endpoint_def) do
    # Generate a default handler name from path and method
    path = Map.get(endpoint_def, :path, Map.get(endpoint_def, "path", ""))
    method = Map.get(endpoint_def, :method, Map.get(endpoint_def, "method", "get"))

    handler_name = generate_handler_name(path, method)
    {:ok, handler_name}
  end

  defp extract_endpoint_schemas(endpoint_def) do
    request_schema =
      Map.get(endpoint_def, :request_schema, Map.get(endpoint_def, "request_schema"))

    response_schema =
      Map.get(endpoint_def, :response_schema, Map.get(endpoint_def, "response_schema"))

    schemas = %{
      request: normalize_schema_reference(request_schema),
      response: normalize_schema_reference(response_schema)
    }

    {:ok, schemas}
  end

  defp normalize_schema_reference(nil), do: nil
  defp normalize_schema_reference(schema) when is_atom(schema), do: schema
  defp normalize_schema_reference(schema) when is_binary(schema), do: String.to_atom(schema)

  defp normalize_schema_reference(schema) when is_map(schema) do
    # This is an inline schema definition - we'll need to generate a module for it
    schema_name = generate_schema_name_from_definition(schema)
    String.to_atom(schema_name)
  end

  defp extract_path_parameters(path) do
    # Extract parameters like :id, :user_id from /users/:id/posts/:post_id
    Regex.scan(~r/:([a-zA-Z_][a-zA-Z0-9_]*)/, path, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.to_atom/1)
  end

  # === ROUTE GENERATION ===

  defp generate_route_definitions(discoverer, endpoint_analysis) do
    route_definitions =
      Enum.map(endpoint_analysis.discovered_endpoints, fn endpoint ->
        generation_inputs = %{
          endpoint_definition: endpoint,
          router_context: build_router_context(discoverer),
          schema_definitions: gather_schema_definitions(),
          generation_strategy: "phoenix_controller"
        }

        signature = RouteGenerationSignature.signature()

        case generate_structured_output(signature, generation_inputs) do
          {:ok, route_def} ->
            {:ok, Map.put(route_def, :original_endpoint, endpoint)}

          {:error, reason} ->
            {:error, {:route_generation_failed, endpoint, reason}}
        end
      end)

    # Check for generation errors
    errors = Enum.filter(route_definitions, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      successful_routes = Enum.map(route_definitions, fn {:ok, route} -> route end)
      {:ok, successful_routes}
    else
      {:error, {:route_generation_errors, errors}}
    end
  end

  defp build_router_context(discoverer) do
    %{
      existing_routes: Map.keys(discoverer.endpoint_registry),
      middleware_stack: discoverer.middleware_stack,
      router_module: discoverer.router_module,
      validation_enabled: discoverer.validation_enabled
    }
  end

  defp gather_schema_definitions do
    # Gather all available schema definitions from various sources
    %{
      dynamic_schemas: list_dynamic_schemas(),
      ecto_schemas: list_ecto_schemas(),
      struct_modules: list_struct_modules()
    }
  end

  # === MIDDLEWARE ANALYSIS ===

  defp analyze_middleware_requirements(_discoverer, endpoint_analysis) do
    middleware_inputs = %{
      endpoint_requirements:
        extract_security_requirements(endpoint_analysis.discovered_endpoints),
      available_middleware: list_available_middleware(),
      security_policies: build_security_policies()
    }

    signature = MiddlewareAnalysisSignature.signature()

    case generate_structured_output(signature, middleware_inputs) do
      {:ok, middleware_config} ->
        {:ok, middleware_config}

      {:error, reason} ->
        {:error, {:middleware_analysis_failed, reason}}
    end
  end

  defp extract_security_requirements(endpoints) do
    Enum.map(endpoints, fn endpoint ->
      %{
        path: endpoint.path,
        method: endpoint.method,
        authentication_required: requires_authentication?(endpoint),
        authorization_rules: extract_authorization_rules(endpoint),
        rate_limiting: extract_rate_limiting(endpoint),
        input_validation: endpoint.validation
      }
    end)
  end

  # === ROUTER MODULE GENERATION ===

  defp generate_router_module(discoverer, route_definitions, middleware_config) do
    module_name = discoverer.router_module

    router_code = """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Dynamically generated router module.
      
      Generated at: #{DateTime.utc_now()}
      Routes: #{length(route_definitions)}
      Middleware: #{length(middleware_config.middleware_stack)}
      \"\"\"
      
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      
      #{generate_middleware_pipeline(middleware_config)}
      
      #{generate_route_definitions_code(route_definitions)}
      
      #{generate_handler_functions(route_definitions)}
      
      #{generate_utility_functions()}
    end
    """

    try do
      [{module, _binary}] = Code.compile_string(router_code)

      {:ok,
       %{
         module: module,
         code: router_code,
         routes: route_definitions,
         compiled_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, {:router_compilation_failed, Exception.message(error)}}
    end
  end

  defp generate_middleware_pipeline(middleware_config) do
    """
    pipeline :api do
      plug :accepts, ["json"]
      #{Enum.map(middleware_config.middleware_stack, &"plug #{&1}")}
    end

    pipeline :authenticated do
      plug :api
      #{generate_auth_middleware(middleware_config)}
    end
    """
  end

  defp generate_route_definitions_code(route_definitions) do
    Enum.map(route_definitions, fn route ->
      endpoint = route.original_endpoint
      pipeline = if requires_authentication?(endpoint), do: ":authenticated", else: ":api"

      """
      scope "/", #{route.module_name || "DynamicController"} do
        pipe_through #{pipeline}
        
        #{endpoint.method} "#{endpoint.path}", #{endpoint.handler || :handle_request}
      end
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_handler_functions(route_definitions) do
    Enum.map(route_definitions, fn route ->
      endpoint = route.original_endpoint
      handler_name = endpoint.handler || :handle_request

      """
      def #{handler_name}(conn, params) do
        # Generated handler for #{endpoint.method} #{endpoint.path}
        #{route.handler_code || generate_default_handler_code(endpoint)}
      end
      """
    end)
    |> Enum.join("\n\n")
  end

  defp generate_default_handler_code(endpoint) do
    """
    try do
      # Parameter validation
      validated_params = validate_parameters(params, #{inspect(endpoint.parameters)})
      
      # Request body validation
      #{if endpoint.request_schema do
      "validated_body = validate_request_body(conn, #{endpoint.request_schema})"
    else
      "validated_body = %{}"
    end}
      
      # Execute business logic
      result = execute_business_logic(validated_params, validated_body)
      
      # Format response
      #{if endpoint.response_schema do
      "response = format_response(result, #{endpoint.response_schema})"
    else
      "response = result"
    end}
      
      json(conn, response)
    rescue
      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{message: Exception.message(error), type: "internal_error"}})
    end
    """
  end

  # === DOCUMENTATION GENERATION ===

  defp generate_documentation(_discoverer, route_definitions) do
    # doc_generator = _discoverer.documentation_generator

    documentation = %{
      openapi_version: "3.0.0",
      info: %{
        title: "Dynamically Generated API",
        version: "1.0.0",
        description: "API generated by Dspy.EndpointDiscovery"
      },
      paths: generate_openapi_paths(route_definitions),
      components: %{
        schemas: generate_schema_definitions_for_docs(route_definitions)
      },
      generated_at: DateTime.utc_now()
    }

    {:ok, documentation}
  end

  defp generate_openapi_paths(route_definitions) do
    Enum.reduce(route_definitions, %{}, fn route, acc ->
      endpoint = route.original_endpoint

      path_info = %{
        String.downcase(Atom.to_string(endpoint.method)) => %{
          summary: Map.get(endpoint.documentation, :summary, "Generated endpoint"),
          description: Map.get(endpoint.documentation, :description, ""),
          parameters: generate_parameter_docs(endpoint.parameters),
          requestBody: generate_request_body_docs(endpoint.request_schema),
          responses: generate_response_docs(endpoint.response_schema)
        }
      }

      Map.put(acc, endpoint.path, path_info)
    end)
  end

  # === UTILITY FUNCTIONS ===

  defp build_default_conventions do
    %{
      route_naming: :snake_case,
      parameter_style: :colon_prefix,
      response_format: :json,
      error_handling: :standard,
      authentication: :optional
    }
  end

  defp generate_handler_name(path, method) do
    # Convert /users/:id/posts to handle_users_id_posts_get
    normalized_path =
      path
      |> String.replace(~r/^\/+/, "")
      |> String.replace(~r/\/+$/, "")
      |> String.replace("/", "_")
      |> String.replace(":", "")

    method_str = Atom.to_string(method)

    "handle_#{normalized_path}_#{method_str}" |> String.to_atom()
  end

  defp generate_schema_name_from_definition(schema_def) do
    # Generate a unique schema name from the definition
    hash = :crypto.hash(:md5, inspect(schema_def)) |> Base.encode16() |> String.slice(0, 8)
    "DynamicSchema_#{hash}"
  end

  defp list_dynamic_schemas do
    # List schemas generated by DynamicSchemaGenerator
    # Placeholder
    []
  end

  defp list_ecto_schemas do
    # List available Ecto schemas
    # Placeholder
    []
  end

  defp list_struct_modules do
    # List available struct modules
    :code.all_loaded()
    |> Enum.filter(fn {module, _} ->
      try do
        function_exported?(module, :__struct__, 0)
      rescue
        _ -> false
      end
    end)
    |> Enum.map(fn {module, _} -> module end)
  end

  defp list_available_middleware do
    # List available middleware modules
    [
      Plug.Logger,
      Plug.RequestId,
      Plug.Telemetry,
      CORSPlug,
      Plug.Parsers,
      Plug.MethodOverride,
      Plug.Head
    ]
  end

  defp build_security_policies do
    %{
      authentication: %{
        required_for: [],
        methods: [:bearer_token, :api_key],
        fallback: :reject
      },
      authorization: %{
        default_policy: :allow,
        role_based: false
      },
      rate_limiting: %{
        enabled: true,
        default_limit: 1000,
        window_size: 3600
      }
    }
  end

  defp requires_authentication?(endpoint) do
    Map.get(endpoint.documentation, :authentication_required, false) or
      String.contains?(endpoint.path, "/admin/") or
      endpoint.method in [:post, :put, :delete]
  end

  defp extract_authorization_rules(endpoint) do
    Map.get(endpoint.documentation, :authorization, [])
  end

  defp extract_rate_limiting(endpoint) do
    Map.get(endpoint.documentation, :rate_limiting, %{})
  end

  defp generate_auth_middleware(middleware_config) do
    case Map.get(middleware_config, :authentication_method) do
      :bearer_token -> "plug Guardian.Plug.VerifyHeader"
      :api_key -> "plug ApiKeyPlug"
      _ -> "plug :require_authentication"
    end
  end

  defp build_endpoint_registry(route_definitions) do
    Enum.reduce(route_definitions, %{}, fn route, acc ->
      endpoint = route.original_endpoint
      key = "#{endpoint.method} #{endpoint.path}"
      Map.put(acc, key, route)
    end)
  end

  defp register_routes_dynamically(_generated_router, _route_definitions) do
    # In a real implementation, this would integrate with Phoenix's router
    # to dynamically register routes at runtime
    :ok
  end

  defp generate_utility_functions do
    """
    defp validate_parameters(params, expected_params) do
      # Parameter validation logic
      params
    end

    defp validate_request_body(conn, schema_module) when is_atom(schema_module) do
      # Request body validation using schema
      %{}
    end

    defp execute_business_logic(params, body) do
      # Default business logic - override in specific handlers
      %{
        message: "Success",
        params: params,
        body: body,
        timestamp: DateTime.utc_now()
      }
    end

    defp format_response(result, schema_module) when is_atom(schema_module) do
      # Response formatting using schema
      result
    end
    """
  end

  defp generate_parameter_docs(parameters) do
    Enum.map(parameters, fn param ->
      %{
        name: Atom.to_string(param),
        in: "path",
        required: true,
        schema: %{type: "string"}
      }
    end)
  end

  defp generate_request_body_docs(nil), do: nil

  defp generate_request_body_docs(schema) do
    %{
      required: true,
      content: %{
        "application/json" => %{
          schema: %{"$ref" => "#/components/schemas/#{schema}"}
        }
      }
    }
  end

  defp generate_response_docs(nil) do
    %{
      "200" => %{
        description: "Success",
        content: %{
          "application/json" => %{
            schema: %{type: "object"}
          }
        }
      }
    }
  end

  defp generate_response_docs(schema) do
    %{
      "200" => %{
        description: "Success",
        content: %{
          "application/json" => %{
            schema: %{"$ref" => "#/components/schemas/#{schema}"}
          }
        }
      }
    }
  end

  defp generate_schema_definitions_for_docs(_route_definitions) do
    # Generate OpenAPI schema definitions for all referenced schemas
    # Placeholder
    %{}
  end

  # === PUBLIC API ===

  @doc """
  Discover endpoints from an OpenAPI specification.
  """
  def discover_from_openapi(openapi_spec) do
    discoverer = new()
    forward(discoverer, %{specification: openapi_spec, format: :openapi})
  end

  @doc """
  Generate routes from a simple endpoint list.
  """
  def generate_routes(endpoint_list) when is_list(endpoint_list) do
    discoverer = new()

    specification = %{
      endpoints: endpoint_list,
      format: :simple
    }

    forward(discoverer, %{specification: specification})
  end

  @doc """
  Register a new endpoint dynamically at runtime.
  """
  def register_endpoint(discoverer, endpoint_spec) do
    # This would integrate with the live reload system
    # to add new endpoints without restarting the application
    {:ok, updated_discoverer} =
      forward(discoverer, %{
        specification: %{endpoints: [endpoint_spec]},
        mode: :incremental
      })

    updated_discoverer
  end
end
