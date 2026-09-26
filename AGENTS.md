# AGENTS.md

## Source of Truth

- `PROJECT_SPEC.md` is the main technical specification.
- Read the relevant section before changing code.
- Work on one phase or module at a time.
- Do not move to the next module unless the user explicitly requests it.

## Learning Goal

The user is a junior full-stack developer.

Explain:

- what problem is being solved,
- why the selected approach is used,
- which files will change,
- which commands are executed,
- how the result is verified.

Use this cycle:

Understand → Build → Run → Break → Observe → Diagnose → Fix → Explain

## Implementation Rules

- Keep the implementation simple and readable.
- Avoid unnecessary abstractions and design patterns.
- Do not add technologies outside `PROJECT_SPEC.md`.
- Do not silently change ports, service names or API contracts.
- Do not modify unrelated files.
- Do not commit secrets.
- Keep `.env` out of Git.
- Maintain `.env.example`.
- Do not create Git commits unless the user explicitly requests it.

## Verification

After making changes:

- run the relevant builds,
- run meaningful tests,
- verify the actual behavior,
- update relevant documentation,
- report unresolved problems honestly.

## Completion Report

At the end of each task report:

- what changed,
- why it changed,
- files changed,
- commands executed,
- verification results,
- what the user should learn,
- recommended next step.
