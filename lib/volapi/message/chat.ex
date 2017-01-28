defmodule Volapi.Message.Chat do
  # There's a data key in message maps that contains data such as if a message is sent by you (self: true) or IP addresses
  defstruct [
    raw_message: [],
    message: "", # Multi-part. Multiple parts can be witnessed when using newlines in a message and links.
    message_alt: "",
    room: "",
    nick: "",
    nick_alt: "", # Convenience key. Useful for pattern matching. It's just the nick downcased.
    id: "", # For room owners. Used for timeouts.
    ip: "",
    channel: "",
    self: false,
    admin: false,
    donator: false,
    staff: false,
    profile: "",
    user: false, # This is true if the user is logged in.
  ]

  def raw_to_string(raw_message) do
    Enum.map_join(raw_message, "", fn
      %{"type" => "text", "value" => value} ->
        value
      %{"type" => "url", "text" => value} ->
        value
      %{"type" => "break"} ->
        "\n"
      %{"type" => "file", "id" => id} -> # There's a third key in this map called "name" which includes the name of the file.
        "@#{id}"
      %{"type" => "room", "id" => id} -> # Same as the comment about about the file message type.
        "##{id}"
      %{"value" => value} ->
        value
      _ ->
        ""
    end)
  end

  @doc """
  Alternate version of the raw_to_string function where filenames and room names are outputted to the string, instead of the file id and room id.
  """
  def raw_to_string_alternate(raw_message) do
    Enum.map_join(raw_message, "", fn
      %{"type" => "text", "value" => value} ->
        value
      %{"type" => "url", "text" => value} ->
        value
      %{"type" => "break"} ->
        "\n"
      %{"type" => "file", "name" => name} -> # There's a third key in this map called "name" which includes the name of the file.
        name
      %{"type" => "room", "name" => name} -> # Same as the comment about about the file message type.
        name
      %{"value" => value} ->
        value
      _ ->
        ""
    end)
  end
end
