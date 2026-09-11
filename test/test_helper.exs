Application.put_env(:ash, :default_string_length_count, :codepoints)
Application.put_env(:ash_typescript, :generate_phx_channel_rpc_actions, true)

ExUnit.start()
