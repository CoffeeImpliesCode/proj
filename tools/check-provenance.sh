#!/usr/bin/env bash
# Source-integrity check for the OSGeo/PROJ SDK.
#
# Three questions, all answerable without a compiler:
#
#   1. Do all 664 recorded files still hash to the digests UPSTREAM.sha256
#      records?
#   2. Is the upstream file set exactly the recorded one -- no missing, extra or
#      renamed file? A plain checksum run cannot see an addition: `sha256sum -c`
#      reports every recorded file and says nothing at all about a file that is
#      in the tree and not in the list.
#   3. Do UPSTREAM.md and UPSTREAM.sha256 name the same release digest, is
#      README.upstream.md the preserved upstream front page, and is SQLite's
#      public-domain notice still where the records say it is?
#
# This is a provenance gate, not a build gate. Nothing here compiles, links,
# executes a target binary or needs a database: it is the check that an edit to
# the canonical native source cannot pass as a routine change.
#
# It also never rewrites UPSTREAM.sha256. That file is a record, not a cache: a
# script that regenerated it would make the gate self-certifying, because the
# digests it compares against would be the digests of whatever is on disk. An
# intentional change to the native source needs an observed failure, a small
# causal patch, an explicit per-file deviation record in NOTICE.md, an *edited*
# digest list, and a CHANGELOG.md entry in the same change.
#
# Usage: tools/check-provenance.sh   (run from anywhere in the repository)
#
# Requires: bash, coreutils sha256sum, awk, find, sort, diff, grep, cmp. No
# compiler, no Zig, no CMake, no sqlite3.
#
# SPDX-License-Identifier: MIT

set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
    echo "$1" >&2
    exit 1
}

# The number of recorded files. It is named here rather than interpolated from
# `wc -l` so that a file *added* to UPSTREAM.sha256 without also updating the
# count, and a file *removed* from it, both stop here rather than quietly
# changing what the gate says it covers.
readonly RECORDED_FILE_COUNT=664

# The directories and the top-level files that make up the imported upstream
# tree. Question 2 walks exactly this set, so an addition anywhere inside it is
# caught and an addition outside it is not mistaken for upstream material.
readonly UPSTREAM_DIRS=(src include data test scripts cmake examples man vendor)
readonly UPSTREAM_TOP_FILES=(
    AUTHORS.md
    CITATION
    CITATION.cff
    ChangeLog
    COPYING
    CMakeLists.txt
    INSTALL
    NEWS.md
    README.upstream.md
    proj.pc.in
)

# --------------------------------------------------------------------- 1. Bytes

recorded_count=$(awk '/^[0-9a-f]{64}  / { n++ } END { print n + 0 }' UPSTREAM.sha256)
if [ "$recorded_count" != "$RECORDED_FILE_COUNT" ]; then
    fail "UPSTREAM.sha256 records $recorded_count files; this gate covers $RECORDED_FILE_COUNT"
fi

sha256sum -c --quiet UPSTREAM.sha256 ||
    fail "an upstream file no longer matches UPSTREAM.sha256"
echo "all $RECORDED_FILE_COUNT recorded files match UPSTREAM.sha256"

# ------------------------------------------------------------------- 2. File set

# The recorded paths, restricted to the upstream tree. Every path in
# UPSTREAM.sha256 is one of these, and every file under these directories is
# recorded; the comparison below is what proves both directions.
expected_tree=$(
    awk '/^[0-9a-f]{64}  / { print $2 }' UPSTREAM.sha256 | LC_ALL=C sort
)

# What is actually on disk. `vendor/` is included whole: it is the one directory
# this fork added to the import, and its three SQLite files are recorded
# digests in the same list as PROJ's own, so an addition there is as much a
# provenance question as an addition under `src/`.
actual_tree=$(
    {
        find "${UPSTREAM_DIRS[@]}" -type f -print | LC_ALL=C sort
        for file in "${UPSTREAM_TOP_FILES[@]}"; do
            [ -f "$file" ] && printf '%s\n' "$file"
        done
    } | LC_ALL=C sort
)

