# smwhr — Sprint Plans Index

Living index of every sprint plan executed against `apps/api`, `apps/mobile`, or `apps/landing`. One entry per plan, newest at the top.

## Conventions

- **Filename:** `YYYY-MM-DD-<scope>-<short-name>.md` (date is the day the plan is written, not the day it ships).
- **Status flags:** 🟡 active · ✅ shipped · ⏸ paused · ❌ abandoned.
- Each plan is **self-contained**: assumes zero prior context, lists files, sessions, definition-of-done, and locked decisions.
- Plans are revised in place when decisions change. Significant pivots are appended as a `## Revisions` section, not rewritten silently.
- Cross-cutting plans that touch multiple apps live here too — flag the scope explicitly in the plan header.

## Plans

| Date | Status | Scope | Plan |
|------|--------|-------|------|
| 2026-04-24 | 🟡 active | mobile | [Mobile R0.1 — Frontend-First Implementation](./2026-04-24-mobile-r01-frontend-first.md) |

## Process

1. Founder describes the goal and constraints.
2. Mobile / Backend / Landing agent invokes `superpowers:writing-plans`, surfaces ambiguities, drafts plan here.
3. Founder resolves ambiguities → agent locks decisions in the plan and removes the open-questions section.
4. Agent executes session by session. Smoke test + commit close every session. No silent scope drift.
5. On ship, status flips to ✅ and a one-line `Outcome` note is added at the top of the plan.

## Anti-patterns

- ❌ Plans without locked decisions ("we'll figure it out") — block until founder resolves.
- ❌ Plans that require coordinating two apps in the same sprint without a named integration session.
- ❌ Plans whose first session is "research" — research happens before writing the plan, not inside it.
- ❌ Re-opening locked decisions mid-execution. Add a Revisions entry instead.
