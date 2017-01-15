defmodule Volapi.Client.Sender do

  @doc """
  Generic function for sending frames using the Volapi.WebSocket.Server
  """
  def gen_send(frame) do
    {:ok, data} = gen_build(frame) |> Poison.encode

    Volapi.WebSocket.Server.reply(data)
  end

  @doc """
  Convenience function for building your own frames.
  Adds 1 to the client_ack automatically.
  """
  def gen_build(frame) do
    gen_build(frame, 1)
  end

  @doc """
  Convenience function for building your own frames.
  Takes a second parameter so you can decide your own client_ack offset.

  Be wary when using this so you don't set a wrong client_ack.
  """
  def gen_build(frame, client_ack_offset) do
    server_ack = Volapi.Server.get_ack(:server)
    client_ack = Volapi.Server.get_ack(:client) + client_ack_offset
    [server_ack, [[0, frame], client_ack]]
  end

  def subscribe(room, nick) do
    checksum = Volapi.Util.get_checksum()

    frame = ["subscribe", %{"nick" => nick, "room" => room, "checksum" => checksum, "checksum2" => checksum}]

    gen_send(frame)
  end

  def send_message(message) do
    nick = Application.get_env(:volapi, :nick)

    frame = ["call", %{"args" => [nick, message], "fn" => "chat"}]

    gen_send(frame)
  end

  def login(session) do
    frame = ["call", %{"fn" => "useSession", "args" => [session]}]

    gen_send(frame)
  end

  @doc """
  `id` refers to the id key in the %Volapi.Chat{} struct.
  It is only available to room owners.
  """
  def timeout_chat(id, nick) do
    frame = ["call", %{"fn" => "timeoutChat", "args" => [id, nick]}]

    gen_send(frame)
  end

  @doc """
  `id` refers to the file_id key in any of the %Volapi.File.*{} structs.
  """
  def timeout_file(id, nick) do
    frame = ["call", %{"fn" => "timeoutFile", "args" => [id, nick]}]

    gen_send(frame)
  end

  def get_timeouts() do
    frame = ["call", %{"fn" => "requestTimeoutList", "args" => []}]

    gen_send(frame)
  end

  def ban_user(ip, ban_opts) do
    frame = ["call", %{"fn" => "banUser", "args" => [ip, ban_opts]}]

    gen_send(frame)
  end
end