if [ "$expected_tree" != "$actual_tree" ]; then
    echo "the upstream file set differs from the recorded one:" >&2
    diff -u <(echo "$expected_tree") <(echo "$actual_tree") >&2 || true
    echo >&2
    echo "A missing file, an extra file and a renamed file all look like this." >&2
    echo "An intentional change to the native source needs an observed failure, a" >&2
    echo "small causal patch, an explicit per-file deviation record in NOTICE.md," >&2
    echo "an edited UPSTREAM.sha256, and a CHANGELOG.md entry in the same change." >&2
    echo "This script will not edit UPSTREAM.sha256 for you: a record that" >&2
    echo "regenerates itself cannot tell an honest correction from a silent edit." >&2
    exit 1
fi
echo "the upstream file set is exactly the recorded $RECORDED_FILE_COUNT files"

# Every top-level file the import records is present, and nothing else at the
# top level is being mistaken for one. This is stated rather than assumed: the
# directory walk above would miss a top-level file that is recorded but absent,
# so the count of *recorded* top-level paths is compared here with the count
# actually present.
recorded_top=$(awk '/^[0-9a-f]{64}  / { print $2 }' UPSTREAM.sha256 | grep -c -v '/' || true)
if [ "$recorded_top" != "${#UPSTREAM_TOP_FILES[@]}" ]; then
    fail "UPSTREAM.sha256 records $recorded_top top-level files; this gate expects ${#UPSTREAM_TOP_FILES[@]}"
fi
echo "all ${#UPSTREAM_TOP_FILES[@]} recorded top-level upstream files are present"

# ------------------------------------------------- 3. Records, and the licences

# 3a. The release digest must be recorded identically in every record that
#     states one, so no two files can disagree about which upstream release
#     this is.
#     `-m1` rather than a pipe into `head -1`: with `pipefail` a `head` that
#     closes the pipe early sends SIGPIPE to grep and turns a successful match
#     into a failed pipeline.
#
#     UPSTREAM.sha256 is not one of those records, and this check previously
#     treated it as one. That file carries no comment header at all -- its
#     first line is already `f5ead304...  AUTHORS.md` -- so the first 64-hex
#     string in it is AUTHORS.md's own per-file digest. Comparing that against
#     the release digest compared two unrelated values and reported a mismatch
#     on a manifest whose 664 entries had just been verified against the tree.
#     A tree whose manifest does carry a header is checked for agreement below;
#     this one does not, and that fact is asserted rather than assumed.
digest_md=$(grep -m1 -oE '[0-9a-f]{64}' UPSTREAM.md)
[ -n "$digest_md" ] || fail "UPSTREAM.md records no sha256 digest"

for record in FORK-NOTES.md CHANGELOG.md README.md; do
    other=$(grep -m1 -oE '[0-9a-f]{64}' "$record" || true)
    [ -z "$other" ] || [ "$other" = "$digest_md" ] ||
        fail "$record names release digest $other, and UPSTREAM.md names $digest_md"
done

if grep -q '^#' UPSTREAM.sha256; then
    header_digest=$(grep '^#' UPSTREAM.sha256 | grep -m1 -oE '[0-9a-f]{64}')
    [ "$header_digest" = "$digest_md" ] ||
        fail "the UPSTREAM.sha256 header names $header_digest and UPSTREAM.md names $digest_md"
    echo "the release digest is recorded consistently in UPSTREAM.md and the UPSTREAM.sha256 header: $digest_md"
else
    # No header, so the manifest carries no release-digest claim to disagree
    # with, and the release digest must not have leaked into the per-file
    # digest column where it would read as a file that upstream ships.
    if awk -v d="$digest_md" '$1 == d { print $2; exit }' UPSTREAM.sha256 | grep -q .; then
        fail "the release digest appears as a per-file digest in UPSTREAM.sha256"
    fi
    echo "the release digest is recorded consistently in UPSTREAM.md, FORK-NOTES.md, CHANGELOG.md and README.md: $digest_md"
    echo "UPSTREAM.sha256 carries no header comment and therefore no release-digest claim; it holds only the 664 per-file digests"
fi

# 3b. The preserved upstream front page. `README.upstream.md` is a copy of
#     upstream's own `README.md`; upstream had no file by that name, so nothing
#     of upstream's was lost and nothing of this fork's shadows it. What proves
#     it is preserved rather than retyped is that its bytes match the digest the
#     import recorded, and that the file still carries upstream's own first
#     substantive line rather than a fork summary.
grep -q '^# PROJ' README.upstream.md ||
    fail "README.upstream.md does not begin with upstream's own PROJ heading"
