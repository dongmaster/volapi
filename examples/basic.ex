defmodule Volapi.Bot.Basic do
  use Volapi.Module, "basic"

  ## Handlers

  handle "chat" do
    match_re ~r/linux/i, :interject
  end

  ## Responders

  defh interject do
    reply "Don't you mean GNU/Linux?"
  end
end
