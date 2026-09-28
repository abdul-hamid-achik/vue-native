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

Upgrading across the `<VSVG>` split also rewires the host: the command adds
the `VueNativeCoreSVG` / `VueNativeMacOSSVG` product to `ios/project.yml` /
`macos/project.yml` and the `register()` call to each generated `AppDelegate`
(before `super` on macOS), because a pre-split host keeps building without the
new sibling package and `<VSVG>` would otherwise degrade to a logged error and
a blank view. The edits are additive and idempotent; a host file whose shape
the command does not recognise is left untouched with a warning.
