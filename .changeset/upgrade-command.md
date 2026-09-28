---
'@thelacanians/vue-native-cli': minor
---

Add `vue-native upgrade`, the migration path that 0.21.0 shipped without.

Every scaffolded project commits a vendored copy of the whole framework source,
so after a breaking release the only migration was re-scaffolding by hand or
editing ~424 files. `upgrade` re-vendors `native/` from the running CLI,
repoints the published dependencies at its version, and rewrites the
`native/.vue-native-version` stamp with `upgradedFrom` and `upgradedAt`.

It refuses without `--force` in the two cases where safe and destructive are
indistinguishable: a project with no stamp (scaffolded before 0.21.0, where a
stale tree looks exactly like an edited one) and a `native/` tree with
uncommitted local modifications in a git repository. `--dry-run` prints the
plan and writes nothing. Re-vendoring overwrites rather than deleting, so
files you added inside `native/` survive even under `--force`; files the
framework renamed upstream do not remove themselves and the command says to
review `git status` afterwards.
