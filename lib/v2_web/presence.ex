defmodule V2Web.Presence do
  use Phoenix.Presence,
    otp_app: :v2,
    pubsub_server: V2.PubSub
end

