defmodule AshExpoConformance.OntologyDslConformanceTest do
  @moduledoc """
  Drift court between `ontology.ttl` (the ash-extension-core-pack contract the
  ggen manufacture consumes) and the hand-written Spark DSL in
  `AshExpo.Resource`.

  Nothing under `lib/` is a generated projection yet, so the ontology and the
  DSL are two declarations of one contract. This test reads the real
  ontology file and the real compiled extension (`AshExpo.Resource.sections/0`)
  and fails on any structural disagreement: section/entity/arg/field names and
  order, field types, required flags, defaults, one_of values and docs.

  The Turtle reader below covers exactly the subset `ontology.ttl` uses
  (prefixed-name subjects, `a`, `;`-separated predicate/object pairs, string,
  integer and boolean literals); an unparseable statement is a test failure,
  not a skip.
  """
  use ExUnit.Case, async: true

  @ontology Path.expand("../../ontology.ttl", __DIR__)

  setup_all do
    %{graph: parse_turtle(File.read!(@ontology))}
  end

  test "extension spec names the real module, package, codegen task and name", %{graph: g} do
    [spec] = subjects_of_type(g, "aex:AshExtensionSpec")
    assert one(g, spec, "aex:moduleName") == inspect(AshExpo.Resource)
    assert one(g, spec, "aex:packageName") == to_string(Mix.Project.config()[:app])
    assert one(g, spec, "aex:codegenName") == AshExpo.Resource.name()
    assert one(g, spec, "aex:extensionTarget") == "resource"

    task = one(g, spec, "aex:codegenTask")
    assert Mix.Task.get(task) == Mix.Tasks.AshExpo.Codegen
  end

  test "sections match in name, order, describe and schema fields", %{graph: g} do
    ontology_sections =
      g
      |> subjects_of_type("aex:DslSection")
      |> Enum.sort_by(&one(g, &1, "aex:sectionOrder"))

    dsl_sections = AshExpo.Resource.sections()

    assert Enum.map(ontology_sections, &one(g, &1, "aex:sectionName")) ==
             Enum.map(dsl_sections, &to_string(&1.name))

    for {subject, section} <- Enum.zip(ontology_sections, dsl_sections) do
      assert one(g, subject, "aex:sectionDescribe") == section.describe

      fields =
        g
        |> subjects_where("aex:sectionFieldOf", subject)
        |> Enum.sort_by(&one(g, &1, "aex:sectionFieldOrder"))

      assert Enum.map(
               fields,
               &{one(g, &1, "aex:sectionFieldName"), one(g, &1, "aex:sectionFieldType")}
             ) ==
               Enum.map(section.schema, fn {name, opts} ->
                 {to_string(name), type_name(opts[:type])}
               end)
    end
  end

  test "entities match in name, order, struct, args and fields", %{graph: g} do
    for section_subject <- subjects_of_type(g, "aex:DslSection") do
      section = section!(one(g, section_subject, "aex:sectionName"))

      ontology_entities =
        g
        |> subjects_where("aex:entityOf", section_subject)
        |> Enum.sort_by(&one(g, &1, "aex:entityOrder"))

      assert Enum.map(ontology_entities, &one(g, &1, "aex:entityName")) ==
               Enum.map(section.entities, &to_string(&1.name))

      for {subject, entity} <- Enum.zip(ontology_entities, section.entities) do
        assert one(g, subject, "aex:entityStruct") ==
                 entity.target |> Module.split() |> List.last()

        args =
          g
          |> subjects_where("aex:argOf", subject)
          |> Enum.sort_by(&one(g, &1, "aex:argOrder"))
          |> Enum.map(&one(g, &1, "aex:argName"))

        assert args == Enum.map(entity.args, &to_string/1)
        assert_fields(g, subject, entity.schema)
      end
    end
  end

  test "the court refuses a drifted ontology (anti-vacuity)", %{graph: g} do
    [action] = section!("expo").entities
    {:in, offline_values} = Keyword.fetch!(action.schema, :offline)[:type]
    dsl_values = Enum.map(offline_values, &to_string/1)

    drifted =
      @ontology
      |> File.read!()
      |> String.replace(~s(aex:oneOfValueName "replayable"), ~s(aex:oneOfValueName "replayed"))
      |> parse_turtle()

    assert one_of_values(g, "expo:offlineField") == dsl_values
    refute one_of_values(drifted, "expo:offlineField") == dsl_values
    assert length(drifted) == length(g)
  end

  defp assert_fields(g, entity_subject, schema) do
    fields =
      g
      |> subjects_where("aex:fieldOf", entity_subject)
      |> Enum.sort_by(&one(g, &1, "aex:fieldOrder"))

    assert Enum.map(fields, &one(g, &1, "aex:fieldName")) ==
             Enum.map(schema, fn {name, _} -> to_string(name) end)

    for {subject, {name, opts}} <- Enum.zip(fields, schema) do
      label = "field #{name}"
      assert one(g, subject, "aex:fieldType") == type_name(opts[:type]), label
      assert one(g, subject, "aex:fieldRequired") == Keyword.get(opts, :required, false), label
      assert one(g, subject, "aex:fieldDoc") == opts[:doc], label

      case Keyword.fetch(opts, :default) do
        {:ok, default} -> assert one(g, subject, "aex:fieldDefault") == inspect(default), label
        :error -> assert optional(g, subject, "aex:fieldDefault") == nil, label
      end

      case opts[:type] do
        {:in, values} -> assert one_of_values(g, subject) == Enum.map(values, &to_string/1), label
        _ -> assert subjects_where(g, "aex:oneOfValueOf", subject) == [], label
      end
    end
  end

  defp one_of_values(g, field_subject) do
    g
    |> subjects_where("aex:oneOfValueOf", field_subject)
    |> Enum.sort_by(&one(g, &1, "aex:oneOfValueOrder"))
    |> Enum.map(&one(g, &1, "aex:oneOfValueName"))
  end

  defp section!(name) do
    Enum.find(AshExpo.Resource.sections(), &(to_string(&1.name) == name)) ||
      flunk("ontology section #{name} has no DSL section")
  end

  defp type_name(:atom), do: "atom"
  defp type_name(:boolean), do: "boolean"
  defp type_name({:in, _}), do: "one_of"
  defp type_name(other), do: flunk("no ontology type mapping for #{inspect(other)}")

  # -- minimal Turtle reader for the subset ontology.ttl uses ---------------

  defp subjects_of_type(g, type), do: subjects_where(g, "a", type)

  defp subjects_where(g, predicate, object) do
    for {s, p, o} <- g, p == predicate, o == object, uniq: true, do: s
  end

  defp optional(g, subject, predicate) do
    case for({^subject, ^predicate, o} <- g, do: o) do
      [] -> nil
      [o] -> o
      many -> flunk("#{subject} #{predicate} has #{length(many)} values")
    end
  end

  defp one(g, subject, predicate) do
    case optional(g, subject, predicate) do
      nil -> flunk("#{subject} has no #{predicate}")
      value -> value
    end
  end

  defp parse_turtle(text) do
    text
    |> String.split("\n")
    |> Enum.reject(
      &(String.starts_with?(String.trim(&1), ["#", "@prefix"]) or String.trim(&1) == "")
    )
    |> Enum.join("\n")
    |> split_statements()
    |> Enum.flat_map(&statement_triples/1)
  end

  defp split_statements(text) do
    ~r/((?:[^".]|"[^"]*")+?)\s\.\s*(?=\n|\z)/s
    |> Regex.scan(text, capture: :all_but_first)
    |> Enum.map(fn [statement] -> String.trim(statement) end)
  end

  defp statement_triples(statement) do
    case Regex.run(~r/\A(\S+)\s+(.*)\z/s, statement) do
      [_, subject, rest] ->
        rest
        |> split_pairs()
        |> Enum.map(fn pair ->
          case Regex.run(~r/\A(\S+)\s+(.+)\z/s, String.trim(pair)) do
            [_, predicate, object] -> {subject, predicate, literal(String.trim(object))}
            _ -> flunk("unparseable predicate/object pair: #{inspect(pair)}")
          end
        end)

      _ ->
        flunk("unparseable statement: #{inspect(statement)}")
    end
  end

  defp split_pairs(rest) do
    ~r/(?:[^";]|"[^"]*")+/
    |> Regex.scan(rest)
    |> Enum.map(&hd/1)
    |> Enum.reject(&(String.trim(&1) == ""))
  end

  defp literal("\"" <> _ = quoted),
    do: quoted |> String.trim_leading("\"") |> String.trim_trailing("\"")

  defp literal("true"), do: true
  defp literal("false"), do: false

  defp literal(token) do
    case Integer.parse(token) do
      {int, ""} -> int
      _ -> token
    end
  end
end
