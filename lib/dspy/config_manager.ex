defmodule Dspy.ConfigManager do
  @moduledoc """
  Comprehensive configuration management system for DSPy task execution
  with hierarchical configuration, environment-aware settings, dynamic
  updates, and validation.
  """

  use GenServer

  defstruct [
    :name,
    :config_store,
    :config_sources,
    :validation_rules,
    :environment,
    :reload_policies,
    :change_listeners,
    :config_history,
    :encryption_keys,
    :secrets_manager,
    :feature_flags
  ]

  @type config_source :: :file | :environment | :etcd | :consul | :database | :remote_api
  @type config_level :: :system | :application | :module | :task | :user
  @type validation_result :: :ok | {:error, [String.t()]}

  defmodule ConfigSchema do
    @moduledoc """
    Configuration schema definition and validation.
    """

    defstruct [
      :fields,
      :required_fields,
      :default_values,
      :validation_rules,
      :transformations,
      :dependencies
    ]

    @type field_type :: :string | :integer | :float | :boolean | :list | :map | :atom | :module
    @type validation_rule ::
            {:range, number(), number()}
            | {:regex, Regex.t()}
            | {:enum, [any()]}
            | {:custom, function()}

    @type t :: %__MODULE__{
            fields: %{atom() => field_type()},
            required_fields: [atom()],
            default_values: map(),
            validation_rules: %{atom() => [validation_rule()]},
            transformations: %{atom() => function()},
            dependencies: %{atom() => [atom()]}
          }

    def new(opts \\ []) do
      %__MODULE__{
        fields: Keyword.get(opts, :fields, %{}),
        required_fields: Keyword.get(opts, :required_fields, []),
        default_values: Keyword.get(opts, :default_values, %{}),
        validation_rules: Keyword.get(opts, :validation_rules, %{}),
        transformations: Keyword.get(opts, :transformations, %{}),
        dependencies: Keyword.get(opts, :dependencies, %{})
      }
    end

    def validate(schema, config) do
      with :ok <- validate_required_fields(schema, config),
           :ok <- validate_field_types(schema, config),
           :ok <- validate_field_rules(schema, config),
           :ok <- validate_dependencies(schema, config) do
        :ok
      else
        {:error, errors} -> {:error, errors}
      end
    end

    def apply_defaults(schema, config) do
      Enum.reduce(schema.default_values, config, fn {key, default_value}, acc ->
        case Map.get(acc, key) do
          nil -> Map.put(acc, key, default_value)
          _ -> acc
        end
      end)
    end

    def transform_values(schema, config) do
      Enum.reduce(schema.transformations, config, fn {key, transform_fn}, acc ->
        case Map.get(acc, key) do
          nil -> acc
          value -> Map.put(acc, key, transform_fn.(value))
        end
      end)
    end

    defp validate_required_fields(schema, config) do
      missing_fields =
        Enum.filter(schema.required_fields, fn field ->
          not Map.has_key?(config, field) or is_nil(Map.get(config, field))
        end)

      case missing_fields do
        [] -> :ok
        fields -> {:error, ["Missing required fields: #{Enum.join(fields, ", ")}"]}
      end
    end

    defp validate_field_types(schema, config) do
      errors =
        Enum.reduce(config, [], fn {key, value}, acc ->
          case Map.get(schema.fields, key) do
            # Unknown fields are allowed
            nil ->
              acc

            expected_type ->
              if valid_type?(value, expected_type) do
                acc
              else
                ["Field #{key} must be of type #{expected_type}, got #{inspect(value)}" | acc]
              end
          end
        end)

      case errors do
        [] -> :ok
        _ -> {:error, Enum.reverse(errors)}
      end
    end

    defp validate_field_rules(schema, config) do
      errors =
        Enum.reduce(config, [], fn {key, value}, acc ->
          case Map.get(schema.validation_rules, key) do
            nil ->
              acc

            rules ->
              rule_errors =
                Enum.reduce(rules, [], fn rule, rule_acc ->
                  case validate_rule(value, rule) do
                    :ok -> rule_acc
                    {:error, message} -> [message | rule_acc]
                  end
                end)

              rule_errors ++ acc
          end
        end)

      case errors do
        [] -> :ok
        _ -> {:error, Enum.reverse(errors)}
      end
    end

    defp validate_dependencies(schema, config) do
      errors =
        Enum.reduce(schema.dependencies, [], fn {field, deps}, acc ->
          if Map.has_key?(config, field) do
            missing_deps =
              Enum.filter(deps, fn dep ->
                not Map.has_key?(config, dep)
              end)

            case missing_deps do
              [] -> acc
              deps -> ["Field #{field} requires dependencies: #{Enum.join(deps, ", ")}" | acc]
            end
          else
            acc
          end
        end)

      case errors do
        [] -> :ok
        _ -> {:error, errors}
      end
    end

    defp valid_type?(value, :string), do: is_binary(value)
    defp valid_type?(value, :integer), do: is_integer(value)
    defp valid_type?(value, :float), do: is_float(value) or is_integer(value)
    defp valid_type?(value, :boolean), do: is_boolean(value)
    defp valid_type?(value, :list), do: is_list(value)
    defp valid_type?(value, :map), do: is_map(value)
    defp valid_type?(value, :atom), do: is_atom(value)
    defp valid_type?(value, :module), do: is_atom(value) and Code.ensure_loaded?(value)
    defp valid_type?(_, _), do: true

    defp validate_rule(value, {:range, min, max}) when is_number(value) do
      if value >= min and value <= max do
        :ok
      else
        {:error, "Value #{value} must be between #{min} and #{max}"}
      end
    end

    defp validate_rule(value, {:regex, regex}) when is_binary(value) do
      if Regex.match?(regex, value) do
        :ok
      else
        {:error, "Value #{value} does not match required pattern"}
      end
    end

    defp validate_rule(value, {:enum, allowed_values}) do
      if value in allowed_values do
        :ok
      else
        {:error, "Value #{inspect(value)} must be one of: #{inspect(allowed_values)}"}
      end
    end

    defp validate_rule(value, {:custom, validation_fn}) do
      validation_fn.(value)
    end

    defp validate_rule(_, _), do: :ok
  end

  defmodule SecretsManager do
    @moduledoc """
    Secure handling of sensitive configuration values.
    """

    defstruct [:encryption_key, :encrypted_values, :access_log]

    def new(encryption_key) do
      %__MODULE__{
        encryption_key: encryption_key,
        encrypted_values: %{},
        access_log: []
      }
    end

    def store_secret(secrets_manager, key, value) do
      encrypted_value = encrypt_value(value, secrets_manager.encryption_key)
      updated_values = Map.put(secrets_manager.encrypted_values, key, encrypted_value)

      %{secrets_manager | encrypted_values: updated_values}
    end

    def retrieve_secret(secrets_manager, key) do
      case Map.get(secrets_manager.encrypted_values, key) do
        nil ->
          {:error, :not_found}

        encrypted_value ->
          case decrypt_value(encrypted_value, secrets_manager.encryption_key) do
            {:ok, decrypted_value} ->
              # Log access
              access_entry = {key, DateTime.utc_now(), Process.info(self(), :registered_name)}
              updated_log = [access_entry | Enum.take(secrets_manager.access_log, 99)]
              updated_manager = %{secrets_manager | access_log: updated_log}

              {{:ok, decrypted_value}, updated_manager}

            {:error, reason} ->
              {{:error, reason}, secrets_manager}
          end
      end
    end

    def list_secret_keys(secrets_manager) do
      Map.keys(secrets_manager.encrypted_values)
    end

    defp encrypt_value(value, encryption_key) do
      # Simple encryption (in production, use proper encryption libraries)
      serialized = :erlang.term_to_binary(value)

      encrypted =
        :crypto.crypto_one_time(:aes_256_cbc, encryption_key, <<0::128>>, serialized, true)

      Base.encode64(encrypted)
    end

    defp decrypt_value(encrypted_value, encryption_key) do
      try do
        decoded = Base.decode64!(encrypted_value)

        decrypted =
          :crypto.crypto_one_time(:aes_256_cbc, encryption_key, <<0::128>>, decoded, false)

        value = :erlang.binary_to_term(decrypted)
        {:ok, value}
      rescue
        _ -> {:error, :decryption_failed}
      end
    end
  end

  # Main ConfigManager API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def get_config(manager \\ __MODULE__, key, default \\ nil) do
    GenServer.call(manager, {:get_config, key, default})
  end

  def set_config(manager \\ __MODULE__, key, value) do
    GenServer.call(manager, {:set_config, key, value})
  end

  def update_config(manager \\ __MODULE__, updates) do
    GenServer.call(manager, {:update_config, updates})
  end

  def get_environment_config(manager \\ __MODULE__, environment) do
    GenServer.call(manager, {:get_environment_config, environment})
  end

  def reload_config(manager \\ __MODULE__, source \\ :all) do
    GenServer.call(manager, {:reload_config, source})
  end

  def validate_config(manager \\ __MODULE__, config) do
    GenServer.call(manager, {:validate_config, config})
  end

  def add_config_listener(manager \\ __MODULE__, listener_fn) do
    GenServer.call(manager, {:add_config_listener, listener_fn})
  end

  def get_feature_flag(manager \\ __MODULE__, flag_name, default \\ false) do
    GenServer.call(manager, {:get_feature_flag, flag_name, default})
  end

  def set_feature_flag(manager \\ __MODULE__, flag_name, value) do
    GenServer.call(manager, {:set_feature_flag, flag_name, value})
  end

  def get_secret(manager \\ __MODULE__, secret_key) do
    GenServer.call(manager, {:get_secret, secret_key})
  end

  def set_secret(manager \\ __MODULE__, secret_key, secret_value) do
    GenServer.call(manager, {:set_secret, secret_key, secret_value})
  end

  # GenServer Implementation

  @impl true
  def init(opts) do
    environment = Keyword.get(opts, :environment, get_current_environment())
    config_sources = Keyword.get(opts, :config_sources, [:file, :environment])

    # Initialize encryption for secrets
    encryption_key = generate_encryption_key()
    secrets_manager = SecretsManager.new(encryption_key)

    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__),
      config_store: %{},
      config_sources: config_sources,
      validation_rules: initialize_validation_rules(opts),
      environment: environment,
      reload_policies: Keyword.get(opts, :reload_policies, %{}),
      change_listeners: [],
      config_history: [],
      encryption_keys: %{default: encryption_key},
      secrets_manager: secrets_manager,
      feature_flags: %{}
    }

    # Load initial configuration
    {:ok, load_initial_configuration(state)}
  end

  @impl true
  def handle_call({:get_config, key, default}, _from, state) do
    value = get_config_value(state.config_store, key, default, state.environment)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:set_config, key, value}, _from, state) do
    case validate_config_value(state.validation_rules, key, value) do
      :ok ->
        updated_store = set_config_value(state.config_store, key, value, state.environment)
        updated_state = %{state | config_store: updated_store}

        # Notify listeners
        notify_config_change(state.change_listeners, key, value)

        # Record in history
        history_entry = {DateTime.utc_now(), :set, key, value}
        updated_history = [history_entry | Enum.take(state.config_history, 99)]

        final_state = %{updated_state | config_history: updated_history}
        {:reply, :ok, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_config, updates}, _from, state) do
    case validate_config_batch(state.validation_rules, updates) do
      :ok ->
        updated_store =
          Enum.reduce(updates, state.config_store, fn {key, value}, acc ->
            set_config_value(acc, key, value, state.environment)
          end)

        updated_state = %{state | config_store: updated_store}

        # Notify listeners for each change
        Enum.each(updates, fn {key, value} ->
          notify_config_change(state.change_listeners, key, value)
        end)

        # Record batch update in history
        history_entry = {DateTime.utc_now(), :batch_update, updates, nil}
        updated_history = [history_entry | Enum.take(state.config_history, 99)]

        final_state = %{updated_state | config_history: updated_history}
        {:reply, :ok, final_state}

      {:error, errors} ->
        {:reply, {:error, errors}, state}
    end
  end

  @impl true
  def handle_call({:get_environment_config, environment}, _from, state) do
    env_config = get_environment_specific_config(state.config_store, environment)
    {:reply, env_config, state}
  end

  @impl true
  def handle_call({:reload_config, source}, _from, state) do
    case reload_configuration(state, source) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:validate_config, config}, _from, state) do
    result = validate_config_batch(state.validation_rules, config)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:add_config_listener, listener_fn}, _from, state) do
    updated_listeners = [listener_fn | state.change_listeners]
    {:reply, :ok, %{state | change_listeners: updated_listeners}}
  end

  @impl true
  def handle_call({:get_feature_flag, flag_name, default}, _from, state) do
    value = Map.get(state.feature_flags, flag_name, default)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:set_feature_flag, flag_name, value}, _from, state) do
    updated_flags = Map.put(state.feature_flags, flag_name, value)
    updated_state = %{state | feature_flags: updated_flags}

    # Notify listeners
    notify_config_change(state.change_listeners, {:feature_flag, flag_name}, value)

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:get_secret, secret_key}, _from, state) do
    case SecretsManager.retrieve_secret(state.secrets_manager, secret_key) do
      {{:ok, secret_value}, updated_manager} ->
        updated_state = %{state | secrets_manager: updated_manager}
        {:reply, {:ok, secret_value}, updated_state}

      {{:error, reason}, updated_manager} ->
        updated_state = %{state | secrets_manager: updated_manager}
        {:reply, {:error, reason}, updated_state}
    end
  end

  @impl true
  def handle_call({:set_secret, secret_key, secret_value}, _from, state) do
    updated_manager = SecretsManager.store_secret(state.secrets_manager, secret_key, secret_value)
    updated_state = %{state | secrets_manager: updated_manager}

    {:reply, :ok, updated_state}
  end

  # Private Implementation

  defp get_current_environment do
    System.get_env("MIX_ENV") || System.get_env("ENV") ||
      "development"
      |> String.to_atom()
  end

  defp initialize_validation_rules(opts) do
    default_schemas = %{
      task_execution:
        ConfigSchema.new(
          fields: %{
            max_concurrent_tasks: :integer,
            timeout: :integer,
            retry_attempts: :integer,
            scheduling_strategy: :atom
          },
          required_fields: [:max_concurrent_tasks],
          default_values: %{
            max_concurrent_tasks: 10,
            timeout: 30_000,
            retry_attempts: 3,
            scheduling_strategy: :priority
          },
          validation_rules: %{
            max_concurrent_tasks: [{:range, 1, 1000}],
            timeout: [{:range, 1000, 600_000}],
            retry_attempts: [{:range, 0, 10}],
            scheduling_strategy: [{:enum, [:fifo, :priority, :deadline, :resource_aware]}]
          }
        ),
      monitoring:
        ConfigSchema.new(
          fields: %{
            metrics_collection_interval: :integer,
            alert_thresholds: :map,
            export_targets: :list
          },
          default_values: %{
            metrics_collection_interval: 10_000,
            alert_thresholds: %{},
            export_targets: []
          }
        )
    }

    custom_schemas = Keyword.get(opts, :validation_schemas, %{})
    Map.merge(default_schemas, custom_schemas)
  end

  defp load_initial_configuration(state) do
    config_store =
      Enum.reduce(state.config_sources, %{}, fn source, acc ->
        case load_config_from_source(source, state.environment) do
          {:ok, config} -> deep_merge(acc, config)
          {:error, _reason} -> acc
        end
      end)

    %{state | config_store: config_store}
  end

  defp load_config_from_source(:file, environment) do
    config_files = [
      "config/config.exs",
      "config/#{environment}.exs",
      "config/local.exs"
    ]

    config =
      Enum.reduce(config_files, %{}, fn file_path, acc ->
        case File.exists?(file_path) do
          true ->
            case load_config_file(file_path) do
              {:ok, file_config} -> deep_merge(acc, file_config)
              {:error, _} -> acc
            end

          false ->
            acc
        end
      end)

    {:ok, config}
  end

  defp load_config_from_source(:environment, _environment) do
    env_config =
      System.get_env()
      |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "DSPY_") end)
      |> Enum.map(fn {key, value} ->
        config_key =
          key
          |> String.replace_prefix("DSPY_", "")
          |> String.downcase()
          |> String.to_atom()

        {config_key, parse_env_value(value)}
      end)
      |> Map.new()

    {:ok, env_config}
  end

  defp load_config_from_source(:etcd, _environment) do
    # Implementation for etcd configuration source
    {:ok, %{}}
  end

  defp load_config_from_source(:consul, _environment) do
    # Implementation for Consul configuration source
    {:ok, %{}}
  end

  defp load_config_from_source(_, _), do: {:error, :unsupported_source}

  defp load_config_file(file_path) do
    try do
      {config, _bindings} = Code.eval_file(file_path)
      {:ok, config}
    rescue
      error -> {:error, error}
    end
  end

  defp parse_env_value(value) do
    cond do
      value in ["true", "TRUE"] ->
        true

      value in ["false", "FALSE"] ->
        false

      Regex.match?(~r/^\d+$/, value) ->
        String.to_integer(value)

      Regex.match?(~r/^\d+\.\d+$/, value) ->
        String.to_float(value)

      String.starts_with?(value, "[") and String.ends_with?(value, "]") ->
        # Simple list parsing
        value
        |> String.slice(1..-2//1)
        |> String.split(",")
        |> Enum.map(&String.trim/1)

      true ->
        value
    end
  end

  defp get_config_value(config_store, key, default, environment) do
    # Try environment-specific config first, then general config
    case get_nested_value(config_store, [environment, key]) do
      nil ->
        case get_nested_value(config_store, [key]) do
          nil -> default
          value -> value
        end

      value ->
        value
    end
  end

  defp set_config_value(config_store, key, value, environment) do
    # Set in environment-specific section
    put_nested_value(config_store, [environment, key], value)
  end

  defp get_nested_value(map, []), do: map

  defp get_nested_value(map, [key | rest]) when is_map(map) do
    case Map.get(map, key) do
      nil -> nil
      value -> get_nested_value(value, rest)
    end
  end

  defp get_nested_value(_, _), do: nil

  defp put_nested_value(map, [key], value) do
    Map.put(map, key, value)
  end

  defp put_nested_value(map, [key | rest], value) do
    current = Map.get(map, key, %{})
    updated = put_nested_value(current, rest, value)
    Map.put(map, key, updated)
  end

  defp deep_merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _key, val1, val2 ->
      if is_map(val1) and is_map(val2) do
        deep_merge(val1, val2)
      else
        val2
      end
    end)
  end

  defp deep_merge(_map1, map2), do: map2

  defp validate_config_value(validation_rules, key, value) do
    case find_applicable_schema(validation_rules, key) do
      nil -> :ok
      schema -> ConfigSchema.validate(schema, %{key => value})
    end
  end

  defp validate_config_batch(validation_rules, config) do
    # Group by applicable schemas and validate each group
    schema_groups =
      Enum.group_by(config, fn {key, _value} ->
        find_applicable_schema(validation_rules, key)
      end)

    errors =
      Enum.reduce(schema_groups, [], fn {schema, key_values}, acc ->
        if schema do
          config_map = Map.new(key_values)

          case ConfigSchema.validate(schema, config_map) do
            :ok -> acc
            {:error, schema_errors} -> schema_errors ++ acc
          end
        else
          acc
        end
      end)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp find_applicable_schema(validation_rules, key) do
    # Find the first schema that contains this key
    Enum.find_value(validation_rules, fn {_schema_name, schema} ->
      if Map.has_key?(schema.fields, key) do
        schema
      else
        nil
      end
    end)
  end

  defp get_environment_specific_config(config_store, environment) do
    Map.get(config_store, environment, %{})
  end

  defp reload_configuration(state, :all) do
    try do
      updated_state = load_initial_configuration(state)
      {:ok, updated_state}
    rescue
      error -> {:error, error}
    end
  end

  defp reload_configuration(state, source) do
    case load_config_from_source(source, state.environment) do
      {:ok, new_config} ->
        updated_store = deep_merge(state.config_store, new_config)
        updated_state = %{state | config_store: updated_store}
        {:ok, updated_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp notify_config_change(listeners, key, value) do
    Enum.each(listeners, fn listener_fn ->
      spawn(fn ->
        try do
          listener_fn.(key, value)
        rescue
          error ->
            IO.puts("Config change listener error: #{inspect(error)}")
        end
      end)
    end)
  end

  defp generate_encryption_key do
    :crypto.strong_rand_bytes(32)
  end

  # Convenience functions for common configuration patterns

  def get_task_execution_config(manager \\ __MODULE__) do
    %{
      max_concurrent_tasks: get_config(manager, :max_concurrent_tasks, 10),
      timeout: get_config(manager, :timeout, 30_000),
      retry_attempts: get_config(manager, :retry_attempts, 3),
      scheduling_strategy: get_config(manager, :scheduling_strategy, :priority)
    }
  end

  def get_monitoring_config(manager \\ __MODULE__) do
    %{
      metrics_collection_interval: get_config(manager, :metrics_collection_interval, 10_000),
      alert_thresholds: get_config(manager, :alert_thresholds, %{}),
      export_targets: get_config(manager, :export_targets, [])
    }
  end

  def get_database_config(manager \\ __MODULE__) do
    %{
      host: get_config(manager, :database_host, "localhost"),
      port: get_config(manager, :database_port, 5432),
      database: get_config(manager, :database_name),
      username: get_config(manager, :database_username),
      password: get_secret(manager, :database_password)
    }
  end
end
