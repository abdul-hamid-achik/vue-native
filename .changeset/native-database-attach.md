---
'@thelacanians/vue-native-cli': patch
---

Database: raw SQL cannot attach other files, and `VACUUM` works again on Apple.

On Android, `execute`, `query` and `executeTransaction` refuse `ATTACH`,
`DETACH` and `VACUUM INTO`, as Apple already did, so raw SQL cannot reach SQLite
files outside the database name it was given. On iOS and macOS the attach limit
that enforced this also broke plain `VACUUM`; it is replaced by an authorizer
that only permits VACUUM's private temporary database. On Android,
`rowsAffected` is now right for `INSERT OR IGNORE` and multi-row inserts, and
`REPLACE` reports `insertId`.
