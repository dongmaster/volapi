defmodule Volapi.State do
  defstruct [
    user_count: 0,
    client_ack: 0,
    server_ack: -1,
    chat: [],
    files: [],
    config: %{},
  ]

end
