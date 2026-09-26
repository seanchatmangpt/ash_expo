import { createTodo, listTodos } from "../../tmp/integration/ash_rpc";
import { createAshExpoClient } from "../../tmp/integration/ash_expo";

const ash = createAshExpoClient({ fetch });

type CreateTodoConfig = Parameters<typeof createTodo>[0];
type ListTodosConfig = Parameters<typeof listTodos>[0];

const createConfig: CreateTodoConfig = {
  fields: ["id", "priority"],
  input: { priority: 1 },
};

const listConfig: ListTodosConfig = {
  fields: ["id", "priority"],
};

async function typecheckComposition() {
  await createTodo(await ash.prepare("Todo", "create", createConfig));
  await listTodos(await ash.prepare("Todo", "read", listConfig));
}

void typecheckComposition;
