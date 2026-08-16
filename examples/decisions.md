---
last_task: 48
importance: 4
date: 2026-08-14
summary: Key architecture and tradeoff decisions (recency-weighted)
---

# Decisions

## D1 — Memory decays by task sequence, not calendar time (imp 4, touched @48)
Replaced the 30-day half-life with a task-sequence axis. A decision untouched
for 6 months but preceded by only 3 tasks is still highly relevant; the decay
unit is "tasks since last touch", not "days since last touch".

## D2 — Keep an importance floor so critical decisions never vanish (imp 5, @12)
Architecture constraints (imp5) keep recency >= 0.50 forever and are never
moved into the cold archive.
