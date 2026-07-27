/**
 * Reset Scope Resolver
 *
 * Maps the caller-supplied `scope` value to the name of the Postgres
 * function that performs that reset.
 *
 * The mapping lives in a Map rather than a plain object so that inherited
 * keys such as `toString` and `__proto__` cannot resolve to anything. The
 * RPC name is always one of two literals — it is never built from caller
 * input.
 */

import { AppError } from "./error-handler.ts";

/** Feature areas a user can reset. */
export type ResetScope = "learning_paths" | "memory_verses";

/** Postgres functions that perform the resets. */
export type ResetRpcName =
  | "reset_user_learning_progress"
  | "reset_user_memory_progress";

const SCOPE_TO_RPC = new Map<string, ResetRpcName>([
  ["learning_paths", "reset_user_learning_progress"],
  ["memory_verses", "reset_user_memory_progress"],
]);

/** Every valid scope, for error messages. */
export const VALID_RESET_SCOPES: readonly ResetScope[] = [
  "learning_paths",
  "memory_verses",
];

/**
 * Resolve a caller-supplied scope to its RPC name.
 *
 * @param scope - Untrusted value from the request body
 * @returns The Postgres function name to call
 * @throws AppError VALIDATION_ERROR (400) if the scope is not in the allowlist
 */
export function resolveResetRpc(scope: unknown): ResetRpcName {
  if (typeof scope !== "string") {
    throw new AppError(
      "VALIDATION_ERROR",
      `Invalid scope. Expected one of: ${VALID_RESET_SCOPES.join(", ")}`,
      400,
    );
  }

  const rpc = SCOPE_TO_RPC.get(scope);

  if (!rpc) {
    throw new AppError(
      "VALIDATION_ERROR",
      `Invalid scope. Expected one of: ${VALID_RESET_SCOPES.join(", ")}`,
      400,
    );
  }

  return rpc;
}
