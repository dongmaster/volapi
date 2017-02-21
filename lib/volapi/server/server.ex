defmodule Volapi.Server do
  use GenServer
  defstruct [
    user_count: 0,
    client_ack: 0,
    server_ack: -1,
    files: [],
    disabled: false,
    file_max_size: 0,
    file_time_to_live: 0,
    max_room_name_length: 0,
    logged_in: false,
    motd: "",
    name: "",
    owner: "",
    private: true,
    room_id: "",
    timeouts: [],
  ]

  ## Client API
  # The actual Client API is in Volapi.Server.Client

  def start_link(room) do
    GenServer.start_link(__MODULE__, room, name: {:global, "volapi_server_" <> room})
  end

  ## Server API

  def init(room) do
    state = %__MODULE__{}

    spawn(fn ->
      Volapi.Room.populate_config(room)
    end)

    {:ok, state}
  end

  # Ack

  def handle_cast({:set_ack, {ack_type, ack}}, state) do
    new_state = Map.put(state, ack_type, ack)
    {:noreply, new_state}
  end

  def handle_call({:get_ack, ack_type}, _from, state) do
    ack = Map.get(state, ack_type)
    {:reply, ack, state}
  end

  # State

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:set_state_custom, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  def handle_call({:get_state_custom, key}, _from, state) do
    resp = Map.get(state, key)
    {:reply, resp, state}
  end

  # User Count

  def handle_cast({:set_user_count, user_count}, state) do
    new_state = Map.put(state, :user_count, user_count)
    {:noreply, new_state}
  end

  def handle_call(:get_user_count, _from, state) do
    user_count = Map.get(state, :user_count)
    {:reply, user_count, state}
  end

  # Files

  def handle_cast({:add_file, file}, state) do
    files_state = Map.get(state, :files)
    new_files = [file | files_state]
    new_state = Map.put(state, :files, new_files)
    {:noreply, new_state}
  end

  def handle_cast({:add_files, files}, state) do
    files_state = Map.get(state, :files)
    new_files = [files | files_state] |> List.flatten
    # Alternative solution below.
    # I have tested both very slightly and List.flatten seems to be faster overall.
    #Enum.reduce(files, files_state, fn(file, acc) ->
    #  [file | acc]
    #end)
    new_state = Map.put(state, :files, new_files)
    {:noreply, new_state}
  end

  def handle_call({:get_file, file_id}, _from, state) do
    files = Map.get(state, :files)

    file = Enum.filter(files, fn(x) -> x.file_id == file_id end) |> hd

    {:reply, file, state}
  end

  def handle_call(:get_files, _from, state) do
    files = Map.get(state, :files)
    {:reply, files, state}
  end

  def handle_cast({:del_file, file}, state) do
    new_files = Map.get(state, :files)
    |> Enum.reject(fn(x) ->
      x.file_id == file
    end)

    new_state = Map.put(state, :files, new_files)
    {:noreply, new_state}
  end

  def handle_info({:del_file, file}, state) do
    spawn(fn ->
      GenServer.cast(Volapi.Server.Client.this(state.room_id), {:del_file, file})
    end)
  end

  # Timeouts

  def handle_call({:add_timeout, timeout}, _from, state) do
    timeouts_state = Map.get(state, :timeouts)

    new_timeouts = [timeout | timeouts_state]

    new_state = Map.put(state, :timeouts, new_timeouts)
    {:reply, timeout, new_state}
  end

  def handle_call(:get_timeouts, _from, state) do
    timeouts = Map.get(state, :timeouts)
    {:reply, timeouts, state}
  end

  # Logged in

  def handle_cast({:logged_in, logged_in}, state) do
    state = Map.put(state, :logged_in, logged_in)
    {:noreply, state}
  end
end
