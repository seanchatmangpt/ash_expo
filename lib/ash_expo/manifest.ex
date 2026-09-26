defmodule AshExpo.Manifest do
  @moduledoc "Builds the deterministic mobile capability manifest from admitted Ash DSL state."

  alias AshExpo.Info

  @doc """
  Builds a deterministic manifest from explicit Ash resource modules.

  Every element must be an Ash resource module. Anything else (a domain, a
  plain module, an atom that names no module) is refused with an
  `ArgumentError` naming the offending input, rather than being silently
  dropped or failing deep inside Spark introspection. Resources without the
  `AshExpo.Resource` extension, or with `enabled? false`, are excluded.
  """
  def build(resources) when is_list(resources) do
    Enum.each(resources, &admit_resource!/1)

    resources =
      resources
      |> Enum.filter(&Info.ash_expo_resource?/1)
      |> Enum.filter(&Info.enabled?/1)
      |> Enum.uniq()
      |> Enum.sort_by(&inspect/1)

    %{
      "schemaVersion" => AshExpo.schema_version(),
      "resources" => Enum.map(resources, &resource_manifest/1)
    }
  end

  @doc "Discovers Ash resources registered in an OTP application's domains."
  def resources_for_app(otp_app) when is_atom(otp_app) do
    otp_app
    |> Ash.Info.domains_and_resources()
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(&Info.ash_expo_resource?/1)
    |> Enum.uniq()
    |> Enum.sort_by(&inspect/1)
  end

  defp admit_resource!(resource) do
    unless is_atom(resource) and Ash.Resource.Info.resource?(resource) do
      raise ArgumentError,
            "AshExpo.Manifest.build/1 expects Ash resource modules; got #{inspect(resource)}"
    end
  end

  defp resource_manifest(resource) do
    %{
      "module" => inspect(resource),
      "typeName" => AshTypescript.Resource.Info.typescript_type_name!(resource),
      "actions" =>
        resource
        |> Info.actions()
        |> Enum.sort_by(&to_string(&1.name))
        |> Enum.map(&action_manifest(resource, &1))
    }
  end

  defp action_manifest(resource, projection) do
    ash_action = Ash.Resource.Info.action(resource, projection.name)

    %{
      "name" => to_string(projection.name),
      "type" => to_string(ash_action.type),
      "transport" => to_string(projection.transport),
      "offline" => to_string(projection.offline),
      "realtime" => projection.realtime?,
      "secure" => projection.secure?
    }
  end
end
