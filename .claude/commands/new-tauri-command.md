---
description: Scaffold a new Tauri command end-to-end — Rust handler, registration, mockito test, frontend hook, TS type.
argument-hint: "<command_snake_case_name>"
---

You are scaffolding a new Tauri command named `$ARGUMENTS`.

Validate `$ARGUMENTS` is non-empty and snake_case. If not, ask the user for a valid name.

## Files to create / modify

1. **Pick the right command file** under `src-tauri/src/commands/`:
   - Touches Deezer? → `commands/deezer.rs`
   - Touches LRCLIB? → `commands/lyrics.rs`
   - Touches local fs / save? → `commands/storage.rs`
   - None of the above? → create new `commands/<area>.rs` and add `pub mod <area>;` to `commands/mod.rs`.

2. **Write the Rust handler** following the existing pattern (see `commands/deezer.rs:17` `fetch_albums`):
   ```rust
   #[tauri::command]
   pub async fn $ARGUMENTS(
       /* args */
       state: State<'_, AppState>,
   ) -> Result<ReturnType, AppError> {
       // 1. cache check
       // 2. rate-limit acquire
       // 3. service call
       // 4. cache write
       // 5. return
   }
   ```

3. **Register in `src-tauri/src/lib.rs:15`** `invoke_handler!` macro:
   ```rust
   commands::<area>::$ARGUMENTS,
   ```

4. **Add a mockito-style test** in the same file, inside `#[cfg(test)] mod tests`. Pattern: spawn mock server, build client pointing at it, call the function, assert.

5. **Add a TS type** for the return shape in `src/types/index.ts` (camelCase).

6. **Add a frontend hook wrapper** in `src/hooks/useDeezer.ts` (or new `use<Area>.ts`) following the `useDeezerCommand<T>` pattern.

7. **Run `/verify`** to confirm everything compiles and tests pass.

8. **Run `/sync-schemas`** to confirm no DTO drift introduced.

## Reminders

- Hook `block-secrets.sh` will reject any literal token/key in the new code.
- Hook `check-rust-after-edit.sh` will run cargo check after each Rust edit.
- After implementation, run `/review-pr` for a santa-method check before commit.
