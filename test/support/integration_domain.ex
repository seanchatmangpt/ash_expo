defmodule AshExpo.Integration.Todo do
  use Ash.Resource,
    otp_app: :ash_expo,
    domain: AshExpo.Integration.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshTypescript.Resource, AshExpo.Resource]

  typescript do
    type_name "Todo"
  end

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :priority, :integer, public?: true
  end

  actions do
    read :read do
      primary? true
      public? true
    end

    create :create do
      primary? true
      public? true
      accept [:priority]
    end
  end

  expo do
    action :read, offline: :cacheable
    action :create, offline: :online_only
  end
end

defmodule AshExpo.Integration.Domain do
  use Ash.Domain,
    otp_app: :ash_expo,
    extensions: [AshTypescript.Rpc]

  typescript_rpc do
    resource AshExpo.Integration.Todo do
      rpc_action :list_todos, :read
      rpc_action :create_todo, :create
    end
  end

  resources do
    resource AshExpo.Integration.Todo
  end
end
