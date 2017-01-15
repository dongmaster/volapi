defmodule Volapi.File.Audio do
  defstruct [
    file_id: "",
    file_name: "",
    file_type: "audio",
    file_size: 0, # Size is in bytes
    file_expiration_time: 0, # UNIX timestamp
    file_life_time: 0, # UNIX timestamp
    metadata: %{user: "", artist: "", album: ""}, # user is uploader
  ]
end

defmodule Volapi.File.Image do
  defstruct [
    file_id: "",
    file_name: "",
    file_type: "image",
    file_size: 0, # Size is in bytes
    file_expiration_time: 0, # UNIX timestamp
    file_life_time: 0, # UNIX timestamp
    metadata: %{user: ""}, # user is uploader
  ]
end

defmodule Volapi.File.Video do
  defstruct [
    file_id: "",
    file_name: "",
    file_type: "video",
    file_size: 0, # Size is in bytes
    file_expiration_time: 0, # UNIX timestamp
    file_life_time: 0, # UNIX timestamp
    metadata: %{user: ""}, # user is uploader
  ]
end

defmodule Volapi.File.Archive do
  defstruct [
    file_id: "",
    file_name: "",
    file_type: "archive",
    file_size: 0, # Size is in bytes
    file_expiration_time: 0, # UNIX timestamp
    file_life_time: 0, # UNIX timestamp
    metadata: %{user: ""}, # user is uploader
  ]
end

defmodule Volapi.File.Document do
  defstruct [
    file_id: "",
    file_name: "",
    file_type: "document",
    file_size: 0, # Size is in bytes
    file_expiration_time: 0, # UNIX timestamp
    file_life_time: 0, # UNIX timestamp
    metadata: %{user: ""}, # user is uploader
  ]
end

defmodule Volapi.File.Other do
  defstruct [
    file_id: "",
    file_name: "",
    file_type: "other",
    file_size: 0, # Size is in bytes
    file_expiration_time: 0, # UNIX timestamp
    file_life_time: 0, # UNIX timestamp
    metadata: %{user: ""}, # user is uploader
  ]
end
