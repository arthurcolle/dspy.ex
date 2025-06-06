defmodule Dspy.Settings do
  @moduledoc """
  Global configuration management for DSPy.

  Maintains settings like language model configuration, generation parameters,
  and optimization settings in a GenServer for thread-safe access.
  """

  use GenServer

  defstruct [
    :lm,
    max_tokens: 2048,
    temperature: 0.0,
    cache: true,
    experimental: []
  ]

  @type t :: %__MODULE__{
          lm: Dspy.LM.t() | nil,
          max_tokens: pos_integer(),
          temperature: float(),
          cache: boolean(),
          experimental: [atom()]
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Configure global DSPy settings.
  """
  def configure(opts) do
    GenServer.call(__MODULE__, {:configure, opts})
  end

  @doc """
  Get current settings.
  """
  def get do
    GenServer.call(__MODULE__, :get)
  end

  @doc """
  Get a specific setting.
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @impl true
  def init(opts) do
    settings = struct(__MODULE__, opts)
    {:ok, settings}
  end

  @impl true
  def handle_call({:configure, opts}, _from, settings) do
    new_settings = struct(settings, opts)
    {:reply, :ok, new_settings}
  end

  @impl true
  def handle_call(:get, _from, settings) do
    {:reply, settings, settings}
  end

  @impl true
  def handle_call({:get, key}, _from, settings) do
    value = Map.get(settings, key)
    {:reply, value, settings}
  end
end
