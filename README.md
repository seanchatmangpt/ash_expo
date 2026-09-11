# ash_expo

`ash_expo` projects an Ash Framework application's admitted public actions into
an Expo-friendly TypeScript runtime without creating a second domain model.

Ash remains authoritative. `ash_typescript` continues to generate the API
types, validators and RPC functions. `ash_expo` adds only mobile-specific
transport, credential storage integration, offline admission metadata and a
deterministic capability manifest.

## Status

`0.1.0-dev` — first vertical slice.

## Installation

```elixir
def deps do
  [
    {:ash_expo, github: "seanchatmangpt/ash_expo"},
    {:ash_typescript, "~> 0.18.2"}
  ]
end
```

Configure `ash_typescript` to generate into the directory consumed by the Expo
application, then configure AshExpo to emit its companion files there as well:

```elixir
config :ash_typescript,
  output_file: "apps/mobile/generated/ash/ash_rpc.ts",
  generate_zod_schemas: true,
  generate_phx_channel_rpc_actions: true

config :ash_expo,
  output: "apps/mobile/generated/ash"
```

## Resource projection

```elixir
defmodule MyApp.Todo do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshTypescript.Resource, AshExpo.Resource]

  typescript do
    type_name "Todo"
  end

  actions do
    defaults [:read]

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
```

AshExpo requires `AshTypescript.Resource` and refuses to generate a projection
for a missing or private Ash action. `:cacheable` is admitted only for read
actions.

## Generate

AshExpo participates in Ash's native extension codegen protocol, so the normal
front door is:

```bash
mix ash.codegen
```

For a focused run:

```bash
mix ash_typescript.codegen --output apps/mobile/generated/ash
mix ash_expo.codegen --output apps/mobile/generated/ash
```

The AshExpo step emits:

```text
ash_expo.ts
ash_expo_manifest.ts
ash_expo_runtime.ts
```

Both `mix ash.codegen --check` and `mix ash_expo.codegen --check` detect stale
generated artifacts. `--dry-run` is also preserved.

## Expo HTTP runtime

`ash_typescript` RPC calls accept `customFetch`. AshExpo supplies one, resolves
relative Ash RPC endpoints against an explicit native API base URL, and keeps a
bearer token behind an explicit storage interface.

```ts
import { fetch as expoFetch } from "expo/fetch";
import * as SecureStore from "expo-secure-store";

import { createTodo } from "./generated/ash/ash_rpc";
import {
  createAshExpoClient,
  createSecureStoreTokenStore,
} from "./generated/ash/ash_expo";

const ash = createAshExpoClient({
  fetch: expoFetch,
  baseUrl: process.env.EXPO_PUBLIC_API_URL,
  tokenStore: createSecureStoreTokenStore(SecureStore),
});

const result = await createTodo(
  await ash.prepare("Todo", "create", {
    fields: ["id", "title"],
    input: { title: "Ship ash_expo" },
  }),
);
```

`prepare` performs the runtime admission check and then constructs the
`ash_typescript` config with the appropriate `customFetch`. The lower-level
`action(resource, action, config)` path performs static projection admission but
does not claim an online network check.

Actions declared with `secure?: false` use the public HTTP transport and do not
receive the configured bearer credential. Unknown resource/action pairs are
refused before RPC construction.

## Phoenix Channel RPC

AshExpo does not invent a websocket protocol. A projection with
`transport: :channel` uses the Phoenix Channel RPC functions already generated
by `ash_typescript`.

```elixir
expo do
  action :read,
    transport: :channel,
    realtime?: true,
    offline: :online_only
end
```

Channel projections require:

```elixir
config :ash_typescript,
  generate_phx_channel_rpc_actions: true
```

In Expo, create the ordinary Phoenix socket/channel and pass the actual
`Channel` object into AshExpo. The generic is inferred, so the object retains
the concrete Phoenix `Channel` type expected by the generated `*Channel`
function.

```ts
import { Socket } from "phoenix";
import { fetch as expoFetch } from "expo/fetch";
import * as SecureStore from "expo-secure-store";

import { listTodosChannel } from "./generated/ash/ash_rpc";
import {
  createAshExpoClient,
  createAshExpoSocketParams,
  createAshExpoSocketUrl,
  createSecureStoreTokenStore,
} from "./generated/ash/ash_expo";

const tokenStore = createSecureStoreTokenStore(SecureStore);
const baseUrl = process.env.EXPO_PUBLIC_API_URL!;
const socket = new Socket(createAshExpoSocketUrl(baseUrl), {
  params: await createAshExpoSocketParams(tokenStore),
});

socket.connect();
const channel = socket.channel("ash_typescript_rpc:mobile", {});
channel.join();

const ash = createAshExpoClient({
  fetch: expoFetch,
  baseUrl,
  tokenStore,
  channel,
});

listTodosChannel(
  await ash.prepareChannel("Todo", "read", {
    fields: ["id", "title"],
    resultHandler: (result) => console.log(result),
  }),
);
```

HTTP construction refuses channel-only projections, and channel construction
refuses HTTP-only projections. `realtime?: true` is admitted only with channel
transport. Channel actions are not admitted into the offline queue.

The runtime does not invent refresh-token semantics, background mutation
replay, local writes, or server-push subscriptions beyond the Phoenix Channel
capability supplied by `ash_typescript`. Those require explicit server-side
contracts.

## Offline classes

| Class | Meaning |
|---|---|
| `online_only` | Requires an online server admission and cannot be queued. |
| `cacheable` | Read result may be cached. Only valid for read actions. |
| `idempotent` | Declares that a future offline queue may retry under an explicit idempotency contract. |
| `replayable` | Declares that a future queue may replay under an explicit replay contract. |

`ash_expo` v0.1 records these classes and refuses an `online_only` queue. It
does **not** provide an offline mutation queue yet.

## Boundary

```text
Ash Resource / Action / Policy
          |
          +--> ash_typescript --> HTTP RPC + Phoenix Channel RPC
          |
          +--> ash_expo -------> mobile manifest / Expo runtime
                                      |
                                      v
                                Expo iOS/Android
```

Generated output is a projection. Business semantics remain in Ash.
