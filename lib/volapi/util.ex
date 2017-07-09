defmodule Volapi.Util do
  require Logger
  @server Application.get_env(:volapi, :server, "volafile.org")
  @volafile_room_url "https://#{@server}/r/<%= room %>"
  @volafile_login_url "https://#{@server}/rest/login?name=<%= name %>&password=<%= password %>"
  @moduledoc """
  This module is used for utility functions.
  """

  @doc """
  Random ID used for making a WS(S) connection to Volafile.
  The random ID is used in the rn param for the WS request.
  """
  def random_id(length) do
    :crypto.strong_rand_bytes(length + 5) |> Base.url_encode64(padding: false) |> String.slice(0, length)
  end

  def get_checksum() do
    HTTPoison.start

    {:ok, %{body: body}} = HTTPoison.get("https://#{@server}/static/js/main.js")

    # This returns the checksum. thanks dodos for the regex
    Regex.run(~r/config\.checksum\s*=\s*"(\w+?)"/, body) |> Enum.at(1)
  end

  def get_room_config(room) do
    import EEx
    HTTPoison.start

    {:ok, %{body: body}} = HTTPoison.get(EEx.eval_string(@volafile_room_url, [room: room]), [], [{:follow_redirect, true}])

    text = Regex.replace(~r'(\w+):(?=([^"\\]*(\\.|"([^"\\]*\\.)*[^"\\]*"))*[^"]*$)', body, "\"\\1\":")
    |> String.replace("\n", "")

    {:ok, config} = Regex.run(~r'config = ({.+});', text, capture: :all_but_first)
    |> Poison.decode

    config
  end

  def get_login_key(room) do
    HTTPoison.start

    nick = Application.get_env(:volapi, :nick)
    password = Application.get_env(:volapi, :password, nil)

    if password != nil do
      {:ok, %{body: body}} = HTTPoison.get(EEx.eval_string(@volafile_login_url, [name: nick, password: password]), [{"Accept", "application/json"}, {"Referer", "https://#{@server}"}])

      {:ok, resp} = Poison.decode(body)

      case resp do
        %{"error" => %{"code" => code, "message" => message}} ->
          {:error, "Couldn't login because of: #{message}"}
        %{"session" => session} ->
          {:success, session}
        lol ->
          IO.inspect lol
          {:error, "Couldn't pattern match on the /rest/login response."}
      end
    else
      {:error, "There is no password key in the config.exs file."}
    end
  end

  def login(room) do
    require Logger
    session = get_login_key(room)

    case session do
      {:error, message} ->
        Logger.error(message)
      {:success, key} ->
        Volapi.Client.Sender.login(key, room)
    end
  end

  def get_text_from_message(message) do
    case message do
      %Volapi.Message.Chat{} ->
        message.message
      %Volapi.Message.File{} ->
        message.file_name
      %Volapi.Message.Timeout{} ->
        message.name
      %Volapi.Message.UserCount{} ->
        message.user_count
    end
  end

  def upload(file_path, room) do
    upload(file_path, Path.basename(file_path), room)
  end

  def upload(file_path, filename, room) do
    Volexupload.main(Application.get_env(:volapi, :nick), room, file_path, filename)
  end



  def load_table(table) do
    load_table(table, [])
  end

  def load_table(table, options) do
    if File.exists?("#{get_dir()}/#{table}.db") do
      Logger.debug("Loading #{table} table from file.")
      :ets.file2tab('#{get_dir()}/#{table}.db')
      :loaded
    else
      Logger.debug("Creating new #{table} table.")
      :ets.new(table, Application.get_env(:volapi, :ets_options, []) ++ options)
      :created
    end
  end

  defp get_dir do
    Application.get_env(:volapi, :ets_table_dir, "priv/tables")
  end
end
