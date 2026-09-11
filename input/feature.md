---
description: Run the full Journey Hero feature workflow — brainstorm (requirements challenge) → spec-writer (OpenSpec spec) → branch → parallel architecture+UX review → slice plan → per-slice test-writer→implementer loop → parallel review gate (design/security/dependency/business + reviewer) → e2e tests & screenshots → documentation → PR. Argument: a short feature description or the path to a spec file.
---

Drive one feature through the Journey Hero TDD workflow (`docs/WORKFLOW.md`). The feature request is: $ARGUMENTS

Follow these phases strictly and in order:

## Phase 0 — BRAINSTORM (brainstorm agent)
Launch the `brainstorm` agent with the raw idea (or the provided spec file — it also checks drafts for gaps). It challenges the requirements against `docs/PLAN.md` scope, `docs/APP_STATE.md`, and `docs/PRINCIPLES.md`, and returns either **READY** or **NEEDS ANSWERS** with at most 7 questions, each with why-it-matters and a suggested default.
- **NEEDS ANSWERS** → relay the questions to the user with AskUserQuestion, offering each suggested default as an option. Fold the answers into the idea. Re-run `brainstorm` only if the answers changed the idea substantially; otherwise proceed.
- **READY** → proceed directly.
Do not skip this phase: it exists so ambiguity costs one conversation here instead of a review bounce or a loop restart later.

