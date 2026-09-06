---
status: accepted
---

# Use LAOO as the canonical monorepo workspace

`C:\laooplatform\laoo` and its GitHub repository are the only source of
truth for LAOO Core, Service, Meeting, and future Business Projects. Each
developer machine keeps its own clone and works on one feature branch at a
time. Legacy repositories are archival copies only.

This keeps shared contracts and UI in one version, while Business Projects
remain isolated under `projects/`.
