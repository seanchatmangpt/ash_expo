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

# Fan-in: 2000 duplicate deliveries of the same resources. Measured over its
# own (smaller) warm sample count because each call does 2000x the admission
# work; the bound test asserts on the median of warm samples, as recorded here.
fanin_resources = resources |> List.duplicate(2_000) |> List.flatten()
fanin_iterations = max(div(iterations, 20), 15)

fanin_op =
  {"manifest_build_fanin_2000", fn -> AshExpo.Manifest.build(fanin_resources) end,
   fanin_iterations}

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
  (Enum.map(ops, fn {name, fun} -> {name, fun, iterations} end) ++ [fanin_op])
  |> Map.new(fn {name, fun, n} ->
    # warm-up: the first call pays one-off code loading, not steady-state cost
    for _ <- 1..20, do: fun.()
    samples = for _ <- 1..n, do: elem(:timer.tc(fun), 0)
    {name, Map.put(stats.(samples), "samples", n)}
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
