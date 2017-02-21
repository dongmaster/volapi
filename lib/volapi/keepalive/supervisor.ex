defmodule Volapi.KeepAlive.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    #Logger.log :debug, "Starting modules!"
    rooms = Application.get_env(:volapi, :rooms, [])
    |> Enum.map(fn(room) -> worker(Volapi.KeepAlive, [room], id: "volapi_keepalive_supervisor_" <> room) end)
    |> supervise(strategy: :one_for_one)


    #load_modules
    #|> Enum.reverse
    #|> Enum.map(fn module -> worker(module, []) end)
    #|> supervise(strategy: :one_for_one)
  end
end
