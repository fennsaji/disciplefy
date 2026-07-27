// ============================================================================
// Reset Scope Resolver Unit Tests
// ============================================================================
// Run with: deno test --allow-env reset-scope.test.ts

import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { resolveResetRpc } from "./reset-scope.ts";
import { AppError } from "./error-handler.ts";

/**
 * Asserts that calling `resolveResetRpc(scope)` throws an `AppError` whose
 * message contains 'Invalid scope' and which carries the exact error code
 * and HTTP status the Edge Function relies on to build its response.
 */
function assertInvalidScope(scope: unknown): void {
  const error = assertThrows(
    () => resolveResetRpc(scope),
    AppError,
    "Invalid scope",
  );
  assertEquals(error.code, "VALIDATION_ERROR");
  assertEquals(error.statusCode, 400);
}

Deno.test({
  name: "resolveResetRpc: maps learning_paths to the learning RPC",
  fn: () => {
    assertEquals(
      resolveResetRpc("learning_paths"),
      "reset_user_learning_progress",
    );
  },
});

Deno.test({
  name: "resolveResetRpc: maps memory_verses to the memory RPC",
  fn: () => {
    assertEquals(
      resolveResetRpc("memory_verses"),
      "reset_user_memory_progress",
    );
  },
});

Deno.test({
  name: "resolveResetRpc: rejects an unknown scope",
  fn: () => {
    assertInvalidScope("everything");
  },
});

Deno.test({
  name: "resolveResetRpc: rejects undefined scope",
  fn: () => {
    assertInvalidScope(undefined);
  },
});

Deno.test({
  name: "resolveResetRpc: rejects null scope",
  fn: () => {
    assertInvalidScope(null);
  },
});

Deno.test({
  name: "resolveResetRpc: rejects empty string scope",
  fn: () => {
    assertInvalidScope("");
  },
});

Deno.test({
  name: "resolveResetRpc: rejects a number scope",
  fn: () => {
    assertInvalidScope(42);
  },
});

Deno.test({
  name: "resolveResetRpc: rejects a plain object scope",
  fn: () => {
    assertInvalidScope({});
  },
});

Deno.test({
  name: "resolveResetRpc: rejects an array scope",
  fn: () => {
    assertInvalidScope(["learning_paths"]);
  },
});

Deno.test({
  name: "resolveResetRpc: does not resolve the toString prototype key",
  fn: () => {
    // A plain-object lookup table would return Object.prototype members here.
    assertInvalidScope("toString");
  },
});

Deno.test({
  name: "resolveResetRpc: does not resolve the constructor prototype key",
  fn: () => {
    assertInvalidScope("constructor");
  },
});

Deno.test({
  name: "resolveResetRpc: does not resolve the __proto__ prototype key",
  fn: () => {
    assertInvalidScope("__proto__");
  },
});
