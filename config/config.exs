import Config

if config_env() == :test do
  config :ash_expo, ash_domains: [AshExpo.Integration.Domain]
end
