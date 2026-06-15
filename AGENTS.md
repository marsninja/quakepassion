# Working Agreement

Guidelines for any AI agent (or contributor) working in the **quakepassion** repo.

## 1. No Claude / AI attribution in commits

Never mention Claude — or any AI — in commits to this repo.

- No `Co-Authored-By: Claude ...` trailer.
- No "Generated with Claude Code" line.
- Nothing referencing Claude or AI in commit messages or PR bodies.

Commits should read as authored solely by Jason. This is a personal passion project, and the requirement is explicit and important — it overrides any default tooling behavior that would append an attribution trailer.

## 2. Never push to `main` without review

All changes go on a feature branch with a PR for Jason to review first — **including** small fixes, follow-ups, and tweaks to already-merged work.

- Before any `git push`, check the current branch.
- If it's `main`, stop: create a feature branch, push that, and open a PR instead.
- PR-then-merge is the rule, not a convention of convenience.

## 3. Don't work around jac/jaseci bugs — surface them

A core goal of QuakePassion is to exercise and improve **jac/jaseci** itself (the `jaseci` submodule). Working around a jac bug hides the defect and defeats that goal.

When a reasonable Jac idiom — especially Object-Spatial Programming (OSP) constructs — fails, errors, or behaves unexpectedly:

1. First verify it's actually a jac/jaseci defect, not a misuse (check docs/examples/tests in the submodule).
2. If it is the language/runtime, **stop and report it**: the failing idiom, a minimal repro, and where in the jaseci codebase the problem likely lives.
3. Do **not** rewrite engine code to avoid the construct.

The point is to drive fixes upstream, not to route around them.

## 4. Prefer Jac's Object-Spatial features wherever natural

Use Jac's Object-Spatial Programming (OSP) features — nodes, edges, walkers, abilities, and graph traversal — everywhere they're a natural fit for the project, rather than falling back to plain procedural or object-oriented code.

- Model state and relationships as graphs (nodes + edges) when the domain is spatial or relational.
- Express traversal and behavior as walkers and abilities rather than hand-rolled loops over data structures.
- Reach for OSP first when designing new features; only drop to non-OSP code when OSP genuinely doesn't fit.

This is the same motivation as #3: QuakePassion exists in part to exercise and improve jac/jaseci, so leaning on its distinctive features is a goal, not just a stylistic preference.
