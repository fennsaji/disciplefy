// ============================================================================
// Hidden Authors Resolver Unit Tests
// ============================================================================
// Run with: deno test --allow-env hidden-authors.test.ts

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { hiddenAuthorIds } from "./hidden-authors.ts";
import { AppError } from "./error-handler.ts";

/** Minimal stand-in for the Supabase service client used by hiddenAuthorIds. */
function fakeDb(opts: {
  blocked?: { user_id: string }[];
  muted?: { muted_user_id: string }[];
  blockedError?: unknown;
  mutedError?: unknown;
}) {
  return {
    rpc: (_fn: string, _args: unknown) =>
      Promise.resolve({ data: opts.blocked ?? [], error: opts.blockedError ?? null }),
    from: (_table: string) => ({
      select: (_cols: string) => ({
        eq: (_col: string, _val: string) =>
          Promise.resolve({ data: opts.muted ?? [], error: opts.mutedError ?? null }),
      }),
    }),
  };
}

Deno.test("returns an empty array when nothing is hidden", async () => {
  const result = await hiddenAuthorIds(fakeDb({}), "viewer", "fellowship");
  assertEquals(result, []);
});

Deno.test("unions blocked users and muted members", async () => {
  const result = await hiddenAuthorIds(
    fakeDb({ blocked: [{ user_id: "a" }], muted: [{ muted_user_id: "b" }] }),
    "viewer",
    "fellowship",
  );
  assertEquals(result.sort(), ["a", "b"]);
});

Deno.test("deduplicates a user who is both blocked and muted", async () => {
  const result = await hiddenAuthorIds(
    fakeDb({ blocked: [{ user_id: "a" }], muted: [{ muted_user_id: "a" }] }),
    "viewer",
    "fellowship",
  );
  assertEquals(result, ["a"]);
});

Deno.test("a muted user still sees their own posts (mutes are one-directional)", async () => {
  const result = await hiddenAuthorIds(
    fakeDb({ blocked: [{ user_id: "c" }], muted: [{ muted_user_id: "viewer" }, { muted_user_id: "d" }] }),
    "viewer",
    "fellowship",
  );
  assertEquals(result.sort(), ["c", "d"]);
});

Deno.test("throws AppError when the block lookup fails", async () => {
  await assertRejects(
    () => hiddenAuthorIds(fakeDb({ blockedError: { message: "boom" } }), "viewer", "fellowship"),
    AppError,
    "Failed to resolve blocked users",
  );
});

Deno.test("throws AppError when the mute lookup fails", async () => {
  await assertRejects(
    () => hiddenAuthorIds(fakeDb({ mutedError: { message: "boom" } }), "viewer", "fellowship"),
    AppError,
    "Failed to resolve muted members",
  );
});
