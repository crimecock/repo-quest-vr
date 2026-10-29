#!/usr/bin/env bash
# A new patch on top of patches/repoxr, for a game update that broke RepoXR's patches (the way 0009 was made for
# R.E.P.O. 0.5.0). One patch per game version keeps it clear what each update needed.
#
#   scripts/repoxr-patch.sh start             work/repoxr-edit: RepoXR (external/RepoXR, v1.2.3) with every patch in
#                                             patches/repoxr applied, as a git repository with that as its one commit
#   ... edit work/repoxr-edit/Source (QuestBuilder.Cli check lists the patch classes that fail and why) ...
#   scripts/repoxr-patch.sh save repo-0.5.1   your changes -> patches/repoxr/<next number>-repo-0.5.1.patch
#   scripts/repoxr-patch.sh diff              what you changed so far
#
# Then list the patch in scripts/prepare-repoxr.sh's header, rebuild RepoXR (scripts/prepare-repoxr.sh) and the kit, and
# run QuestBuilder.Cli check again: no failed patch classes, no IL/type/reference errors.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
edit="$root/work/repoxr-edit"
upstream="$root/external/RepoXR"

case "${1:-}" in
    start)
        [ -f "$upstream/RepoXR.csproj" ] || git -C "$root" submodule update --init external/RepoXR
        if [ -d "$edit/.git" ] && [ -n "$(git -C "$edit" status --porcelain)" ]; then
            echo "work/repoxr-edit has unsaved changes; save them first (or delete the folder)" >&2
            exit 1
        fi
        rm -rf "$edit"
        mkdir -p "$edit"
        (cd "$upstream" && tar --exclude ./.git --exclude ./bin --exclude ./obj -cf - .) | tar -xf - -C "$edit"
        for patch in "$root"/patches/repoxr/*.patch; do
            patch -p1 --forward --silent -d "$edit" < "$patch" || { echo "patch failed: $(basename "$patch")" >&2; exit 1; }
        done
        git -C "$edit" init -q
        git -C "$edit" add -A
        git -C "$edit" -c user.name=repoxr-patch -c user.email=repoxr-patch@localhost commit -q -m "RepoXR + patches/repoxr"
        echo "ready: edit $edit/Source, then: scripts/repoxr-patch.sh save <name>"
        ;;
    diff)
        git -C "$edit" diff --stat
        ;;
    save)
        name="${2:?usage: scripts/repoxr-patch.sh save <name, e.g. repo-0.5.1>}"
        [ -d "$edit/.git" ] || { echo "no work/repoxr-edit; run: scripts/repoxr-patch.sh start" >&2; exit 1; }
        git -C "$edit" add -A
        [ -n "$(git -C "$edit" diff --cached --name-only)" ] || { echo "no changes in work/repoxr-edit" >&2; exit 1; }
        last="$(ls "$root"/patches/repoxr/*.patch | sed -E 's#.*/([0-9]{4})-.*#\1#' | sort -n | tail -1)"
        number="$(printf '%04d' $((10#$last + 1)))"
        out="$root/patches/repoxr/$number-$name.patch"
        git -C "$edit" diff --cached --no-color > "$out"
        # The next save starts from here
        git -C "$edit" -c user.name=repoxr-patch -c user.email=repoxr-patch@localhost commit -q -m "$number-$name"
        echo "saved $out ($(grep -c '^+++ ' "$out") files); list it in scripts/prepare-repoxr.sh"
        ;;
    *)
        sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
        exit 64
        ;;
esac
