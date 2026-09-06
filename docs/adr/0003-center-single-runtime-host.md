---
status: accepted
---

# Use one Center runtime host for every Business Project

LAOO Flutter on port `8080` and `laoo_api` on port `5080` are the only
development and customer runtime hosts. Service, Meeting, and Visitor remain
separate source owners under `projects`, but contribute Flutter routes and
.NET controller assemblies to Center.

Each computer uses its own clone and the same local ports. Project-specific
standalone Flutter entrypoints, platform runners, and API hosts were removed
after parity verification. This prevents customers from operating one API
process per purchased system while preserving independent project ownership.
