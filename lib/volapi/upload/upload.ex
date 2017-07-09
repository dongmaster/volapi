defmodule Volexupload do
  @server Application.get_env(:volapi, :server, "volafile.org")
  @base_upload_key_url "https://#{@server}/rest/getUploadKey?name=<%= name %>&room=<%= room %>"
  @base_upload_url "https://<%= server %>/upload?room=<%= room %>&key=<%= key %>"

  def main(name, room, file_path, filename) do
    HTTPoison.start
    get_upload_key(name, room)
    |> upload(file_path, filename)
  end

  def get_upload_key(name, room) do
    require EEx
    upload_key_url = EEx.eval_string(@base_upload_key_url, [name: name, room: room])
    %{"status_code": status_code, "headers": headers, "body": body} = HTTPoison.get!(upload_key_url, [{"Accept", "application/json"}, {"Referer", "https://#{@server}"}], [{:timeout, :infinity}, {:recv_timeout, :infinity}])

    %{"key" => key, "server" => server, "file_id" => file_id} = Poison.decode!(body)
    #res = Poison.decode!(body)
    #res = %{key: key, server: server, file_id: file_id}
    {server, room, key, file_id}
  end

  def upload({server, room, key, file_id}, file_path, filename) do
    upload_url = EEx.eval_string(@base_upload_url, [server: server, room: room, key: key])

    if filename do
      HTTPoison.post!(upload_url, {:multipart, [{:file, file_path, {"form-data", [{"name", "file"}, {"filename", filename}]}, []}]}, [{"Origin", @server}, {"Referer", "https://#{@server}"}], [{:timeout, :infinity}, {:recv_timeout, :infinity}])
    else
      HTTPoison.post!(upload_url, {:multipart, [{:file, file_path, {"form-data", [{"name", "file"}, {"filename", Path.basename(file_path)}]}, []}]}, [{"Origin", @server}, {"Referer", "https://#{@server}"}], [{:timeout, :infinity}, {:recv_timeout, :infinity}])
    end

    file_id
  end
end
