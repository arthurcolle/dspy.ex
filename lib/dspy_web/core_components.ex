defmodule DspyWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for the DSPy Godmode interface.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Flash group component for displaying notifications.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div class="flash-group">
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end

  @doc """
  Flash message component.
  """
  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error], required: true
  attr :title, :string, required: true

  def flash(%{kind: :info} = assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      class="flash flash-info"
      phx-click={hide_flash(@kind)}
      phx-hook="Flash"
    >
      <div class="flash-content">
        <div class="flash-icon">✅</div>
        <div class="flash-message">
          <p class="flash-title"><%= @title %></p>
          <p><%= msg %></p>
        </div>
        <button class="flash-close" aria-label="close">✕</button>
      </div>
    </div>
    """
  end

  def flash(%{kind: :error} = assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      class="flash flash-error"
      phx-click={hide_flash(@kind)}
      phx-hook="Flash"
    >
      <div class="flash-content">
        <div class="flash-icon">❌</div>
        <div class="flash-message">
          <p class="flash-title"><%= @title %></p>
          <p><%= msg %></p>
        </div>
        <button class="flash-close" aria-label="close">✕</button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a custom title for the page with suffix support.
  """
  attr :suffix, :string, default: ""
  slot :inner_block, required: true

  def custom_live_title(assigns) do
    ~H"""
    <title><%= render_slot(@inner_block) %><%= @suffix %></title>
    """
  end

  defp hide_flash(kind) do
    JS.push("lv:clear-flash", value: %{key: kind})
    |> JS.hide(
      to: "#flash-#{kind}",
      transition: "fade-out-scale",
      time: 200
    )
  end
end