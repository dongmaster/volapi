defmodule Volapi.WebSocket.Server do
  @behaviour :websocket_client
  @volafile_wss_url "wss://volafile.io/api/?rn=<%= rn %>&EIO=3&transport=websocket&t=<%= t %>"

  # Client API

  def start_link(room) do
    url = generate_wss_url(@volafile_wss_url)
    {:ok, pid} = result = :websocket_client.start_link(url, __MODULE__, %{room: room})
    :global.register_name("volapi_wss_" <> room, pid)
    result
  end

  def volaping(room, ping_reply) do
    :global.send("volapi_wss_" <>, {:volaping, Integer.to_string(ping_reply)})
  end

  # There are two ack's.
  # One is used for when the client (volapi) sends something and the other is used for when the server (volafile) sends something.
  def reply(data) do
    :global.send(:volapi_server, {:text, {:reply, data}})
    :ok
  end

  def generate_wss_url(volafile_wss_url) do
    rn = Volapi.Util.random_id(10)
    t = Volapi.Util.random_id(7)

    EEx.eval_string(volafile_wss_url, [rn: rn, t: t])
  end

  # Server API

  def init(%{}) do
    {:once, %{}}
  end

  def onconnect(wsreq, state) do
    # IO.inspect wsreq
    {:ok, state}
  end

  def ondisconnect({:remote, :closed}, state) do
    IO.inspect "Disconnected! State: "
    IO.inspect Volapi.Server.get_state
    {:reconnect, state}
  end

  def websocket_handle({:pong, _}, _conn_state, state) do
    {:ok, state}
  end

  def websocket_handle({:text, << "0" :: binary, data :: binary >>}, _conn_state, state) do
    IO.puts "Received message from 0"
    IO.inspect data

    Volapi.Client.Receiver.parse(Poison.decode(data))
    {:ok, state}
  end

  def websocket_handle({:text, << "4" :: binary, data :: binary >>}, _conn_state, state) do
    IO.puts "Received message from 4"
    #IO.inspect data

    Volapi.Client.Receiver.parse(Poison.decode(data))
    {:ok, state}
  end

  def websocket_handle({:text, something}, _conn_state, state) do
    IO.inspect something
    {:ok, state}
  end

  #def websocket_handle({:text, {:reply, data}}, _conn_state, state) do
  #  IO.inspect data
  #  {:reply, {:text, data}, state}
  #end

  # def websocket_info({:set_ack, {ack_type, ack}}, _conn_state, state) do
  #   {:ok, Map.put(state, ack_type, ack)}
  # end

  # def websocket_info({:delta_ack, {ack_type, delta}}, _conn_state, state) do
  #   {:ok, Map.put(state, ack_type, ack + delta)}
  # end

  def websocket_info({:volaping, ping_reply}, _conn_state, state) do
    IO.puts "sending a volaping"
    {:reply, {:text, ping_reply}, state}
  end

  def websocket_info({:text, {:reply, data}}, _conn_state, state) do
    IO.inspect data
    {:reply, {:text, "4" <> data}, state}
  end

  def websocket_info(:state, _conn_state, state) do
    IO.inspect state
    {:ok, state}
  end

  def websocket_info(:start, _conn_state, state) do
    IO.puts "help does this execute?"
    # {:reply, {:text, "erlang message received"}, state}
    {:ok, state}
  end

  def websocket_info(_something, _conn_state, state) do
    IO.puts "help does this execute? how about this"
    # {:reply, {:text, "erlang message received"}, state}
    {:ok, state}
  end

  def websocket_terminate(reason, conn_state, state) do
    IO.inspect "Terminated! Reason: #{reason} | state: #{state}"
    :ok
  end

end
