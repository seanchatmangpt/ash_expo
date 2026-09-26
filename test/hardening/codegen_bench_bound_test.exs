defmodule AshExpoHardening.CodegenBenchBoundTest do
  @moduledoc """
  Regression bound for `bench/codegen_bench.exs`.

  Recorded 2026-09-26 (Elixir 1.19.5 / OTP 28, loaded macOS host, 2000
  iterations, 1 integration resource): generate median 54us / p95 553us,
  manifest_build median 1us, resources_for_app median 1us. The bounds below
  leave ~100x headroom over those medians so a slow CI runner does not flap,
  while an accidental O(n^2) path or per-call recompilation still fails.
  """
  use ExUnit.Case, async: false

  @iterations 300
  @generate_median_bound_us 5_000
  @manifest_median_bound_us 1_000
  @fanin 2_000
  @fanin_bound_us 250_000

  defp median_us(fun) do
    for _ <- 1..20, do: fun.()

    samples =
      for _ <- 1..@iterations do
        {us, _} = :timer.tc(fun)
        us
      end

    samples |> Enum.sort() |> Enum.at(div(@iterations, 2))
  end

  test "generate/2 median stays under the regression bound" do
    resources = [AshExpoHardening.Support.Ordered, AshExpoHardening.Support.Reordered]
    median = median_us(fn -> AshExpo.Codegen.generate(resources, "generated") end)
    assert median < @generate_median_bound_us, "generate median #{median}us"
  end

  test "Manifest.build/1 median stays under the regression bound" do
    resources = [AshExpoHardening.Support.Ordered, AshExpoHardening.Support.Reordered]
    median = median_us(fn -> AshExpo.Manifest.build(resources) end)
    assert median < @manifest_median_bound_us, "manifest median #{median}us"
  end

  test "duplicate-heavy input is deduplicated in bounded time" do
    resources = List.duplicate(AshExpoHardening.Support.Ordered, @fanin)
    {us, manifest} = :timer.tc(fn -> AshExpo.Manifest.build(resources) end)

    assert length(manifest["resources"]) == 1
    assert us < @fanin_bound_us, "#{@fanin}-element build took #{us}us"
  end
end