grep -q 'OSGeo/PROJ' README.upstream.md ||
    fail "README.upstream.md does not name upstream's own repository"
recorded_readme=$(awk '/^[0-9a-f]{64}  README\.upstream\.md$/ { print $1 }' UPSTREAM.sha256)
[ -n "$recorded_readme" ] ||
    fail "UPSTREAM.sha256 does not record README.upstream.md"
[ "$(sha256sum README.upstream.md | cut -d' ' -f1)" = "$recorded_readme" ] ||
    fail "README.upstream.md no longer matches the digest UPSTREAM.sha256 records for it"
echo "README.upstream.md is upstream's own preserved front page, byte for byte"

# 3c. PROJ's own grant. It lives in `COPYING`, and the same text has to be in the
#     records this fork added around it: a private repository removes no
#     upstream obligation.
grep -q 'MIT style license' COPYING ||
    fail "the MIT-style grant is missing from COPYING"
for file in NOTICE.md FORK-LICENSE.md; do
    grep -q 'MIT' "$file" ||
        fail "the upstream licence identifier is missing from $file"
done
echo "the upstream MIT-style grant is present in COPYING and named in the records"

# 3d. SQLite's own terms. The amalgamation is public domain, and its notice is
#     the blessing at the top of the header -- "The author disclaims copyright to
#     this source code" followed by three lines of blessing. It is not an
#     MIT-style grant and no other file in the tree carries it, so if the header
#     were replaced the vendored dependency would have lost its licence with
#     nothing left to notice it.
for file in vendor/sqlite3/sqlite3.h vendor/sqlite3/sqlite3.c; do
    grep -q 'The author disclaims copyright to this source code' "$file" ||
        fail "SQLite's public-domain notice is missing from $file"
done
grep -q 'May you do good and not evil' vendor/sqlite3/sqlite3.h ||
    fail "SQLite's public-domain blessing is missing from vendor/sqlite3/sqlite3.h"
# And the records must say so too: the licence of a tree is never the licence of
# its most prominent file.
grep -q 'sqlite3' NOTICE.md ||
    fail "NOTICE.md does not record the vendored SQLite3 dependency"
grep -q 'sqlite3' UPSTREAM.md ||
    fail "UPSTREAM.md does not record the vendored SQLite3 dependency"
echo "SQLite's public-domain notice is present in the vendored amalgamation and named in the records"

# 3e. The omission that has to stay an omission. `shell.c` is the `sqlite3`
#     command-line program; this package builds `proj.db` by executing the SQL
#     through the vendored library inside its own generator, so it needs no CLI
#     and must not acquire one. A `shell.c` appearing under `vendor/sqlite3/`
#     would mean a CLI was added to a tree whose build explicitly does without
#     one -- and the file-set check above would have accepted it, because the
#     import's digest list would have to have been edited first. That is exactly
#     the kind of change this question exists to notice.
if [ -e vendor/sqlite3/shell.c ]; then
    fail "vendor/sqlite3/shell.c is present; this package builds proj.db without the sqlite3 CLI"
fi
grep -q 'shell\.c' NOTICE.md ||
    fail "NOTICE.md does not record that SQLite's shell.c is deliberately not vendored"
echo "the absence of SQLite's shell.c is recorded and holds"

# 3f. Two generated inputs, and the rule that keeps them honest.
#     `data/sql/proj.db.sql.expected.md5` is the digest upstream's own
#     `generate_proj_db.cmake:32-48` compares the concatenated SQL against, and
#     `build.zig`'s host-run generator asserts the same equality and stops the
#     build when it does not hold. These two files cannot drift apart: the
#     expected digest *is* the file's content, and this gate checks the shape of
#     it so that an emptied or padded file is caught here rather than by a build
#     that fails for a reason nobody can read.
expected_md5_file=data/sql/proj.db.sql.expected.md5
if [ "$(tr -d ' \t\r\n' < "$expected_md5_file")" != "97f045739c534f9697ae359d4be8c95a" ]; then
    fail "$expected_md5_file does not hold the digest upstream's generate_proj_db.cmake compares against"
fi
echo "the recorded proj.db SQL digest is upstream's, and the generator asserts it"

echo "provenance checks passed"