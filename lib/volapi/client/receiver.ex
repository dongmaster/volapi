defmodule Volapi.Client.Receiver do
  import Logger

  # If a frame is sent by the server, the server_ack is the number at the end of the list. The client_ack is the first number
  # If a frame is sent by the client, the reverse applies to the above.

  # Receivers

  @doc """
  The first frame to be received by Volapi.
  """
  def parse({:ok, %{"pingInterval" => ping_interval, "pingTimeout" => ping_timeout, "sid" => sid, "upgrades" => upgrades}}, room) do
    :timer.apply_interval(ping_interval, __MODULE__, :ping, [room])
    :ok
  end

  @doc """
  One of the first frames to be received by Volapi.
  """
  def parse({:ok, %{"version" => version, "session" => session, "ack" => ack}}, room) do
    Volapi.Server.Client.set_ack(:server, ack, room)
    Volapi.Client.Sender.subscribe(Application.get_env(:volapi, :nick), room)
  end

  def parse({:ok, [client_ack | frames]}, room) do
    Volapi.Server.Client.set_ack(:client, client_ack, room)
    Volapi.KeepAlive.keep_alive(room)
    parse(frames, room)
  end

  def parse([], room) do
    :ok
  end

  @doc """
  Stores the user count.
  """
  def parse([[[_, ["user_count", user_count]], server_ack] | t], room) do
    Volapi.Server.Client.set_ack(:server, server_ack, room)
    Volapi.Server.Client.set_user_count(%Volapi.Message.UserCount{user_count: user_count, room: room}, room)
    parse(t, room)
  end

  @doc """
  Handles files
  """
  def parse([[[_, ["files", %{"files" => files}]], server_ack] | t], room) do
    Volapi.Server.Client.set_ack(:server, server_ack, room)

    handle_file(files, room)
    |> Volapi.Server.Client.add_files(room)

    parse(t, room)
  end

  @doc """
  Handles deleted files
  """
  def parse([[[_, ["delete_file", file_id]], server_ack] | t], room) do
    Volapi.Server.Client.set_ack(:server, server_ack, room)

    Volapi.Server.Client.del_file(file_id, room)

    parse(t, room)
  end

  def parse([[[_, ["chat", %{"data" => data, "message" => message, "nick" => nick, "options" => options}]], server_ack] | t], room) do
    Volapi.Server.Client.set_ack(:server, server_ack, room)

    msg = %Volapi.Message.Chat
    {
      raw_message: message,
      message: Volapi.Message.Chat.raw_to_string(message),
      message_alt: Volapi.Message.Chat.raw_to_string_alternate(message),
      room: room,
      self: Map.get(data, "self", false),
      id: Map.get(data, "id", ""),
      ip: Map.get(data, "ip", ""),
      channel: Map.get(data, "channel", ""),
      nick: nick,
      nick_alt: String.downcase(nick),
      admin: Map.get(options, "admin", false),
      donator: Map.get(options, "donator", false),
      profile: Map.get(options, "profile", ""),
      staff: Map.get(options, "staff", false),
      user: Map.get(options, "user", false),
    }

    Volapi.Server.Client.add_message(msg, room)
    parse(t, room)
  end

  def parse([[[_, ["chat", %{"message" => message, "nick" => nick, "options" => options}]], server_ack] | t], room) do
    parse([[[0, ["chat", %{"data" => %{}, "message" => message, "nick" => nick, "options" => options}]], server_ack] | t], room)
  end

  def parse([[[_, ["subscribed", _]], server_ack] | t], room) do
    Volapi.Server.Client.set_ack(:server, server_ack, room)

    Volapi.Server.Util.cast(:connect, %Volapi.Message.Connected{connected: true, room: room})

    if Application.get_env(:volapi, :password, nil) != nil and Application.get_env(:volapi, :auto_login, false) == true do
      Volapi.Util.login(room)
    end

    parse(t, room)
  end

  def parse([[[_, ["login", name]], server_ack] | t], room) do
    Volapi.Server.Client.login(%Volapi.Message.Login{logged_in: true, nick: name, room: room}, room)
    parse(t, room)
  end

  def parse([[[_, ["logout", _]], server_ack] | t], room) do
    Volapi.Server.Client.logout(%Volapi.Message.Login{logged_in: false, room: room}, room)
    parse(t, room)
  end

  def parse([[[_, ["owner", %{"owner" => owner}]], server_ack] | t], room) do
    Volapi.Server.Util.cast(:is_owner, owner)
    parse(t, room)
  end

  def parse([[[_, ["showTimeoutList", timeouts]], server_ack] | t], room) do
    Enum.each(timeouts, fn(%{"id" => id, "name" => name, "date" => date}) ->
      Volapi.Server.Client.add_timeout(%Volapi.Message.Timeout{id: id, name: name, date: date}, room)
    end)
    parse(t, room)
  end

  def parse([[[_, ["roomScore", room_score]], server_ack] | t], room) do
    Volapi.Server.Client.set_config(:room_score, room_score, room)
    parse(t, room)
  end

  def parse([[h, server_ack] | t], room) do
    Volapi.Server.Client.set_ack(:server, server_ack, room)
    IO.puts("Ignoring the following frame:")
    IO.inspect h
    IO.puts("Ignoring the above frame.")
    parse(t, room)
  end

  def ping(room) do
    Volapi.WebSocket.Server.volaping(2, room)
  end

  def handle_file(files, room) do
    Enum.map(files, fn
      [file_id, file_name, file_type, file_size, file_expiration_time, file_life_time, metadata, _] ->
        metadata =
          case metadata do
            %{"user" => uploader, "artist" => artist, "album" => album} ->
              %{user: uploader, artist: artist, album: album}
            %{"user" => uploader, "artist" => artist} ->
              %{user: uploader, artist: artist, album: ""}
            %{"user" => uploader, "album" => album} ->
              %{user: uploader, artist: "", album: album}
            %{"user" => uploader} ->
              %{user: uploader, artist: "", album: ""}
            _ ->
              %{user: "", artist: "", album: ""}
          end

        %Volapi.Message.File
        {
          file_id: file_id,
          file_name: file_name,
          file_type: file_type,
          file_size: file_size,
          file_expiration_time: file_expiration_time,
          file_life_time: file_life_time,
          metadata: metadata,
          room: room,
        }
      _ ->
        %Volapi.Message.File{}
    end)
  end
end
