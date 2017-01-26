defmodule Volapi.Server do
  use GenServer
  defstruct [
    user_count: 0,
    client_ack: 0,
    server_ack: -1,
    chat: :queue.new(),
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

  @chat_limit 300

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

  def handle_call({:set_ack, {ack_type, ack}}, _from, state) do
    new_state = Map.put(state, ack_type, ack)
    {:reply, :ok, new_state}
  end

  def handle_call({:delta_ack, {ack_type, delta}}, _from, state) do
    new_state = Map.put(state, ack_type, Map.get(state, ack_type) + delta)
    {:reply, :ok, new_state}
  end

  def handle_call({:get_ack, ack_type}, _from, state) do
    ack = Map.get(state, ack_type)
    {:reply, ack, state}
  end

  # State

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_state_custom, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end

  def handle_call({:get_state_custom, key}, _from, state) do
    resp = Map.get(state, key)
    {:reply, resp, state}
  end

  # User Count

  def handle_call({:set_user_count, user_count}, _from, state) do
    new_state = Map.put(state, :user_count, user_count)
    {:reply, :ok, new_state}
  end

  def handle_call(:get_user_count, _from, state) do
    user_count = Map.get(state, :user_count)
    {:reply, user_count, state}
  end

  # Files

  def handle_call({:add_file, file}, _from, state) do
    files_state = Map.get(state, :files)
    new_files = [file | files_state]
    new_state = Map.put(state, :files, new_files)
    {:reply, :ok, new_state}
  end

  def handle_call({:add_files, files}, _from, state) do
    files_state = Map.get(state, :files)
    new_files = [files | files_state] |> List.flatten
    # Alternative solution below.
    # I have tested both very slightly and List.flatten seems to be faster overall.
    #Enum.reduce(files, files_state, fn(file, acc) ->
    #  [file | acc]
    #end)
    new_state = Map.put(state, :files, new_files)
    {:reply, :ok, new_state}
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

  def handle_call({:del_file, file}, _from, state) do
    new_files = Map.get(state, :files)
    |> Enum.reject(fn(x) ->
      x.file_id == file
    end)

    new_state = Map.put(state, :files, new_files)
    {:reply, :ok, new_state}
  end

  # Chat messages

  def handle_call({:add_message, message}, _from, state) do
    messages_state = Map.get(state, :chat)

    new_queue =
      case :queue.len(messages_state) do
        len when len >= @chat_limit ->
          {_, q} = :queue.out(messages_state)
          # The reason in_r is used instead of in is because if we don't use that, the order of the list when you use to_list on the queue is wrong (first item is the oldest item, which is not what we want in this case)
          :queue.in_r(message, q)
        len when len <= @chat_limit - 1 ->
          :queue.in_r(message, messages_state)
      end

    new_state = Map.put(state, :chat, new_queue)
    {:reply, :ok, new_state}
  end

  def handle_call(:get_messages, _from, state) do
    messages = Map.get(state, :chat) |> :queue.to_list
    {:reply, messages, state}
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

  def handle_call({:logged_in, logged_in}, _from, state) do
    state = Map.put(state, :logged_in, logged_in)
    {:reply, logged_in, state}
  end
end
