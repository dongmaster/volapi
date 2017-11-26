defmodule Volapi do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false


    :pg2.start
    :pg2.create(:modules)
    :ets.new(:modules, [:set, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    tables = Application.get_env(:volapi, :ets_tables, [])

    Enum.each(tables, fn
      {table, options} ->
        Volapi.Util.load_table(table, options)
      table when is_atom(table) ->
        Volapi.Util.load_table(table)
    end)

    children = [
      #worker(Volapi.Server, []),
      #worker(Volapi.WebSocket.Server, [url]),
      supervisor(Volapi.Queue.Messages.Supervisor, []),
      supervisor(Volapi.Server.Supervisor, []),
      supervisor(Volapi.WebSocket.Supervisor, []),
      supervisor(Volapi.KeepAlive.Supervisor, []),
      supervisor(Volapi.Module.Supervisor, [[name: Volapi.Module.Supervisor]])
    ]

    opts = [strategy: :one_for_one, name: Volapi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
