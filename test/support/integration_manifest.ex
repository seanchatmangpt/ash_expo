defmodule AshExpo.Integration.Manifest do
  @moduledoc """
  Test-only AshTypescript manifest scoped to the integration domain.

  Required by `mix ash_typescript.codegen` (invoked by CI's "Generate real
  AshTypescript and AshExpo integration" step) — AshTypescript's orchestrator
  refuses to run without a configured `:manifest` module. Scoped explicitly to
  `AshExpo.Integration.Domain` (rather than walking `Ash.Info.domains/1`) so it
  stays independent of whatever other domains this app config admits.
  """

  use AshTypescript.Manifest,
    otp_app: :ash_expo,
    domains: [AshExpo.Integration.Domain]
end
