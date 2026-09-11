defmodule AshExpo.Info do
  @moduledoc "Introspection and admission checks for `AshExpo.Resource`."

  alias Spark.Dsl.Extension

  @doc "Returns true when the resource enables its Expo projection."
  def enabled?(resource) do
    Extension.get_opt(resource, [:expo], :enabled?, true)
  end

  @doc "Returns the declared Expo action projections in declaration order."
  def actions(resource) do
    Extension.get_entities(resource, [:expo])
  end

  @doc "Returns an Expo action projection by Ash action name."
  def action(resource, name) do
    Enum.find(actions(resource), &(&1.name == name))
  end

  @doc "Returns whether the resource has the AshExpo extension installed."
  def ash_expo_resource?(resource) do
    AshExpo.Resource in Ash.Resource.Info.extensions(resource)
  end

  @doc "Validates the AshTypescript dependency and public Ash action boundary."
  def validate_resource!(resource) do
    unless AshTypescript.Resource in Ash.Resource.Info.extensions(resource) do
      raise ArgumentError,
            "#{inspect(resource)} uses AshExpo.Resource but not AshTypescript.Resource; " <>
              "AshExpo projects the ash_typescript contract rather than creating a second API model"
    end

    actions(resource)
    |> duplicate_names!()
    |> Enum.each(fn projection ->
      validate_transport!(resource, projection)

      case Ash.Resource.Info.action(resource, projection.name) do
        nil ->
          raise ArgumentError,
                "AshExpo action #{inspect(projection.name)} does not exist on #{inspect(resource)}"

        %{public?: false} ->
          raise ArgumentError,
                "AshExpo action #{inspect(projection.name)} on #{inspect(resource)} must be public? true"

        ash_action ->
          validate_offline_class!(resource, ash_action, projection)
      end
    end)

    :ok
  end

  defp duplicate_names!(projections) do
    duplicates =
      projections
      |> Enum.group_by(& &1.name)
      |> Enum.filter(fn {_name, values} -> length(values) > 1 end)
      |> Enum.map(&elem(&1, 0))

    if duplicates != [] do
      raise ArgumentError,
            "AshExpo action projections must be unique; duplicate names: #{inspect(duplicates)}"
    end

    projections
  end

  defp validate_transport!(resource, %{name: name, realtime?: true, transport: transport})
       when transport != :channel do
    raise ArgumentError,
          "AshExpo realtime action #{inspect(resource)}.#{name} must use transport: :channel"
  end

  defp validate_transport!(resource, %{name: name, transport: :channel}) do
    unless Application.get_env(:ash_typescript, :generate_phx_channel_rpc_actions, false) do
      raise ArgumentError,
            "AshExpo channel action #{inspect(resource)}.#{name} requires " <>
              "config :ash_typescript, generate_phx_channel_rpc_actions: true"
    end
  end

  defp validate_transport!(_resource, _projection), do: :ok

  defp validate_offline_class!(resource, %{type: type}, %{name: name, offline: :cacheable})
       when type != :read do
    raise ArgumentError,
          "AshExpo :cacheable is only valid for read actions; #{inspect(resource)}.#{name} is #{type}"
  end

  defp validate_offline_class!(_resource, _ash_action, _projection), do: :ok
end
