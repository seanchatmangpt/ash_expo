defmodule AshExpoTest.Todo do
  use Ash.Resource,
    extensions: [AshTypescript.Resource, AshExpo.Resource]

  typescript do
    type_name "Todo"
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end

  actions do
    read :read do
      primary? true
      public? true
    end

    create :create do
      accept [:title]
      public? true
    end
  end

  expo do
    action :read, offline: :cacheable
    action :create, offline: :online_only
  end
end

defmodule AshExpoTest do
  use ExUnit.Case, async: true

  alias AshExpoTest.Todo

  test "builds a deterministic admitted mobile manifest" do
    manifest = AshExpo.Manifest.build([Todo])

    assert manifest["schemaVersion"] == 1
    assert [resource] = manifest["resources"]
    assert resource["typeName"] == "Todo"

    assert resource["actions"] == [
             %{
               "name" => "create",
               "type" => "create",
               "transport" => "http",
               "offline" => "online_only",
               "realtime" => false,
               "secure" => true
             },
             %{
               "name" => "read",
               "type" => "read",
               "transport" => "http",
               "offline" => "cacheable",
               "realtime" => false,
               "secure" => true
             }
           ]
  end

  test "generated runtime composes through ash_typescript customFetch" do
    runtime = AshExpo.Codegen.render_runtime()

    assert runtime =~ "customFetch: mobileFetch"
    assert runtime =~ "createSecureStoreTokenStore"
    assert runtime =~ "online_only and cannot be queued"
  end

  test "generation is byte deterministic" do
    assert AshExpo.Codegen.generate([Todo], "generated") ==
             AshExpo.Codegen.generate([Todo], "generated")
  end
end
