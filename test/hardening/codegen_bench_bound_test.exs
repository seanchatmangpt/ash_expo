defmodule AshExpoHardening.CodegenBenchBoundTest do
  @moduledoc """
  Regression bound for `bench/codegen_bench.exs`.

  Measured numbers live only in `bench/receipts/` (one receipt per recorded
  subject); this module deliberately does not restate them, so the two cannot
  disagree. Every bound is asserted on the median of repeated warm samples,
  never on a single call: the first call into a freshly loaded resource pays
  one-off code loading and Spark introspection costs that were measured at
  up to ~450ms on a loaded host, which is noise for a regression bound.

  The fan-in bound also compares the 2000-duplicate build against the
  single-resource build, so an accidental O(n^2) dedup path fails on the
  ratio even on a host fast enough to pass the absolute bound.
  """
  use ExUnit.Case, async: false

  alias AshExpoHardening.Support.{Ordered, Reordered}

  @iterations 300
  @generate_median_bound_us 5_000
  @manifest_median_bound_us 1_000
  @fanin 2_000
  @fanin_samples 15
  @fanin_bound_us 250_000
  # Linear dedup of 2000 duplicates costs a few hundred single builds (the
  # receipt records ~270us vs ~1us); quadratic dedup would cost ~2000x more
  # than that. The ratio bound sits between the two.
  @fanin_ratio_bound 2_000

  defp warm_median_us(fun, iterations) do
    for _ <- 1..20, do: fun.()

    samples =
      for _ <- 1..iterations do
        {us, _} = :timer.tc(fun)
        us
      end

    samples |> Enum.sort() |> Enum.at(div(iterations, 2))
  end

  test "generate/2 median stays under the regression bound" do
    median =
      warm_median_us(
        fn -> AshExpo.Codegen.generate([Ordered, Reordered], "generated") end,
        @iterations
      )

    assert median < @generate_median_bound_us, "generate median #{median}us"
  end

  test "Manifest.build/1 median stays under the regression bound" do
    median = warm_median_us(fn -> AshExpo.Manifest.build([Ordered, Reordered]) end, @iterations)
    assert median < @manifest_median_bound_us, "manifest median #{median}us"
  end

  test "duplicate-heavy input is deduplicated in bounded time" do
    resources = List.duplicate(Ordered, @fanin)

    manifest = AshExpo.Manifest.build(resources)
    assert length(manifest["resources"]) == 1
    assert manifest == AshExpo.Manifest.build([Ordered])

    single = max(warm_median_us(fn -> AshExpo.Manifest.build([Ordered]) end, @iterations), 1)
    fanin = warm_median_us(fn -> AshExpo.Manifest.build(resources) end, @fanin_samples)

    assert fanin < @fanin_bound_us,
           "#{@fanin}-element build median #{fanin}us over #{@fanin_samples} warm samples"

    assert fanin < single * @fanin_ratio_bound,
           "#{@fanin}-element build median #{fanin}us vs single #{single}us"
  end
end
