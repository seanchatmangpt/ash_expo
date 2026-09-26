defmodule AshExpo.Resource.Transformers.TrackChannelConfig do
  @moduledoc false
  # The ValidateProjection verifier admits `transport: :channel` projections only
  # when `config :ash_typescript, generate_phx_channel_rpc_actions: true`. The
  # verifier runs inside the consumer's compilation, so the consumer module must
  # record that key as compile env; otherwise flipping the config would not
  # recompile it and a channel projection admitted earlier would go stale.
  #
  # Evaluating `Application.compile_env/3` in the consumer's module body makes
  # the compiler trace `{:compile_env, :ash_typescript, [key], value}` against
  # the consumer, which is what Mix uses to recompile on config change.

  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl) do
    channel? =
      dsl
      |> Spark.Dsl.Transformer.get_entities([:expo])
      |> Enum.any?(&(&1.transport == :channel))

    if channel? do
      {:ok,
       Spark.Dsl.Transformer.eval(
         dsl,
         [],
         quote do
           @ash_expo_channel_rpc_actions Application.compile_env(
                                           :ash_typescript,
                                           :generate_phx_channel_rpc_actions,
                                           false
                                         )
           @doc false
           def __ash_expo_channel_rpc_actions__, do: @ash_expo_channel_rpc_actions
         end
       )}
    else
      {:ok, dsl}
    end
  end
end
