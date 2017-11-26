defmodule Volapi.Client.Sender do
  @short 1800
  @medium 7200
  @long 86400

  @doc """
  Generic function for sending frames using the Volapi.WebSocket.Server
  """
  def gen_queue(frame, room) do
    Volapi.Queue.Messages.add_message(gen_build(frame, room), room)
  end

  def gen_send([], _room) do
  end

  def gen_send(frames, room) do
    {:ok, data} = gen_build_final(frames |> Enum.reverse(), room) |> Poison.encode

    Volapi.WebSocket.Server.reply(data, room)
  end

  @doc """
  Convenience function for building your own frames.
  Adds 1 to the client_ack automatically.
  """
  def gen_build(frame, room) do
    gen_build(frame, 1, room)
  end

  @doc """
  Convenience function for building your own frames.
  Takes a second parameter so you can decide your own client_ack offset.

  Be wary when using this so you don't set a wrong client_ack.
  """
  def gen_build(frame, client_ack_offset, room) do
    # server_ack = Volapi.Server.Client.get_ack(:server, room)
    client_ack = Volapi.Server.Client.get_ack(:client, room) + client_ack_offset
    Volapi.Server.Client.set_ack(:client, client_ack + 1, room)
    #[server_ack, [[0, frame], client_ack]]
    [[0, frame], client_ack]
  end

  def gen_build_final(frames, room) do
    server_ack = Volapi.Server.Client.get_ack(:server, room)
    [server_ack | frames]
  end

  @doc """
  Special internal function that should hopefully keep the connection alive.
  """
  def keep_alive(room) do
    {:ok, data} = [Volapi.Server.Client.get_ack(:server, room)] |> Poison.encode

    Volapi.WebSocket.Server.reply(data, room)
  end

  def subscribe(nick, room) do
    checksum = Volapi.Util.get_checksum(room)

    frame = ["subscribe", %{"nick" => nick, "room" => room, "checksum" => checksum, "checksum2" => checksum}]

    gen_queue(frame, room)
  end

  def send_message(message, room) do
    nick = Application.get_env(:volapi, :nick)
    send_message(message, nick, room)
  end

  def send_message(message, :me, room) do
    nick = Application.get_env(:volapi, :nick)

    frame = ["call", %{"fn" => "command", "args" => [nick, "me", message]}]

    gen_queue(frame, room)
  end

  def send_message(message, :admin, room) do
    nick = Application.get_env(:volapi, :nick)

    frame = ["call", %{"fn" => "command", "args" => [nick, "a", message]}]

    gen_queue(frame, room)
  end

  def send_message(message, nick, room) do
    frame = ["call", %{"args" => [nick, message], "fn" => "chat"}]

    gen_queue(frame, room)
  end

  def login(session, room) do
    frame = ["call", %{"fn" => "useSession", "args" => [session]}]

    gen_queue(frame, room)
  end

  def timeout_chat(id, nick, :short, room) do
    timeout_chat(id, nick, @short, room)
  end

  def timeout_chat(id, nick, :medium, room) do
    timeout_chat(id, nick, @medium, room)
  end

  def timeout_chat(id, nick, :long, room) do
    timeout_chat(id, nick, @long, room)
  end

  def timeout_chat(id, nick, room) do
    timeout_chat(id, nick, @medium, room)
  end

  @doc """
  `id` refers to the id key in the %Volapi.Chat{} struct.
  It is only available to room owners.

  The seconds argument can also be :short, :medium and :long.
  """
  def timeout_chat(id, nick, seconds, room) do
    frame = ["call", %{"fn" => "timeoutChat", "args" => [id, nick, seconds]}]

    gen_queue(frame, room)
  end


  def timeout_file(id, nick, :short, room) do
    timeout_file(id, nick, @short, room)
  end

  def timeout_file(id, nick, :medium, room) do
    timeout_file(id, nick, @medium, room)
  end

  def timeout_file(id, nick, :long, room) do
    timeout_file(id, nick, @long, room)
  end

  def timeout_file(id, nick, room) do
    timeout_file(id, nick, @medium, room)
  end

  @doc """
  `id` refers to the file_id key in any of the %Volapi.File.*{} structs.
  It is only available to room owners.
  """
  def timeout_file(id, nick, seconds, room) do
    frame = ["call", %{"fn" => "timeoutFile", "args" => [id, nick, seconds]}]

    gen_queue(frame, room)
  end

  @doc """
  The id returned by this is always a chat id, so use `timeout_chat` on id's that come from this function.
  """
  def get_timeouts(room) do
    frame = ["call", %{"fn" => "requestTimeoutList", "args" => []}]

    gen_queue(frame, room)
  end

  def ban_user(ip, ban_opts, room) do
    frame = ["call", %{"fn" => "banUser", "args" => [ip, ban_opts]}]

    gen_queue(frame, room)
  end

  def unban_user(ip, ban_opts, room) do
    frame = ["call", %{"fn" => "unbanUser", "args" => [ip, ban_opts]}]

    gen_queue(frame, room)
  end

  def delete_file(file_id, room) do
    frame = ["call", %{"fn" => "deleteFiles", "args" => [[file_id]]}]

    gen_queue(frame, room)
  end
end
