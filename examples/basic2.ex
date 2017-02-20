defmodule Volapi.Bot.Basic2 do
  use Volapi.Module, "basic2"

  ## Handlers
  handle "chat" do
    enforce :beepi do
      match ~r/linux/i, :linux
    end

    enforce :hvoxw do
      match ~r/hollywood/i, :hollywood
    end
  end

  ## Enforcers

  def beepi(%{room: "BEEPi"}), do: true
  def beepi(_), do: false

  def hvoxw(%{room: "HvoXw"}), do: true
  def hvoxw(_), do: false

  ## Responders

  defh linux do
    reply "Don't you mean GNU/Linux?"
  end

  defh hollywood do
    reply "Don't you mean GNU/Hollywood?"
  end
end