## Phase 1 — SPEC (spec-writer agent)
Launch the `spec-writer` agent (runs on Fable) with the sharpened idea, the brainstorm verdict, and **every answer the user gave** (say which suggested defaults were accepted). It writes the **OpenSpec change** `openspec/changes/<feature-slug>/` (layout: `openspec/README.md`): `proposal.md` — `## Intent` / `## Scope` / `## Approach` / `## Background (verified in code)` / `## Decisions` / the required `## Announcement` — plus one delta spec `specs/<capability>/spec.md` per touched capability, holding `## ADDED|MODIFIED|REMOVED Requirements` with `### Requirement:` SHALL statements each carrying `#### Scenario:` WHEN/THEN blocks. It writes nothing else (a PreToolUse hook enforces the scope — not `design.md`/`tasks.md`, not the truth layer `openspec/specs/`, not the frozen `docs/specs/`). It does not create the branch or commit.
Handle its report:
- **WRITTEN** with `> OPEN:` markers → relay each open question to the user with AskUserQuestion (offering the agent's suggested default), then re-launch `spec-writer` with the answers to resolve the markers. Never resolve one yourself by guessing, and never let a spec with an `> OPEN:` marker reach Phase 3.
- **WRITTEN** clean → proceed.
- **BLOCKED** → it found a plan conflict or contradictory answers; take that conversation to the user, then re-run from Phase 0 or Phase 1 as the answer warrants.
Do not write the spec yourself: the orchestrator's job here is to route answers, not to author requirements. Every downstream agent (architect, ux, test-writer, reviewer, business) reads the spec by requirement and scenario name, so a spec not in this grammar breaks their coverage checks.

## Phase 2 — Branch
Create a fresh branch off the latest main: `git fetch origin main && git checkout -b feature/<feature-slug> origin/main` (the untracked `openspec/changes/<feature-slug>/` folder from Phase 1 carries over), then commit the change on it: `docs(<feature-slug>): openspec proposal + spec deltas`.
Never work on main directly.

## Phase 3 — ARCHITECTURE + UX REVIEW (architect + ux agents, in parallel)
Launch the `architect` and `ux` agents **together, in a single message**, both with the change folder path. They review the same input against different documents, so neither needs the other's result to start:
- `architect` checks the spec against `docs/PLAN.md` §4's architecture decisions, the existing package layout, and `docs/PRINCIPLES.md` §4's performance budgets (does the flow imply N+1 proxy calls, main-thread work, non-lazy lists?).
- `ux` walks every requirement's scenarios as a real user journey — every state (idle, loading, success, each distinguishable failure), its presentation (inline field error / banner / dialog / snackbar), and the exact proposed copy — against `docs/DESIGN.md`'s voice rules.

Handle the verdicts:
- `architect` REQUEST REVISION → discard the ux result (the flow it reviewed is about to change), re-launch `spec-writer` with the verdict to revise the spec (asking the user first, via AskUserQuestion, only where the verdict needs a product decision), commit the revision, then re-run **both** in parallel.
- Only `ux` REQUEST REVISION → re-launch `spec-writer` with the verdict (same rule about product decisions), commit, and re-run `ux`; re-run `architect` too only if the fix changed the architectural shape (new abstraction, new dependency, moved layer boundary).
- The spec-writer reports REVISED with the exact requirement/scenario names it changed — pass that list to the re-run reviewers so they focus on the delta.
- Both APPROVE / APPROVE WITH NOTES → write `openspec/changes/<feature-slug>/design.md` yourself (the orchestrator — no agent): `# Design: <feature name>`, then `## Technical Approach` / `## Architecture Decisions` / `## Data Flow` / `## File Changes` from the architect's notes (including any proposed `docs/PLAN.md` §4 amendment, marked pending human sign-off), `## UX states` holding the ux agent's state-by-state table verbatim, and `## Verdicts` (brainstorm, architect, ux — with dates and revision rounds). Commit it (`docs(<feature-slug>): design`) and continue, pointing test-writer and implementer at `design.md` for the notes and the state table.

## Phase 3.5 — SLICE PLAN (orchestrator — no agent)
Before launching ANY coding agent, split the approved spec into **implementation slices**. This exists to bound every test-writer/implementer run to something that finishes in minutes, not hours — the whole spec still lands on this one branch and ships in one PR.

- A slice is the smallest independently testable increment: roughly **1–3 requirements** (or the scenarios of one larger requirement), or one layer of one component (persistence first, then domain logic, then ViewModel/UI wiring). Every slice must leave the branch compiling and green.
- Order slices so each builds only on `main` plus earlier slices — no slice may depend on a later one.
- A small spec (≤ ~3 criteria touching one component) is a **single slice** — do not manufacture ceremony. But err toward smaller: an agent run that would exceed roughly an hour of work is a slicing failure, not a fact of life.
- Record the plan in `openspec/changes/<feature-slug>/tasks.md` — OpenSpec's **tasks** checklist: `# Tasks`, then `## Implementation slices` with one `- [ ] N. <slice>` line per slice, each naming the `Requirement:` names (and, when a requirement is split, the `Scenario:` names) it covers — and commit it (`docs(<feature-slug>): slice plan`), so the reviewer and the PR reader see the intended decomposition. Tick a slice's box (`- [x]`) in the GREEN commit that finishes it, so the file always shows where the branch stands.

## Phases 4 + 5 — RED → GREEN, once per slice
Run the RED→GREEN pair **per slice, in slice order** — never hand the whole spec to one agent run when the plan has more than one slice.

For each slice N of M:

1. **RED** — launch the `test-writer` agent with ONLY slice N's requirements and their scenarios (by name, quoted from the spec), plus the architect notes and the ux state-table rows relevant to it. Tell it explicitly: "this is slice N of M of `openspec/changes/<slug>/tasks.md`; the requirements are in `openspec/changes/<slug>/specs/<capability>/spec.md`, the notes and state table in `design.md`; write failing tests for these scenarios only — later slices' requirements are out of scope for this run." It commits `test(<feature>): slice N — ...`. Verify the commit exists and note its hash — it is the freeze boundary for this slice.
2. **GREEN** — launch the `implementer` agent for slice N: make slice N's new tests pass while keeping every earlier slice's tests green. It must not touch test files. It commits `feat(<feature>): slice N — ...`.
3. ENFORCE the frozen-tests contract for the slice yourself:
```bash
git diff <slice-N-test-commit>..HEAD --name-only -- 'app/src/test' 'app/src/androidTest'
```
If that prints anything, revert those changes and send the implementer back with the violation report.
4. If either agent reports the slice is still too big, is stalling, or has run far past the expected size — STOP, split the remainder of that slice into smaller slices, update `tasks.md`, and continue with the smaller pieces. Never re-launch the same oversized task and hope.

Only after the **final** slice is green, ENFORCE that the backlog register was maintained (`docs/backlog/` — one file per open item, see its README):
```bash
git diff origin/main...HEAD --name-only -- docs/backlog docs/ROADMAP.md
```
Judge the output against what the feature actually did — there is no unconditional "must touch" file anymore:
- Feature closed an open item → its `docs/backlog/` file must be **deleted** in the diff (and the `docs/ROADMAP.md` line naming it removed, if one exists).
- Feature left something open or discovered something → a new slug-named backlog file must exist (no sequential ids — see the README).
- Nothing opened or closed → no docs change required at all. Do **not** demand one.
- Any other `docs/ROADMAP.md` edit (re-ordering, new scope) is the owner's call, not the branch's — revert it and flag it.
There is no progress-log entry to write; the PR description (Phase 10) is the history. Checked again by the reviewer.

## Phase 6 — REVIEW GATE (design/security/dependency/business + reviewer, one parallel batch)
First decide mechanically which reviews are needed — never launch an agent whose entire report would be "nothing to review":
```bash
git diff origin/main...HEAD --name-only
scripts/check-string-parity.sh   # run whenever any strings.xml changed; on FAIL, send the implementer back to fix parity BEFORE launching any review agent
```
- `design` — launch only if the diff touches `app/src/main/res/` or a `.kt` file containing `@Composable`. Otherwise record its verdict as **SKIPPED — no UI surface (orchestrator-verified via diff)**.
- `dependency` — launch only if the diff touches `gradle/libs.versions.toml` or any `build.gradle.kts`. Otherwise record **SKIPPED — no dependency changes (orchestrator-verified via diff)**.
- `security`, `business`, `reviewer` — always launch; their relevance is a judgment call, and the reviewer is the independent different-model gate.

Launch every non-skipped agent **in a single message** so they run concurrently. The `reviewer` reviews the same frozen diff as the other four and does not consume their verdicts, so it belongs in the same batch — running it afterwards only adds latency.

## Phase 7 — Findings loop
For any REQUEST CHANGES from the gate: route each finding to the right place (implementation bugs → implementer; genuinely wrong tests AND missing unit tests for new functions → test-writer — the latter is a **test-gap round**, never the implementer's job; design-system/plan amendments → the agent that owns that doc), then re-run **only the checks whose findings were addressed** — plus the `reviewer` whenever production code changed after its APPROVE.
Make every re-run delta-focused: give the re-launched agent the commit hash of its previous verdict and instruct it to review the commits since then, not the full branch diff from scratch.
After each fix round, recheck the diff file list — a SKIPPED check stays skipped only while the diff still has no relevant surface for it.
Repeat until every launched agent APPROVEs.

## Phase 8 — E2E TESTS & SCREENSHOTS (e2e agent)
Launch the `e2e` agent. It writes/updates full-journey Compose UI tests under `app/src/androidTest/` (named `*E2ETest.kt`, distinct from test-writer's behavioral tests), runs them plus captures a screenshot per changed screen where a device/emulator is available, and reports a handoff manifest (screenshots captured vs. pending, per screen).

## Phase 9 — DOCUMENT + ARCHIVE (documentation agent)
Launch the `documentation` agent with the `e2e` agent's handoff manifest and the change folder path. It updates only the `docs/app-state/screen-*.md` files for screens the diff touched (plus the `docs/APP_STATE.md` index line for a new screen), rewriting them to current state — never appending change narration — and referencing the screenshots the `e2e` agent captured (or marking a screen pending per the manifest). It does not capture screenshots itself.
Then it **archives the OpenSpec change**: precondition every `tasks.md` box is ticked; it applies each `specs/<capability>/spec.md` delta to the truth layer `openspec/specs/<capability>/spec.md` (ADDED appended, MODIFIED replaces the exactly-matching requirement block, REMOVED deletes it; a missing truth spec is created with `## Purpose` + `## Requirements`), moves the folder with `git mv openspec/changes/<slug> openspec/changes/archive/<YYYY-MM-DD>-<slug>`, and commits. VERIFY afterwards: `openspec/changes/<slug>/` no longer exists, the archive folder does, and `git diff origin/main...HEAD --name-only -- openspec/specs` lists only the capabilities the change's deltas named. A header mismatch it refused to resolve goes back to `spec-writer` (the delta header must match the truth spec exactly), never gets fixed by hand in the truth spec.
If a fix round after this phase changes a requirement, `spec-writer` edits the archived change in place and the documentation agent re-applies the delta.

## Phase 10 — PR & pipeline
Push the branch (`git push -u origin feature/<feature-slug>`) and open a pull request to main **as a draft**, titled after the feature, with a link to the archived change (`openspec/changes/archive/<date>-<slug>/` — proposal, deltas, design, tasks) and the truth specs it updated, plus every agent's verdict (brainstorm, spec-writer — WRITTEN/REVISED rounds and any `> OPEN:` questions the user answered —, architect, ux, design, security, dependency, business, reviewer — SKIPPED verdicts included, with their reason) in the description. The PR description **is the permanent history of this feature** (the progress log is retired — `docs/archive/PROGRESS-LOG.md`): it must also name every backlog item opened or closed, what each review round found, and how the result was verified.

`ci.yml` does not run on a draft PR (its jobs gate on `draft == false`), so once this phase has nothing left to do — the branch is fully pushed and every phase above is done, not a mid-slice checkpoint — mark the PR ready for review (`draft: false`) before ending the run. That's what actually triggers `ci.yml` for the first time on this PR. After the human merges, `ship.yml` builds, tests, and publishes the playground APK to GitHub Releases automatically.

Report at the end: branch name, PR link, all verdicts, and test counts.
