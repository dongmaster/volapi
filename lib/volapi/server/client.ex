defmodule Volapi.Server.Client do
  alias Volapi.Server.Util
  ## Client API

  #def start_link(room) do
  #  GenServer.start_link(Volapi.Server, %{}, name: {:global, "volapi_server_" <> room})
  #end

  def this(room) do
    :global.whereis_name("volapi_server_" <> room)
  end

  # Ack

  def set_ack(:server, ack, room) do
    GenServer.call(this(room), {:set_ack, {:server_ack, ack}})
  end

  def set_ack(:client, ack, room) do
    GenServer.call(this(room), {:set_ack, {:client_ack, ack}})
  end

  def get_ack(:server, room) do
    GenServer.call(this(room), {:get_ack, :server_ack})
  end

  def get_ack(:client, room) do
    GenServer.call(this(room), {:get_ack, :client_ack})
  end

  # Get State

  def get_state(room) do
    GenServer.call(this(room), :get_state)
  end

  # User count

  def set_user_count(user_count, room) do
    Util.cast(:user_count, user_count)

    GenServer.call(this(room), {:set_user_count, user_count})
  end

  def get_user_count(room) do
    GenServer.call(this(room), :get_user_count)
  end

  # Files

  def add_file(file, room) do
    Util.cast(:file, file)
    GenServer.call(this(room), {:add_file, file})
  end

  def add_files(files, room) do
    Util.cast_list(:file, files)

    GenServer.call(this(room), {:add_files, files})
  end

  def get_file(file_id, room) do
    GenServer.call(this(room), {:get_file, file_id})
  end

  def get_files(room) do
    GenServer.call(this(room), :get_files)
  end

  def del_file(file, room) do
    # The reason for using get_file here is that it is kind of retarded to just return the file_id of a deleted file.
    # It's not very useful by itself, thus it is much better to just return the whole file map.
    Util.cast(:file_delete, get_file(file, room))

    GenServer.call(this(room), {:del_file, file})
  end

  def del_files(files, room) do
    Util.cast_list(:file_delete, files)

    Enum.each(files, fn(x) ->
      GenServer.call(this(room), {:del_file, x})
    end)
  end

  # Chat messages

  def add_message(message, room) do
    Util.cast(:msg, message)

    GenServer.call(this(room), {:add_message, message})
  end

  def get_messages(room) do
    GenServer.call(this(room), :get_messages)
  end

  # Config

  def set_config(key, value, room) do
    GenServer.call(this(room), {:set_state_custom, key, value})
  end

  def get_config(key, room) do
    GenServer.call(this(room), {:get_state_custom, key})
  end

  # Timeouts

  def add_timeout(message, room) do
    Util.cast(:timeout, message)

    GenServer.call(this(room), {:add_timeout, message})
  end

  def get_timeouts(room) do
    GenServer.call(this(room), :get_timeouts)
  end

  # Login

  def login(message, room) do
    Util.cast(:logged_in, message)

    GenServer.call(this(room), {:logged_in, true})
  end

  def logout(message, room) do
    Util.cast(:logged_in, message)

    GenServer.call(this(room), {:logged_in, false})
  end
end
