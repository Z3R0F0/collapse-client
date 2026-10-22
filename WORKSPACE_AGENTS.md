# Collapse workspace: agent entry point

The workspace uses two sibling repositories: `collapse-client` and
`collapse-backend`. Start with the client's `HANDOFF.md` and `START_HERE.md`, then read the
`AGENTS.md` in EACH repository you will change. Their scoped instructions apply
to their files. No other application repositories are required.

- Verify current files and Git status before work. Clone both repositories
  alongside one another following `START_HERE.md`; preserve unrelated changes.
- Read both architecture documents and `collapse-backend/MEDIA_API.md` for
  cross-project behavior. Preserve the existing ownership boundaries; do not
  replace the design with a second messaging, navigation or persistence stack.
- Client window/scroll/outbox/media-gallery state are independent. Coordinate
  protocol changes on both sides and test account isolation and deletion/ACL
  behavior, not just the happy path.
- This is a clean environment, not a migration of the old machine's accounts,
  sessions, database, uploads or credentials. Setup generates NEW local keys.
  Never copy credentials from another production environment into it.
- Run heavy builds/tests/browser sessions one at a time. Keep live services and
  unrelated changes intact. No destructive reset, commits, remote pushes or
  deployments without authorization. Use patch-based source edits.
- Report evidence and remaining limits honestly. Historical verification paths
  under `.local` refer to excluded private artifacts, not missing source code.
  Do not call physical-device, Docker or deferred WebM acceptance verified.

The backend repository contains maintained overlay/build sources; pinned upstream
Tinode and ordinary SDK/package dependencies are downloaded and checksum-checked
by the documented setup. This is not a bundled offline toolchain.
