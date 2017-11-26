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
      user: Map.get(options, "user", false), # This will be phased out/deprecated soon, will be changed to logged_in
      logged_in: Map.get(options, "user", false),
      files: Volapi.Message.Chat.get_files(message), # Files mentioned in the chat message
      rooms: Volapi.Message.Chat.get_rooms(message), # Rooms mentioned in the chat message
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

  def parse([[[_, ["config",
                   %{
                     "cdn_domain" => cdn_domain,
                     "chat_max_alias_length" => chat_max_alias_length,
                     "chat_max_history" => chat_max_history,
                     "chat_max_message_length" => chat_max_message_length,
                     "checksum2" => checksum2,
                     "created_time" => created_time,
                     "dmca_mail" => dmca_mail,
                     "download_cookie_lifetime" => download_cookie_lifetime,
                     "file_max_size" => file_max_size,
                     "file_time_to_live" => file_time_to_live,
                     "max_ban_message_length" => max_ban_message_length,
                     "max_concurrent_uploads" => max_concurrent_uploads,
                     "max_custom_room_id_length" => max_custom_room_id_length,
                     "max_report_text_length" => max_report_text_length,
                     "max_room_name_length" => max_room_name_length,
                     "name" => name,
                     "owner" => owner,
                     "private" => private,
                     "pro_reward_min_room_age" => pro_reward_min_room_age,
                     "room_disabled_redirect_timeout" => room_disabled_redirect_timeout,
                     "round_up_threshold" => round_up_threshold,
                     "session_lifetime" => session_lifetime,
                     "site" => site,
                     "sitename" => sitename,
                     "title_append" => title_append,
                     "ui_enable_gallery" => ui_enable_gallery,
                     "ui_gallery_buttons_hide_timeout" => ui_gallery_buttons_hide_timeout,
                     "ui_gallery_honor_filter" => ui_gallery_honor_filter,
                     "ui_gallery_title_hide_timeout" => ui_gallery_title_hide_timeout,
                     "ui_tooltip_show_delay" => ui_tooltip_show_delay
                   } = config]], server_ack] | t], room) do
    Volapi.Server.Util.cast(:config, %Volapi.Message.Config
      {
        cdn_domain: cdn_domain,
        chat_max_alias_length: chat_max_alias_length,
        chat_max_history: chat_max_history,
        chat_max_message_length: chat_max_message_length,
        checksum2: checksum2,
        created_time: created_time,
        dmca_mail: dmca_mail,
        download_cookie_lifetime: download_cookie_lifetime,
        file_max_size: file_max_size,
        file_time_to_live: file_time_to_live,
        max_ban_message_length: max_ban_message_length,
        max_concurrent_uploads: max_concurrent_uploads,
        max_custom_room_id_length: max_custom_room_id_length,
        max_report_text_length: max_report_text_length,
        max_room_name_length: max_room_name_length,
        name: name,
        owner: owner,
        private: private,
        pro_reward_min_room_age: pro_reward_min_room_age,
        room_disabled_redirect_timeout: room_disabled_redirect_timeout,
        round_up_threshold: round_up_threshold,
        session_lifetime: session_lifetime,
        site: site,
        sitename: sitename,
        title_append: title_append,
        ui_enable_gallery: ui_enable_gallery,
        ui_gallery_buttons_hide_timeout: ui_gallery_buttons_hide_timeout,
        ui_gallery_honor_filter: ui_gallery_honor_filter,
        ui_gallery_title_hide_timeout: ui_gallery_title_hide_timeout,
        ui_tooltip_show_delay: ui_tooltip_show_delay,
        room: room,
      })
    Volapi.Server.Client.set_config(:owner, owner, room)
    Volapi.Server.Client.set_config(:name, name, room)

    parse(t, room)
  end

  def parse([[[_, ["config", config]], server_ack] | t], room) do
    Volapi.Server.Util.cast(:config_raw, Map.put(config, :room, room))
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
        %{user: nick, artist: artist, album: album, ip: ip} =
          case metadata do
            %{"user" => uploader, "artist" => artist, "album" => album} ->
              %{user: uploader, artist: artist, album: album, ip: ""}
            %{"user" => uploader, "artist" => artist} ->
              %{user: uploader, artist: artist, album: "", ip: ""}
            %{"user" => uploader, "album" => album} ->
              %{user: uploader, artist: "", album: album, ip: ""}
            %{"user" => uploader} ->
              %{user: uploader, artist: "", album: "", ip: ""}
            # autism ->
            #   %{user: Map.get(autism, "user", ""), artist: Map.get(autism, "artist", ""), album: Map.get(autism, "album", ""), ip: Map.get(autism, "ip", "")}
            _ ->
              %{user: "", artist: "", album: "", ip: ""}
          end

        %Volapi.Message.File
        {
          file_id: file_id,
          file_name: file_name,
          file_type: file_type,
          file_size: file_size,
          file_expiration_time: file_expiration_time,
          file_life_time: file_life_time,
          ip: Map.get(metadata, "ip", ""),
          nick: nick,
          nick_alt: String.downcase(nick),
          artist: artist,
          album: album,
          room: room,
        }
      _ ->
        %Volapi.Message.File{}
    end)
  end
end
