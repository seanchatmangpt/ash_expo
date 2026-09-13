defmodule AshExpo.Info do
  @moduledoc "Introspection functions for `AshExpo.Resource`."

  use Spark.InfoGenerator, extension: AshExpo.Resource, sections: [:expo]

  @doc "Returns true when the resource enables its Expo projection."
  def enabled?(resource), do: expo_enabled?(resource)

  @doc "Returns the declared Expo action projections in declaration order."
  def actions(resource), do: expo(resource)

  @doc "Returns an Expo action projection by Ash action name."
  def action(resource, name) do
    Enum.find(actions(resource), &(&1.name == name))
  end

  @doc "Returns whether the resource has the AshExpo extension installed."
  def ash_expo_resource?(resource) do
    AshExpo.Resource in Ash.Resource.Info.extensions(resource)
  end
end
