import Config

config :ash, :default_string_length_count, :codepoints

if config_env() == :test do
  config :ash_expo, ash_domains: [AshExpo.Integration.Domain]
  config :ash_typescript, manifest: AshExpo.Integration.Manifest
  config :ash_typescript, run_endpoint: "/rpc/run", validate_endpoint: "/rpc/validate"
end
