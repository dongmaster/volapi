# Volapi

This is a simple and reliable API client for [Volafile.io](https://volafile.io).

Volapi.ex is reasonably stable and should work for most purposes.
Some features have yet to been implemented though, because I'm lazy.

If you want to use this, you should know that breaking changes will be introduced possibly frequently.

## Examples
### Setup
Take a look at the [Releases](https://github.com/dongmaster/volapi/releases) page to see the latest version.

Create a new mix project and add this to your deps:
(The version number below is just an example. Use the latest version from the Releases page)
```elixir
defp deps do
  [
    {:volapi, "~> v2.1.15"}
  ]
```

Pull in the dependencies with `mix deps.get`.

Next, open `config/config.exs` in your favorite text editor.

config.exs:
```elixir
use Mix.Config

config :volapi,
  nick: "ElixirBot",
  password: "CoolBot!",
  auto_login: false # Logs in automatically after connecting to Volafile. Can be a bit spotty so don't rely on this too much. You can just omit this from your config.exs if you don't intend on using it.
  rooms: ["room1"]
```

Now you're ready to use Volapi.ex.

The following examples are clones of the examples in [RealDolos's Volapi](https://github.com/realdolos/volapi) README.
### Basic
This is a very simple example.
```elixir
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
```

### Multiple rooms
Just change the `rooms` key in the config to ["room1", "room2"] to join several rooms.

This example is a bit trickier, because each room have unique responses, depending on the room.
BEEPi has the response "Don't you mean GNU/Linux?"
and
HvoXw has the response "Don't you mean GNU/Hollywood?"

This is easily solvable though :^)
```elixir
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
```

It is best practice to follow the HER (Handlers, Enforcers, Responders) format as seen above, when writing Volapi.ex modules.

## Features not implemented (because of laziness and lack of need of these features)
- Session resuming (When your connection to Volafile dies, you can resume your session by providing the previously used ids)
- Room change events (Such as when the MOTD, room name and more gets changed)
- Room control (It is not possible to change any room settings at all right now. This means changing the MOTD and such)
- There's no function to change your name.
- You can't log out.
- There's no function to upload files.
