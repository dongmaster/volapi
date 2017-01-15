defmodule Volapi.Server.Util do
  def cast(type, data) do
    spawn(fn ->
      try do
        Enum.each(:pg2.get_members(:modules), fn(member) ->
          GenServer.cast(member, {type, data})
        end)
      rescue
        _ ->
          ""
      end
    end)
  end

  # datas is a silly name
  def cast_list(type, datas) do
    spawn(fn ->
      try do
        Enum.each(:pg2.get_members(:modules), fn(member) ->
          Enum.each(datas, fn(data) ->
            GenServer.cast(member, {type, data})
          end)
        end)
      rescue
        _ ->
          ""
      end
    end)
  end
end
