# Runtime source layout

The installed module uses three generated runtime files:

- `common/functions.sh` — shared platform, safety and reporting functions;
- `neorender` — the interactive terminal menu;
- `neorenderctl` — the command-line controller and benchmark engine.

To keep GitHub API publication reviewable, each runtime file is maintained as ordered UTF-8 shell fragments:

```text
functions/*.sh   -> common/functions.sh
menu/*.sh        -> neorender
controller/*.sh  -> neorenderctl
```

`scripts/test.sh` assembles the fragments in a temporary directory and validates the resulting files with POSIX `sh` and BusyBox `ash`. `scripts/build.sh` performs the same deterministic assembly in the release staging directory, removes `src/` from the installable package, generates runtime and full SHA-256 manifests, and creates the release ZIP.

Fragments are concatenated in lexical filename order. Renaming or reordering fragments is therefore a functional change and must be covered by the source tests.
