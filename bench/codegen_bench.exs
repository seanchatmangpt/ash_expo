# Deterministic timing benchmark for the AshExpo projection pipeline.
#
#     MIX_ENV=test mix run bench/codegen_bench.exs [iterations]
#
# Measures real calls (no doubles) against the test-env integration resource
# discovered from the :ash_expo OTP app, and prints one JSON line with
# per-operation median / p95 / max in microseconds. The regression bound that
# guards these numbers lives in test/hardening/codegen_bench_bound_test.exs.

iterations =
  case System.argv() do
    [n | _] -> String.to_integer(n)
    [] -> 2_000
  end

resources = AshExpo.Manifest.resources_for_app(:ash_expo)

if resources == [] do
  raise "benchmark needs MIX_ENV=test (integration resources are test-only)"
end

ops = [
  {"resources_for_app", fn -> AshExpo.Manifest.resources_for_app(:ash_expo) end},
  {"manifest_build", fn -> AshExpo.Manifest.build(resources) end},
  {"render_runtime", fn -> AshExpo.Codegen.render_runtime() end},
  {"generate", fn -> AshExpo.Codegen.generate(resources, "generated") end}
]

stats = fn samples ->
  sorted = Enum.sort(samples)
  n = length(sorted)

  %{
    "median_us" => Enum.at(sorted, div(n, 2)),
    "p95_us" => Enum.at(sorted, min(n - 1, div(n * 95, 100))),
    "max_us" => List.last(sorted)
  }
end

results =
  Map.new(ops, fn {name, fun} ->
    # warm-up
    for _ <- 1..50, do: fun.()
    samples = for _ <- 1..iterations, do: elem(:timer.tc(fun), 0)
    {name, stats.(samples)}
  end)

digest =
  resources
  |> AshExpo.Codegen.generate("generated")
  |> Enum.sort()
  |> :erlang.term_to_binary()
  |> then(&:crypto.hash(:sha256, &1))
  |> Base.encode16(case: :lower)

IO.puts(
  Jason.encode!(%{
    "schema" => "ash_expo/codegen-bench/1",
    "iterations" => iterations,
    "resources" => Enum.map(resources, &inspect/1),
    "generate_output_sha256" => digest,
    "otp" => System.otp_release(),
    "elixir" => System.version(),
    "results" => results
  })
)
