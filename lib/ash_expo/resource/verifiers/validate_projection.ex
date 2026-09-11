defmodule AshExpo.Resource.Verifiers.ValidateProjection do
  @moduledoc false

  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    resource = Spark.Dsl.Verifier.get_persisted(dsl, :module)
    projections = Spark.Dsl.Verifier.get_entities(dsl, [:expo])

    with :ok <- validate_ash_typescript(resource),
         :ok <- validate_unique_names(resource, projections) do
      validate_projections(resource, projections)
    end
  end

  defp validate_ash_typescript(resource) do
    if AshTypescript.Resource in Ash.Resource.Info.extensions(resource) do
      :ok
    else
      error(
        resource,
        "#{inspect(resource)} uses AshExpo.Resource but not AshTypescript.Resource; " <>
          "AshExpo projects the ash_typescript contract rather than creating a second API model"
      )
    end
  end

  defp validate_unique_names(resource, projections) do
    duplicates =
      projections
      |> Enum.group_by(& &1.name)
      |> Enum.filter(fn {_name, values} -> length(values) > 1 end)
      |> Enum.map(&elem(&1, 0))

    if duplicates == [] do
      :ok
    else
      error(
        resource,
        "AshExpo action projections must be unique; duplicate names: #{inspect(duplicates)}"
      )
    end
  end

  defp validate_projections(resource, projections) do
    Enum.reduce_while(projections, :ok, fn projection, :ok ->
      case validate_projection(resource, projection) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_projection(resource, %{name: name, realtime?: true, transport: transport})
       when transport != :channel do
    error(resource, "AshExpo realtime action #{inspect(resource)}.#{name} must use transport: :channel")
  end

  defp validate_projection(resource, %{name: name, transport: :channel} = projection) do
    if Application.get_env(:ash_typescript, :generate_phx_channel_rpc_actions, false) do
      validate_action(resource, projection)
    else
      error(
        resource,
        "AshExpo channel action #{inspect(resource)}.#{name} requires " <>
          "config :ash_typescript, generate_phx_channel_rpc_actions: true"
      )
    end
  end

  defp validate_projection(resource, projection), do: validate_action(resource, projection)

  defp validate_action(resource, projection) do
    case Ash.Resource.Info.action(resource, projection.name) do
      nil ->
        error(
          resource,
          "AshExpo action #{inspect(projection.name)} does not exist on #{inspect(resource)}"
        )

      %{public?: false} ->
        error(
          resource,
          "AshExpo action #{inspect(projection.name)} on #{inspect(resource)} must be public? true"
        )

      %{type: type} when projection.offline == :cacheable and type != :read ->
        error(
          resource,
          "AshExpo :cacheable is only valid for read actions; #{inspect(resource)}.#{projection.name} is #{type}"
        )

      _action ->
        :ok
    end
  end

  defp error(resource, message) do
    {:error,
     Spark.Error.DslError.exception(
       module: resource,
       message: message,
       path: [:expo]
     )}
  end
end
