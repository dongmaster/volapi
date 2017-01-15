defmodule Volapi.Room do
  @room_config_keys [
    "disabled", "file_max_size", "file_time_to_life",
    "max_room_name_length", "motd", "name",
    "owner", "private", "room_id",
  ]

  def populate_config(room) do
    config = Volapi.Util.get_room_config(room)

    Enum.each(config, fn({key, value}) ->
      if key in @room_config_keys do
        value =
          case value do
            value when value == "true" ->
              true
            value when value == "false" ->
              false
            _ ->
              value
          end

        Volapi.Server.set_config(String.to_atom(key), value)
      end
    end)
  end
end
