defmodule AshExpo do
  @moduledoc """
  Connects Ash Framework resources to Expo applications without introducing a
  second domain model.

  `AshExpo.Resource` records mobile-specific transport and offline policy for
  already-public Ash actions. `AshExpo.Codegen` projects that metadata into a
  deterministic TypeScript manifest and an Expo-safe runtime adapter that plugs
  into `ash_typescript` through its `customFetch` option.

  Ash remains authoritative for actions, policies, validation, relationships,
  calculations and persistence. AshExpo only projects admissible client
  capabilities.
  """

  @schema_version 1

  @doc "Manifest schema version emitted by this package."
  def schema_version, do: @schema_version
end
