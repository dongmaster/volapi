defmodule Volapi.Bot do
  use Volapi.Module, "main"

  handle "chat" do
    match "hey", :hey
  end

  handle "timeout" do
    match_all :timeout
  end

  def hey(_, _) do
    Volapi.Client.Sender.send_message("hi")
  end

  defh timeout do
    IO.puts "hej"
    IO.puts "hej"
    IO.puts "hej"
    IO.puts "hej"
    IO.puts "hej"
    IO.puts "hej"
    IO.puts "hej"
    IO.puts "hej"
  end

  def module_init do
    IO.puts "heyo"
  end
end
