defmodule AshExpo.Resource.Verifiers.ValidateProjection do
  @moduledoc false

  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    resource = dsl[:persist][:module]
    AshExpo.Info.validate_resource!(resource)
    :ok
  rescue
    error in ArgumentError ->
      {:error,
       Spark.Error.DslError.exception(
         message: Exception.message(error),
         path: [:expo]
       )}
  end
end
