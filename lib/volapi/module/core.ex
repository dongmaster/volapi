defmodule Volapi.Module.Core do
  #use Volapi.Module, "core"

  def handle_cast({:check_callbacks, message}, callbacks) do
    f = fn {from, matcher} ->
      case matcher.(message) do
        {true, res} ->
          GenServer.reply(from, res)
          false
        false -> true
      end
    end
    unmatched_callbacks = Enum.filter(callbacks, f)
    {:noreply, unmatched_callbacks}
  end

  def handle_cast({:remove_callback, task_pid}, callbacks) do
    f = fn {{pid, _tag}, _matcher} -> task_pid != pid end
    unmatched_callbacks = Enum.filter(callbacks, f)
    {:noreply, unmatched_callbacks}
  end

  def handle_call({:add_callback, fun}, from, callbacks) do
    {:noreply, [{from, fun}|callbacks]}
  end

  def handle_cast(_, state) do
    {:reply, state}
  end

  def on_message(msg) do
    GenServer.cast(self, {:check_callbacks, msg})
  end

  #handle "chat" do
  #end

  #handle "file" do
  #end
end
