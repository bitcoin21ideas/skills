# Tailoring the commit skill to a project

This is the build-time playbook. Follow it when the user asks you to **adapt this skill to their current project and install it** — e.g. *"look at the commit skill at `<github folder URL>`, tailor it to this project, and fold it into my `.claude/skills/`."*

The output is a single lean file: `.claude/skills/commit/SKILL.md` in the user's project, hard-wired to that project's gate, scopes, and conventions, with all detection prose and tailoring markers removed. **This `tailoring.md` is never copied into the project** — only the finished `SKILL.md` lands.

## 1. Get the template

You need the generic `SKILL.md` as your base. If you don't already have it locally, fetch the **raw** bytes (do not rely on a summary of the rendered GitHub page — it must be copied faithfully):

```bash
curl -s https://raw.githubusercontent.com/bitcoin21ideas/skills/main/skills/commit/SKILL.md
```

(`gh api repos/bitcoin21ideas/skills/contents/skills/commit/SKILL.md --jq .content | base64 -d` works too.) You only need `SKILL.md` — this `tailoring.md` is the instructions you're already reading.

## 2. Detect the project's realities

Inspect the current repo (run reads in parallel where you can). Gather:

- **Test/lint gate** — the command(s) to run before committing:
  - Node: `package.json` `scripts` — prefer a composite (`qa`, `check`, `verify`, `ci`); else the available `lint` / `typecheck` (`tsc --noEmit`) / `test`.
  - Python: `.pre-commit-config.yaml` → `pre-commit run --all-files`; else `pyproject.toml`/`tox.ini` for `pytest`, `ruff`/`flake8`, `mypy`.
  - Rust `Cargo.toml` → `cargo clippy` + `cargo test`. Go `go.mod` → `go vet ./...` + `go test ./...`. `Makefile` → `check`/`test`/`lint` targets.
  - Note any git `pre-commit` hook already wired (`.git/hooks/pre-commit`, husky) so the skill defers to it.
- **Scopes** — the conventional-commit scope vocabulary: top-level source dirs, workspace package names, and any scopes already used in `git log --oneline -50`.
- **Commit style** — from `git log --oneline -30`: conventional vs. freeform, the type vocabulary actually in use, whether scopes and bodies are common, the language, and any house quirks (e.g. tests filed under `chore(test):`). The tailored skill should match what the repo already does.
- **Sensitive paths** — gitignored env/secret files and any project-specific secret patterns worth adding to the scan.
- **Project pre-commit conventions** — does the repo keep a `CHANGELOG.md`? A `CONTRIBUTING.md` with commit rules? An English-only or other language rule? Capture anything the skill should enforce before committing.

## 3. Confirm with the user

Present what you found in one round — the proposed gate command, the scope list, the detected style, and any extra checks (changelog, language). Let the user correct it before you write. Don't dump every detail; lead with the gate and scopes, since those matter most.

## 4. Produce the tailored SKILL.md

Start from the template and apply these edits. The template carries HTML-comment seams to make this mechanical:

- **`<!-- tailor:gate -->` … `<!-- /tailor:gate -->`** — replace the entire detection block with the concrete command(s) you confirmed, plus the docs-only skip rule. Example: *"Run `npm run qa` from the repo root. Skip for docs/config-only changes."*
- **`<!-- tailor:scopes -->`** — replace the generic "derive from structure" line with the concrete scope list (and any module-specific scopes).
- **`<!-- tailor:sensitive -->`** — append the project's specific sensitive paths/patterns to the by-name list.
- **`<!-- tailor:strip -->`** — delete that line (the blockquote pointing here) entirely. The installed copy must not reference `tailoring.md`.
- **Extra checks** — if the project keeps a CHANGELOG or has a language/commit rule, add a short bullet to Step 3 or the message-format section. Otherwise leave them out — don't add ceremony the project doesn't use.
- **Keep intact**: `name: commit` (so it stays invocable as `/commit`), the secrets-scan step, the no-em-dash rule, and the no-AI-attribution rule. These are non-negotiable across projects.
- **Frontmatter**: keep `name: commit` (so it stays invocable as `/commit`). Update `description` to name the project and its gate. Leave `metadata` or simplify as you like.
- **Invocation**: the template is both user- and model-invocable (no `disable-model-invocation` field) — the model can start it when the user expresses commit intent, and it still waits for plan approval before committing. Keep it that way unless the user wants explicit-only, in which case add `disable-model-invocation: true`.

Remove every remaining `<!-- tailor:* -->` marker so the final file is clean.

## 5. Install it

- Default target: `.claude/skills/commit/SKILL.md` in the current project (create the directories).
- If a `commit` skill already exists there, show the diff and ask before overwriting.
- Do **not** copy this `tailoring.md` into the project.
- Show the user the final file and confirm it's discoverable as `/commit` in this project.

## 6. Re-tailoring later

If the project's tooling changes (new test runner, new scopes), the user re-runs this flow — re-detect, re-confirm, overwrite the installed copy. Nothing else to maintain.
