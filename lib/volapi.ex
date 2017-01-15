defmodule Volapi do
  use Application
  @volafile_wss_url "wss://volafile.io/api/?rn=<%= rn %>&EIO=3&transport=websocket&t=<%= t %>"

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    url = generate_wss_url(@volafile_wss_url)

    :pg2.start
    :pg2.create(:chat_handlers)
    :pg2.create(:file_handlers)
    :pg2.create(:modules)
    :ets.new(:modules, [:set, :named_table, :public, {:read_concurrency, true}, {:write_concurrency, true}])

    children = [
      worker(Volapi.Server, []),
      worker(Volapi.WebSocket.Server, [url]),
      supervisor(Volapi.Module.Supervisor, [[name: Volapi.Module.Supervisor]])
    ]

    opts = [strategy: :one_for_one, name: Volapi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def generate_wss_url(volafile_wss_url) do
    rn = Volapi.Util.random_id(10)
    t = Volapi.Util.random_id(7)

    EEx.eval_string(volafile_wss_url, [rn: rn, t: t])
  end
end
