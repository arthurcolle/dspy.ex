defmodule DspyWeb.CoordinatorController do
  use DspyWeb, :controller
  alias Dspy.GodmodeCoordinator

  def execute_task(conn, %{"task" => task} = params) do
    case GodmodeCoordinator.execute_coordinated_task(task, params) do
      {:ok, result} -> json(conn, %{status: "success", result: result})
      {:error, reason} -> 
        conn
        |> put_status(400)
        |> json(%{status: "error", reason: reason})
    end
  end

  def override_behavior(conn, %{"target" => target} = params) do
    case GodmodeCoordinator.override_system_behavior(target, params) do
      :ok -> json(conn, %{status: "success"})
      {:error, reason} -> 
        conn
        |> put_status(400)
        |> json(%{status: "error", reason: reason})
    end
  end

  def system_hotswap(conn, params) do
    case GodmodeCoordinator.system_hotswap(params) do
      {:ok, result} -> json(conn, %{status: "success", result: result})
      {:error, reason} -> 
        conn
        |> put_status(400)
        |> json(%{status: "error", reason: reason})
    end
  end

  def system_status(conn, _params) do
    status = GodmodeCoordinator.get_system_status()
    json(conn, status)
  end

  def force_optimization(conn, _params) do
    case GodmodeCoordinator.force_system_optimization() do
      :ok -> json(conn, %{status: "success"})
      {:error, reason} -> 
        conn
        |> put_status(400)
        |> json(%{status: "error", reason: reason})
    end
  end
end