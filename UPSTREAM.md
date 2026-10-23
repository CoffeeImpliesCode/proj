# Upstream

| Field | PROJ source |
|---|---|
| Project | PROJ, OSGeo |
| Site | <https://proj.org/> |
| Repository | <https://github.com/OSGeo/PROJ> (`OSGeo/PROJ`) |
| Release | 9.9.0, published 2026-09-15T12:21:00Z |
| Release archive | `proj-9.9.0.tar.gz`, 6,048,023 bytes |
| Archive URL | <https://github.com/OSGeo/PROJ/releases/download/9.9.0/proj-9.9.0.tar.gz> |
| SHA-256 | `791a0610547eeabb17006cfd49cdbd2034f3240f47ed5e88a1031811f4e2bcf3` |
| MD5 | `50ed234d73d68f7bf4378e9a020a40a7` |
| Annotated tag | `9.9.0`, object `ce93bea6b5a18152b36e18c4179aae6df79a58b8` |
| Tag target | `1df2be61c0e4732aa1326126113776b291ae7657` |
| Tagger | Kristian Evers, 2026-09-15T12:19:01Z |

## Import

The source was obtained by downloading and extracting the release archive. It has no Git history or patch series. The import contains 664 files totaling 40,952,259 bytes; `UPSTREAM.sha256` records one digest per file. No PROJ upstream files were modified or removed. The upstream `README.md` is preserved as `README.upstream.md`.

The package's `data/proj.db` is generated from the imported SQL files; it is not in the release archive. The licence inventory and data-term exceptions are in `NOTICE.md`.

## Separate SQLite source

| Field | SQLite amalgamation |
|---|---|
| Version | 3.53.4 |
| Archive | `sqlite-amalgamation-3530400.zip`, 2,946,650 bytes |
| URL | <https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip> |
| SHA3-256 | `628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e` |
| SHA-256 | `1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d` |
| Imported files | `vendor/sqlite3/sqlite3.c`, `vendor/sqlite3/sqlite3.h`, `vendor/sqlite3/sqlite3ext.h` |
| Omitted file | `shell.c` (1,185,915 bytes), the SQLite command-line shell; it is not a PROJ upstream file. |
