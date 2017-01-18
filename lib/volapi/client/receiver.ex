defmodule Volapi.Client.Receiver do
  import Logger

  # If a frame is sent by the server, the server_ack is the number at the end of the list. The client_ack is the first number
  # If a frame is sent by the client, the reverse applies to the above.

  # Receivers

  @doc """
  The first frame to be received by Volapi.
  """
  def parse({:ok, %{"pingInterval" => ping_interval, "pingTimeout" => ping_timeout, "sid" => sid, "upgrades" => upgrades}}) do
    :timer.apply_interval(ping_interval, __MODULE__, :ping, [])
    :ok
  end

  @doc """
  One of the first frames to be received by Volapi.
  """
  def parse({:ok, %{"version" => version, "session" => session, "ack" => ack}}) do
    Volapi.Server.set_ack(:server, ack)
    Volapi.Client.Sender.subscribe(Application.get_env(:volapi, :room), Application.get_env(:volapi, :nick))
  end

  def parse({:ok, [client_ack | frames]}) do
    Volapi.Server.set_ack(:client, client_ack)
    parse(frames)
  end

  def parse([]) do
    :ok
  end

  @doc """
  Stores the user count.
  """
  def parse([[[_, ["user_count", user_count]], server_ack] | t]) do
    Volapi.Server.set_ack(:server, server_ack)
    Volapi.Server.set_user_count(user_count)
    Logger.debug("User count: #{user_count}")
    parse(t)
  end

  @doc """
  Handles files
  """
  def parse([[[_, ["files", %{"files" => files}]], server_ack] | t]) do
    Volapi.Server.set_ack(:server, server_ack)

    handle_file(files)
    |> Volapi.Server.add_files

    parse(t)
  end

  @doc """
  Handles deleted files
  """
  def parse([[[_, ["delete_file", file_id]], server_ack] | t]) do
    Volapi.Server.set_ack(:server, server_ack)

    Volapi.Server.del_file(file_id)

    parse(t)
  end

  def parse([[[_, ["chat", %{"data" => data, "message" => message, "nick" => nick, "options" => options}]], server_ack] | t]) do
    Volapi.Server.set_ack(:server, server_ack)

    msg = %Volapi.Message.Chat
    {
      raw_message: message,
      message: Volapi.Message.Chat.raw_to_string(message),
      self: Map.get(data, "self", false),
      id: Map.get(data, "id", ""),
      ip: Map.get(data, "ip", ""),
      channel: Map.get(data, "channel", ""),
      nick: nick,
      nickd: String.downcase(nick),
      admin: Map.get(options, "admin", false),
      donator: Map.get(options, "donator", false),
      profile: Map.get(options, "profile", ""),
      staff: Map.get(options, "staff", false),
      user: Map.get(options, "user", false),
    }

    Volapi.Server.add_message(msg)
    parse(t)
  end

  def parse([[[_, ["chat", %{"message" => message, "nick" => nick, "options" => options}]], server_ack] | t]) do
    parse([[[0, ["chat", %{"data" => %{}, "message" => message, "nick" => nick, "options" => options}]], server_ack] | t])
  end

  def parse([[[_, ["subscribed", _]], server_ack] | t]) do
    Volapi.Server.set_ack(:server, server_ack)

    Volapi.Server.Util.cast(:connect, true)

    if Application.get_env(:volapi, :password, nil) do
      Volapi.Util.login
    end

    parse(t)
  end

  def parse([[[_, ["login", name]], server_ack] | t]) do
    Volapi.Server.Util.cast(:login, name)
    parse(t)
  end

  def parse([[[_, ["owner", %{"owner" => owner}]], server_ack] | t]) do
    Volapi.Server.Util.cast(:is_owner, owner)
    parse(t)
  end

  def parse([[[_, ["showTimeoutList", timeouts]], server_ack] | t]) do
    Enum.each(timeouts, fn(%{"id" => id, "name" => name, "date" => date}) ->
      Volapi.Server.add_timeout(%Volapi.Message.Timeout{id: id, name: name, date: date})
    end)
    parse(t)
  end

  def parse([[h, server_ack] | t]) do
    Volapi.Server.set_ack(:server, server_ack)
    IO.puts("Ignoring the following frame:")
    IO.inspect h
    IO.puts("Ignoring the above frame.")
    parse(t)
  end

  def ping do
    Volapi.WebSocket.Server.volaping(2)
  end

  def handle_file(files) do
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
        }
      _ ->
        %Volapi.Message.File{}
    end)
  end
end
