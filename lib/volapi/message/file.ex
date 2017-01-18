defmodule Volapi.Message.File do
  defstruct [
    file_id: "",
    file_name: "",
    file_type: "",
    file_size: 0, # Size is in bytes
    file_expiration_time: 0, # UNIX timestamp
    file_life_time: 0, # UNIX timestamp
    metadata: %{user: "", artist: "", album: ""}, # user is uploader
    room: "",
  ]
end
