# Test-only resources for test/hardening (compiled via elixirc_paths(:test)).
defmodule AshExpoHardening.Support.Ordered do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshTypescript.Resource, AshExpo.Resource]

  typescript do
    type_name "Ordered"
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
      accept [:priority]
      public? true
    end
  end

  expo do
    action :read, offline: :cacheable
    action :create, offline: :online_only
  end
end

defmodule AshExpoHardening.Support.Disabled do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshTypescript.Resource, AshExpo.Resource]

  typescript do
    type_name "Disabled"
  end

  attributes do
    uuid_primary_key :id
  end

  actions do
    read :read do
      primary? true
      public? true
    end
  end

  expo do
    enabled?(false)
    action :read
  end
end

defmodule AshExpoHardening.Support.Plain do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshTypescript.Resource]

  typescript do
    type_name "Plain"
  end

  attributes do
    uuid_primary_key :id
  end

  actions do
    defaults [:read]
  end
end

defmodule AshExpoHardening.Support.Reordered do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshTypescript.Resource, AshExpo.Resource]

  typescript do
    type_name "Reordered"
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
      accept [:priority]
      public? true
    end
  end

  # Declared in the opposite order to AshExpoHardening.Support.Ordered.
  expo do
    action :create, offline: :online_only
    action :read, offline: :cacheable
  end
end
