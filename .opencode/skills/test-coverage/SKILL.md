---
name: test-coverage
description: Use when adding unit tests, improving test coverage, creating XCTest cases, or adding test mocks for existing openclient-llm Swift code.
---

# Test Coverage

Use this skill to add meaningful XCTest coverage for existing behavior. Read `AGENTS.md` and
`specs/testing.instructions.md` before editing; also read the specifications governing the source under test.

## Scope

If the requested target or desired depth is unclear, ask one concise question. Otherwise infer the smallest useful scope
from the request and nearby tests. Do not demand a coverage percentage when critical paths are evident.

## Process

1. Read the source under test and its direct dependencies. Identify public behavior, state transitions, errors, and
   meaningful boundaries.
2. Search `openclient-llm-test/` for existing coverage and reusable mocks before adding files.
3. Add focused tests at the smallest useful boundary. Prioritize changed or risky behavior over exhaustive permutations.
4. Mirror the source organization under `openclient-llm-test/Features/` or `openclient-llm-test/Core/`.
5. Reuse protocol-backed mocks. Add a shared mock under `openclient-llm-test/Mocks/` only when multiple tests benefit;
   keep a one-off helper private to its test file.
6. Follow the repository's Given-When-Then structure, test naming, file header, `@MainActor`, and concurrency rules.
7. Ask the user before running tests unless their request already explicitly includes verification. When approved, load
   `xcode-verify` and run the smallest relevant test set first.

## Coverage Guidance

- **ViewModels:** observable Event-to-State transitions, async loading behavior, coordination, and recoverable errors.
- **UseCases:** business rules, transformations, dependency failures, and meaningful edge cases.
- **Repositories:** mapping, persistence, caching, and invalidation behavior with external boundaries mocked.
- **Managers and parsers:** public contracts, malformed input, invariants, and round trips when applicable.

Do not require a test file for a pass-through type with no independent behavior. Do not test private methods directly,
add delays, call real services, or weaken production design solely to make testing convenient. Every test must be capable
of failing when its covered behavior regresses.

## Completion

Report the behavior covered, files added or changed, and any important gaps. If tests ran, report their result; otherwise
state that verification awaits approval.
