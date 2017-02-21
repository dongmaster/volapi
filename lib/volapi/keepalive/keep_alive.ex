defmodule Volapi.KeepAlive do
  use GenServer

  ## Client API

  def start_link(room) do
    GenServer.start_link(__MODULE__, room, name: {:global, "volapi_keepalive_" <> room})
  end

  def this(room) do
    :global.whereis_name("volapi_keepalive_" <> room)
  end

  def keep_alive(room) do
    GenServer.cast(this(room), :keep_alive)
  end

  ## Server API

  def init(room) do
    {:ok, %{room: room, timer: Process.send_after(self(), :init, 1)}}
  end

  def handle_info(:init, state) do
    {:noreply, state}
  end

  def handle_cast(:keep_alive, state) do
    timer =
      if state.timer == false do
        Process.send_after(this(state.room), :keep_alive_, 15_000)
      else
        Process.cancel_timer(state.timer)
        Process.send_after(this(state.room), :keep_alive_, 15_000)
      end

    {:noreply, Map.put(state, :timer, timer)}
  end

  def handle_info(:keep_alive_, state) do
    Volapi.Client.Sender.keep_alive(state.room)
    {:noreply, state}
  end
end
