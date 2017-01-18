defmodule Volapi do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false


    :pg2.start
    :pg2.create(:modules)
    :ets.new(:modules, [:set, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    children = [
      #worker(Volapi.Server, []),
      #worker(Volapi.WebSocket.Server, [url]),
      supervisor(Volapi.Server.Supervisor, [])
      supervisor(Volapi.WebSocket.Supervisor, []),
      supervisor(Volapi.Module.Supervisor, [[name: Volapi.Module.Supervisor]])
    ]

    opts = [strategy: :one_for_one, name: Volapi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
