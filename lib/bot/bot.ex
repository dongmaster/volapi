defmodule Volapi.Bot do
  use Volapi.Module, "bot"

  def is_not_me(%{self: self}), do: !self

  handle "chat" do
    enforce :is_not_me do
      match "hi", :hi
    end
  end

  defh hi do
    Volapi.Client.Sender.send_message("hi", message.room)
  end
end
