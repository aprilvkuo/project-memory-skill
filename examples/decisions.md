---
last_task: 48
importance: 4
date: 2026-08-14
summary: Key architecture and tradeoff decisions (recency-weighted)
---

# Decisions

## D1 — Memory decays by task sequence, not calendar time
last_task: 48
importance: 4
load: recent
date: 2026-08-14
summary: Memory recency follows task distance rather than calendar age.

Replaced the 30-day half-life with a task-sequence axis. A decision untouched
for 6 months but preceded by only 3 tasks is still highly relevant; the decay
unit is "tasks since last touch", not "days since last touch".

## D2 — Separate preservation importance from automatic loading
last_task: 12
importance: 5
load: recent
date: 2026-03-10
summary: Critical decisions are preserved but stop auto-loading when stale.

Architecture constraints remain indexed and must not be automatically deleted.
They still decay into cold storage and only load when relevant.
