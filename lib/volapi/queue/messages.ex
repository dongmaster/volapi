defmodule Volapi.Queue.Messages do
  use GenServer
  @send_interval 50

  def this(room) do
    :global.whereis_name("volapi_queue_messages_" <> room)
  end

  ## Client API

  def add_message(message, room) do
    GenServer.cast(this(room), {:add_message, message})
  end

  ## Server API

  def start_link(room) do
    GenServer.start_link(__MODULE__, %{room: room, messages: []}, name: {:global, "volapi_queue_messages_" <> room})
  end

  def init(state) do
    Process.send_after(self(), :send_messages, @send_interval)
    {:ok, state}
  end

  def handle_cast({:add_message, message}, state) do
    new_messages = [message | Map.get(state, :messages, [])]

    new_messages =
      if Enum.count(new_messages) > 50 do
        Volapi.Client.Sender.gen_send(Map.get(state, :messages, []), Map.get(state, :room))
        []
      else
        new_messages
      end

    {:noreply, Map.put(state, :messages, new_messages)}
  end

  def handle_info(:send_messages, state) do
    # Send messages here
    Volapi.Client.Sender.gen_send(Map.get(state, :messages, []), Map.get(state, :room))
    Process.send_after(self(), :send_messages, @send_interval)

    {:noreply, Map.put(state, :messages, [])}
  end
end
