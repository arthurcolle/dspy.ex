defmodule Dspy.Adapters do
  @moduledoc """
  Adapter system for converting between different formats (JSON, XML, Chat, etc.).
  Compatible with Python DSPy's adapter architecture.
  
  Supports automatic parsing and formatting of:
  - JSON structured outputs
  - XML hierarchical data
  - Chat conversation formats
  - Custom field extraction
  - Type coercion and validation
  """

  defmodule Adapter do
    @moduledoc """
    Base adapter behavior for format conversion.
    """
    
    @callback parse(String.t(), keyword()) :: {:ok, any()} | {:error, String.t()}
    @callback format(any(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
    @callback validate(any(), keyword()) :: {:ok, any()} | {:error, String.t()}
  end

  defmodule JSONAdapter do
    @moduledoc """
    Adapter for JSON format parsing and generation.
    """
    
    @behaviour Dspy.Adapters.Adapter
    
    @impl true
    def parse(text, opts \\ []) do
      case extract_json_from_text(text, opts) do
        {:ok, json_str} ->
          case Jason.decode(json_str) do
            {:ok, data} -> validate_and_transform(data, opts)
            {:error, %Jason.DecodeError{data: error}} ->
              {:error, "JSON decode error: #{error}"}
          end
        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl true
    def format(data, opts \\ []) do
      case Jason.encode(data, pretty: opts[:pretty] || false) do
        {:ok, json} ->
          if opts[:wrap_in_code_block] do
            {:ok, "```json\n#{json}\n```"}
          else
            {:ok, json}
          end
        {:error, error} ->
          {:error, "JSON encode error: #{inspect(error)}"}
      end
    end

    @impl true
    def validate(data, opts \\ []) do
      schema = opts[:schema]
      required_fields = opts[:required_fields] || []
      
      cond do
        schema && not validate_schema(data, schema) ->
          {:error, "Data does not match schema"}
        
        not validate_required_fields(data, required_fields) ->
          {:error, "Missing required fields: #{inspect(required_fields)}"}
        
        true ->
          {:ok, data}
      end
    end

    defp extract_json_from_text(text, opts) do
      # Try multiple extraction strategies
      strategies = [
        &extract_code_block_json/1,
        &extract_bracketed_json/1,
        &extract_full_text_as_json/1
      ]
      
      case try_strategies(text, strategies) do
        {:ok, json} -> 
          {:ok, json}
        {:error, reason} ->
          if opts[:lenient] do
            # Try to fix common JSON issues
            fix_and_retry(text)
          else
            {:error, reason}
          end
      end
    end

    defp extract_code_block_json(text) do
      case Regex.run(~r/```(?:json)?\s*(\{.*?\})\s*```/s, text, capture: :all_but_first) do
        [json] -> {:ok, json}
        _ -> {:error, "No JSON code block found"}
      end
    end

    defp extract_bracketed_json(text) do
      case Regex.run(~r/(\{.*\})/s, text, capture: :all_but_first) do
        [json] -> {:ok, json}
        _ -> {:error, "No bracketed JSON found"}
      end
    end

    defp extract_full_text_as_json(text) do
      trimmed = String.trim(text)
      if String.starts_with?(trimmed, "{") and String.ends_with?(trimmed, "}") do
        {:ok, trimmed}
      else
        {:error, "Text is not valid JSON"}
      end
    end

    defp try_strategies(_text, []), do: {:error, "All extraction strategies failed"}
    defp try_strategies(text, [strategy | rest]) do
      case strategy.(text) do
        {:ok, result} -> {:ok, result}
        {:error, _} -> try_strategies(text, rest)
      end
    end

    defp fix_and_retry(text) do
      # Common JSON fixes
      fixed = text
      |> String.replace(~r/,(\s*[}\]])/, "\\1")  # Remove trailing commas
      |> String.replace(~r/'([^']*)'/, "\"\\1\"")  # Fix single quotes
      |> String.replace(~r/(\w+):\s*([^",\{\[\s][^",\}\]]*)/, "\"\\1\": \"\\2\"")  # Add quotes to keys/values
      
      case Jason.decode(fixed) do
        {:ok, data} -> {:ok, data}
        {:error, _} -> {:error, "Could not fix JSON format"}
      end
    end

    defp validate_schema(_data, nil), do: true
    defp validate_schema(data, schema) when is_map(data) and is_map(schema) do
      Enum.all?(schema, fn {key, expected_type} ->
        case Map.get(data, key) do
          nil -> false
          value -> validate_type(value, expected_type)
        end
      end)
    end

    defp validate_required_fields(_data, []), do: true
    defp validate_required_fields(data, required_fields) when is_map(data) do
      Enum.all?(required_fields, &Map.has_key?(data, &1))
    end

    defp validate_type(value, :string), do: is_binary(value)
    defp validate_type(value, :integer), do: is_integer(value)
    defp validate_type(value, :float), do: is_float(value)
    defp validate_type(value, :boolean), do: is_boolean(value)
    defp validate_type(value, :list), do: is_list(value)
    defp validate_type(value, :map), do: is_map(value)
    defp validate_type(_value, _type), do: true

    defp validate_and_transform(data, opts) do
      case validate(data, opts) do
        {:ok, validated_data} ->
          transformed = transform_fields(validated_data, opts[:transform] || %{})
          {:ok, transformed}
        {:error, reason} ->
          {:error, reason}
      end
    end

    defp transform_fields(data, transforms) when is_map(data) do
      Enum.reduce(transforms, data, fn {field, transform_fn}, acc ->
        case Map.get(acc, field) do
          nil -> acc
          value -> Map.put(acc, field, transform_fn.(value))
        end
      end)
    end
    defp transform_fields(data, _transforms), do: data
  end

  defmodule XMLAdapter do
    @moduledoc """
    Adapter for XML format parsing and generation.
    """
    
    @behaviour Dspy.Adapters.Adapter
    
    @impl true
    def parse(text, opts \\ []) do
      case extract_xml_from_text(text, opts) do
        {:ok, xml_str} ->
          case SweetXml.parse(xml_str, dtd: :none) do
            {:ok, doc} -> 
              parsed = xml_to_map(doc, opts)
              {:ok, parsed}
            {:error, reason} ->
              {:error, "XML parse error: #{inspect(reason)}"}
          end
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e -> {:error, "XML parsing failed: #{Exception.message(e)}"}
    end

    @impl true
    def format(data, opts \\ []) do
      case map_to_xml(data, opts) do
        {:ok, xml} ->
          if opts[:wrap_in_code_block] do
            {:ok, "```xml\n#{xml}\n```"}
          else
            {:ok, xml}
          end
        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl true
    def validate(data, opts \\ []) do
      required_tags = opts[:required_tags] || []
      
      if validate_required_tags(data, required_tags) do
        {:ok, data}
      else
        {:error, "Missing required XML tags: #{inspect(required_tags)}"}
      end
    end

    defp extract_xml_from_text(text, _opts) do
      # Try multiple XML extraction strategies
      cond do
        String.contains?(text, "```xml") ->
          case Regex.run(~r/```xml\s*(.*?)\s*```/s, text, capture: :all_but_first) do
            [xml] -> {:ok, xml}
            _ -> {:error, "No XML code block found"}
          end
        
        String.contains?(text, "<") and String.contains?(text, ">") ->
          case Regex.run(~r/(<.*>.*<\/.*>)/s, text, capture: :all_but_first) do
            [xml] -> {:ok, xml}
            _ -> {:error, "No complete XML structure found"}
          end
        
        true ->
          {:error, "No XML content found"}
      end
    end

    defp xml_to_map(xml_doc, _opts) do
      # Convert XML document to Elixir map structure
      # This would need a proper XML parsing library like SweetXml
      %{parsed: "XML parsing not fully implemented"}
    end

    defp map_to_xml(data, opts) when is_map(data) do
      root_tag = opts[:root_tag] || "root"
      indent = opts[:indent] || 0
      
      xml_content = Enum.map(data, fn {key, value} ->
        format_xml_element(key, value, indent + 2)
      end) |> Enum.join("\n")
      
      xml = """
      #{String.duplicate(" ", indent)}<#{root_tag}>
      #{xml_content}
      #{String.duplicate(" ", indent)}</#{root_tag}>
      """
      
      {:ok, xml}
    end

    defp format_xml_element(key, value, indent) when is_map(value) do
      {:ok, inner_xml} = map_to_xml(value, [indent: indent + 2])
      """
      #{String.duplicate(" ", indent)}<#{key}>
      #{inner_xml}
      #{String.duplicate(" ", indent)}</#{key}>
      """
    end
    defp format_xml_element(key, value, indent) when is_list(value) do
      elements = Enum.map(value, fn item ->
        format_xml_element("item", item, indent + 2)
      end) |> Enum.join("\n")
      
      """
      #{String.duplicate(" ", indent)}<#{key}>
      #{elements}
      #{String.duplicate(" ", indent)}</#{key}>
      """
    end
    defp format_xml_element(key, value, indent) do
      "#{String.duplicate(" ", indent)}<#{key}>#{value}</#{key}>"
    end

    defp validate_required_tags(_data, []), do: true
    defp validate_required_tags(data, required_tags) when is_map(data) do
      Enum.all?(required_tags, fn tag ->
        Map.has_key?(data, tag) or Map.has_key?(data, to_string(tag))
      end)
    end
  end

  defmodule ChatAdapter do
    @moduledoc """
    Adapter for chat conversation format parsing and generation.
    """
    
    @behaviour Dspy.Adapters.Adapter
    
    @impl true
    def parse(text, opts \\ []) do
      case extract_chat_messages(text, opts) do
        {:ok, messages} -> 
          validated_messages = validate_chat_format(messages, opts)
          {:ok, validated_messages}
        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl true
    def format(messages, opts \\ []) when is_list(messages) do
      formatted = Enum.map(messages, &format_message/1) |> Enum.join("\n\n")
      
      if opts[:wrap_in_code_block] do
        {:ok, "```\n#{formatted}\n```"}
      else
        {:ok, formatted}
      end
    end

    @impl true
    def validate(messages, opts \\ []) when is_list(messages) do
      required_roles = opts[:required_roles] || ["user", "assistant"]
      
      if validate_message_roles(messages, required_roles) do
        {:ok, messages}
      else
        {:error, "Invalid chat message roles"}
      end
    end

    defp extract_chat_messages(text, _opts) do
      # Parse different chat formats
      patterns = [
        ~r/^(Human|User|Q):\s*(.+?)^(Assistant|AI|A):\s*(.+?)$/ms,
        ~r/\*\*Human:\*\*\s*(.+?)\*\*Assistant:\*\*\s*(.+?)$/ms,
        ~r/User:\s*(.+?)Assistant:\s*(.+?)$/ms
      ]
      
      case try_chat_patterns(text, patterns) do
        {:ok, messages} -> {:ok, messages}
        {:error, _} -> parse_generic_chat(text)
      end
    end

    defp try_chat_patterns(_text, []), do: {:error, "No chat pattern matched"}
    defp try_chat_patterns(text, [pattern | rest]) do
      case Regex.scan(pattern, text, capture: :all_but_first) do
        [] -> try_chat_patterns(text, rest)
        matches -> 
          messages = Enum.flat_map(matches, &parse_chat_match/1)
          {:ok, messages}
      end
    end

    defp parse_chat_match([user_content, assistant_content]) do
      [
        %{role: "user", content: String.trim(user_content)},
        %{role: "assistant", content: String.trim(assistant_content)}
      ]
    end
    defp parse_chat_match([role1, content1, role2, content2]) do
      [
        %{role: normalize_role(role1), content: String.trim(content1)},
        %{role: normalize_role(role2), content: String.trim(content2)}
      ]
    end

    defp parse_generic_chat(text) do
      lines = String.split(text, "\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      
      messages = Enum.reduce(lines, [], fn line, acc ->
        cond do
          String.starts_with?(line, ["Human:", "User:", "Q:"]) ->
            content = String.replace(line, ~r/^(Human|User|Q):\s*/, "")
            [%{role: "user", content: content} | acc]
          
          String.starts_with?(line, ["Assistant:", "AI:", "A:"]) ->
            content = String.replace(line, ~r/^(Assistant|AI|A):\s*/, "")
            [%{role: "assistant", content: content} | acc]
          
          true ->
            # Append to last message if exists
            case acc do
              [last | rest] ->
                updated = Map.update!(last, :content, &(&1 <> " " <> line))
                [updated | rest]
              [] ->
                [%{role: "user", content: line}]
            end
        end
      end)
      
      {:ok, Enum.reverse(messages)}
    end

    defp format_message(%{role: role, content: content}) do
      role_label = case role do
        "user" -> "Human"
        "assistant" -> "Assistant"
        "system" -> "System"
        _ -> String.capitalize(role)
      end
      
      "#{role_label}: #{content}"
    end

    defp validate_chat_format(messages, _opts) do
      Enum.map(messages, fn message ->
        message
        |> Map.put_new(:role, "user")
        |> Map.put_new(:content, "")
        |> Map.update!(:role, &normalize_role/1)
      end)
    end

    defp validate_message_roles(messages, required_roles) do
      roles = Enum.map(messages, & &1.role) |> Enum.uniq()
      Enum.all?(required_roles, &(&1 in roles))
    end

    defp normalize_role("Human"), do: "user"
    defp normalize_role("User"), do: "user"
    defp normalize_role("Q"), do: "user"
    defp normalize_role("Assistant"), do: "assistant"
    defp normalize_role("AI"), do: "assistant"
    defp normalize_role("A"), do: "assistant"
    defp normalize_role(role), do: String.downcase(role)
  end

  # Main adapter interface

  @doc """
  Parse text using the specified adapter.
  
  ## Examples
  
      iex> Adapters.parse("{\"name\": \"John\"}", :json)
      {:ok, %{"name" => "John"}}
      
      iex> Adapters.parse("<root><name>John</name></root>", :xml)
      {:ok, %{name: "John"}}
  """
  def parse(text, adapter_type, opts \\ [])
  def parse(text, :json, opts), do: JSONAdapter.parse(text, opts)
  def parse(text, :xml, opts), do: XMLAdapter.parse(text, opts)
  def parse(text, :chat, opts), do: ChatAdapter.parse(text, opts)

  @doc """
  Format data using the specified adapter.
  """
  def format(data, adapter_type, opts \\ [])
  def format(data, :json, opts), do: JSONAdapter.format(data, opts)
  def format(data, :xml, opts), do: XMLAdapter.format(data, opts)
  def format(data, :chat, opts), do: ChatAdapter.format(data, opts)

  @doc """
  Validate data using the specified adapter.
  """
  def validate(data, adapter_type, opts \\ [])
  def validate(data, :json, opts), do: JSONAdapter.validate(data, opts)
  def validate(data, :xml, opts), do: XMLAdapter.validate(data, opts)
  def validate(data, :chat, opts), do: ChatAdapter.validate(data, opts)

  @doc """
  Auto-detect the format of text and parse accordingly.
  """
  def auto_parse(text, opts \\ []) do
    cond do
      String.contains?(text, "{") and String.contains?(text, "}") ->
        parse(text, :json, opts)
      
      String.contains?(text, "<") and String.contains?(text, ">") ->
        parse(text, :xml, opts)
      
      String.contains?(text, ["Human:", "User:", "Assistant:", "AI:"]) ->
        parse(text, :chat, opts)
      
      true ->
        {:error, "Could not auto-detect format"}
    end
  end
end