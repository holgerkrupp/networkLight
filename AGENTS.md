# Agent Instructions

## Engineering Philosophy — Pragmatic Solo Developer

This project is maintained by a solo developer, often as a free, open-source application with a small user base. Optimize for useful, reliable software with minimal complexity and maintenance effort. Do not apply big-company processes or engineering standards unless explicitly requested.

This section is the default decision rule for scope, testing, and implementation effort. Preserve explicit project-specific requirements, especially data safety, privacy, security, platform constraints, and documented user-visible behavior. Interpret generic checklists proportionally to the change rather than expanding every task into a major project.

### 1. Simplicity first

- Prefer the simplest implementation that solves the actual problem for realistic users.
- Follow existing architecture, patterns, and native platform APIs.
- Avoid unnecessary abstractions, protocols, layers, dependencies, configuration, and infrastructure.
- Do not build generic frameworks for one-off functionality or speculate about future use.
- Prefer small, understandable changes over large rewrites; remove obsolete code when safe.
- If a simple approach handles roughly 90–95% of realistic cases, prefer it over a much more complex approach to theoretical completeness, unless the remainder risks user data, security, or essential functionality.

### 2. Requirements and scope

- Implement the requested outcome without inventing additional requirements.
- Distinguish essential behavior from optional enhancements.
- Cover common usage and observed failures; do not chase every hypothetical edge case.
- Do not create follow-up issues or expand GitHub acceptance criteria for speculative improvements.
- Do not block a task for nice-to-have refinements, exhaustive compatibility work, or theoretical future-proofing.
- When requirements are ambiguous but low-risk, choose a reasonable default and proceed.

### 3. Proportional testing

- Testing effort must match the change's complexity and risk.
- Add focused tests for important domain logic, migrations, data integrity, and confirmed regressions where practical.
- Do not require unit tests for every function, view, or trivial code change.
- Do not introduce elaborate mocks, test harnesses, or dependencies solely for coverage.
- A successful build plus targeted checks is enough for many small changes.
- Manual validation may cover device-specific UI, hardware, and platform behavior. Clearly state what remains to be checked, but do not keep implementation issues open solely for unavailable physical-device verification.
- Never claim a build or test passed when it was not run.

### 4. Reliability without overengineering

Prioritize, in order: (1) avoiding user-data loss or corruption, (2) avoiding common crashes and freezes, (3) keeping core functionality working, and (4) recoverable, understandable failures.

- Handle likely and observed errors; avoid defensive machinery for implausible scenarios.
- Prefer graceful degradation and straightforward recovery over elaborate retry systems.
- Use non-blocking feedback for recoverable background errors; do not interrupt users unnecessarily.
- Do not silently discard data or suppress failures requiring user action.
- Security, privacy, authentication, and irreversible operations deserve extra care even in a small app.

### 5. Architecture and performance

- Refactor only what is necessary for the requested change or an evidenced problem.
- Prefer incremental improvements, existing services, and established patterns.
- Do not maintain parallel implementations without a concrete migration reason.
- Optimize reported or measured user-visible slowness; avoid speculative caches, concurrency systems, and benchmarks.
- Accept small inefficiencies when the alternative adds substantial maintenance burden.

### 6. Definition of done

A task is done when the requested behavior is implemented, the relevant build/checks have been attempted where the environment allows, important regressions have been reasonably checked, and no serious new issue is known.

The following are **not automatic release gates**: exhaustive edge-case coverage, complete unit/UI test coverage, formal benchmarks, extensive architecture documentation, future-proof abstractions, old development-schema compatibility, extra settings, or physical-device verification unavailable to the agent.

Respect any explicit, narrower project requirement that applies to the task. Do not confuse optional improvements with blockers.

### 7. Agent behavior and communication

- Favor working software and clear maintenance over theoretical perfection.
- Do the work rather than turning small requests into lengthy plans.
- Ask for clarification only when the decision materially affects functionality, user data, security, or architecture.
- Keep changes focused and summaries concise: what changed, what was verified, and any real remaining risk.
- Recommend further work only when it has clear practical value.
- Never hide limitations, invent verification results, or compromise essential user-data protection.

**Guiding principle: Good enough, reliable, understandable, and shipped is usually better than theoretically perfect but excessively complex.**
