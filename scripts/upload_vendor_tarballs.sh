#!/usr/bin/env bash
# Generate and upload vendor tarballs to the overlay's GitHub releases.
#
# Each release-eligible ebuild embeds a recipe block of the form:
#     # To (re)generate the vendor tarball:
#     #   <shell commands, indented with "#   ">
# This script extracts that recipe, runs it in a throwaway directory with the
# package's distfiles symlinked in, and uploads the resulting
# ${P}-vendor.tar.xz to a GitHub release tagged with the same filename.
#
# Usage:
#   upload_vendor_tarballs.sh [OPTIONS] [cat/pn ...]
#
# Options:
#   --dry-run    Show what would happen; do not run recipes or upload.
#   --force      Re-upload even if the asset already exists on the release.
#   --yes        Skip the per-package recipe confirmation prompt.
#   --token TOK  GitHub API token (default: $GITHUB_TOKEN, else `pass show` entry).
#   --no-pass    Do not consult pass(1) for the token.
#   -h, --help   Show this help.
#
# Examples:
#   upload_vendor_tarballs.sh                       # all packages, interactive
#   upload_vendor_tarballs.sh net-nds/phpldapadmin  # one package
#   upload_vendor_tarballs.sh --dry-run             # rehearse everything

set -euo pipefail

readonly REPO="vklimovs/portage-overlay"
readonly RECIPE_MARKER="generate the vendor tarball:"
readonly API="https://api.github.com"
readonly UPLOADS="https://uploads.github.com"
readonly PASS_ENTRY="Github/portage-overlay-releases"

DRY_RUN=0
FORCE=0
ASSUME_YES=0
TOKEN_ARG=""
NO_PASS=0
FILTERS=()

# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

log()  { printf '==> %s\n' "$*" >&2; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

require_cmd() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
    done
}

confirm() {
    local prompt="$1"
    (( ASSUME_YES )) && return 0
    [[ -t 0 ]] || die "stdin is not a TTY; pass --yes to skip confirmation"
    local reply
    read -r -p "$prompt [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]]
}

# Pause and wait for the user to be ready before invoking `pass`, since a
# gpg-agent pinentry prompt that times out unattended makes `pass` fail.
wait_for_pass() {
    [[ -r /dev/tty ]] || return 0
    printf 'About to run `pass show` -- a pinentry prompt may appear. Press Enter when ready: ' >&2
    read -r _ </dev/tty
}

# First line of `pass show $PASS_ENTRY`, or empty on any failure (pass not
# installed, entry missing, GPG agent locked, ...). Never fatal on its own;
# resolve_token decides whether a missing token is an error.
token_from_pass() {
    command -v pass >/dev/null 2>&1 || return 0
    local out
    wait_for_pass
    out=$(pass show "$PASS_ENTRY" 2>/dev/null) || return 0
    # Take only the first line (pass entries conventionally store the secret on
    # line 1 and metadata below).
    out=${out%%$'\n'*}
    printf '%s' "$out"
}

# Resolve the GitHub token from, in order: --token, $GITHUB_TOKEN, then
# `pass show $PASS_ENTRY` (unless --no-pass). Mirrors check_versions.py's
# precedence. Token is kept in a single variable and never exported.
resolve_token() {
    if [[ -n $TOKEN_ARG ]]; then
        printf '%s' "$TOKEN_ARG"; return 0
    fi
    if [[ -n ${GITHUB_TOKEN:-} ]]; then
        printf '%s' "$GITHUB_TOKEN"; return 0
    fi
    (( NO_PASS )) && return 0
    token_from_pass
}

# curl wrapper:
#   - fails on HTTP >= 400 (with body printed)
#   - never accepts a downgraded redirect
#   - reads the Authorization header from stdin so the token never appears in
#     argv (visible via /proc/*/cmdline).
gh_curl() {
    local token="$1"; shift
    printf 'Authorization: Bearer %s\n' "$token" | \
        curl --silent --show-error --fail-with-body \
             --proto '=https' --proto-redir '=https' \
             --location \
             --header @- \
             --header 'Accept: application/vnd.github+json' \
             --header 'X-GitHub-Api-Version: 2022-11-28' \
             "$@"
}

# --------------------------------------------------------------------------- #
# argument parsing
# --------------------------------------------------------------------------- #

while (( $# )); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        --token)   shift; (( $# )) || die "--token requires an argument"; TOKEN_ARG="$1" ;;
        --token=*) TOKEN_ARG="${1#--token=}" ;;
        --no-pass) NO_PASS=1 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; FILTERS+=("$@"); break ;;
        -*) die "unknown option: $1 (try --help)" ;;
        *)  FILTERS+=("$1") ;;
    esac
    shift
done

require_cmd curl jq awk portageq

OVERLAY_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$OVERLAY_ROOT"
[[ -d profiles ]] || die "$OVERLAY_ROOT does not look like a Gentoo overlay"

DISTDIR=$(portageq envvar DISTDIR 2>/dev/null || echo /var/cache/distfiles)
[[ -d $DISTDIR ]] || die "DISTDIR $DISTDIR does not exist"

# --------------------------------------------------------------------------- #
# package discovery
# --------------------------------------------------------------------------- #

# Print "cat/pn<TAB>ebuild_path" for EVERY ebuild that declares a vendor recipe.
# If FILTERS is non-empty, only packages whose cat/pn matches a filter are
# emitted. All versions carrying a recipe are emitted (not just the newest), so a
# package that keeps several versions in the tree (e.g. an LTS + a feature
# release) gets each version's tarball built and uploaded. process_package's
# skip-if-asset-exists check keeps repeated runs idempotent.
discover_ebuilds() {
    local match
    {
        while IFS= read -r -d '' ebuild; do
            grep -qF "$RECIPE_MARKER" "$ebuild" || continue
            local pn cat cpn
            pn=$(basename "$(dirname "$ebuild")")
            cat=$(basename "$(dirname "$(dirname "$ebuild")")")
            cpn="$cat/$pn"
            if (( ${#FILTERS[@]} )); then
                match=0
                for f in "${FILTERS[@]}"; do [[ $cpn == "$f" ]] && match=1 && break; done
                (( match )) || continue
            fi
            printf '%s\t%s\n' "$cpn" "$ebuild"
        done < <(find . -type f -name '*.ebuild' -not -path './.git/*' -print0)
    } | sort
}

# Strip leading ${PN}- and trailing -rN to recover bare PV.
derive_pv() {
    local pn="$1" p="$2" pv
    pv=${p#"${pn}-"}
    pv=${pv%-r[0-9]*}
    printf '%s' "$pv"
}

# Expand SRC_URI for $cat/$p via portageq (handles ${PV}, ${MY_PN}, etc.) and
# emit one "url<TAB>filename" line per source. USE-conditional groups are
# evaluated against the current USE; we strip "use? ( ... )" wrappers entirely
# (best-effort -- the vendor recipes here never depend on USE).
expand_src_uri() {
    local cpn="$1" p="$2" raw
    raw=$(PORTDIR_OVERLAY="$OVERLAY_ROOT" \
          portageq metadata / ebuild "${cpn%/*}/$p" SRC_URI 2>/dev/null) || return 0
    # Drop "use? (" / "!use? (" / ")" tokens; keep urls and "-> name" pairs.
    awk '
        {
            for (i = 1; i <= NF; i++) {
                t = $i
                if (t ~ /\?$/ || t == "(" || t == ")") continue
                if (t == "->") { rename = 1; continue }
                if (rename) { name = t; rename = 0; printf "%s\t%s\n", url, name; url = ""; continue }
                if (url != "") {
                    n = url; sub(".*/", "", n)
                    printf "%s\t%s\n", url, n
                }
                url = t
            }
        }
        END {
            if (url != "") { n = url; sub(".*/", "", n); printf "%s\t%s\n", url, n }
        }
    ' <<<"$raw"
}

# Extract recipe body between the marker and the first non-indented comment or
# code line. Bodies are unindented by stripping the leading "#   " (4 chars).
extract_recipe() {
    local ebuild="$1"
    awk -v marker="$RECIPE_MARKER" '
        index($0, marker) { flag=1; next }
        flag {
            if ($0 ~ /^#   /) { print substr($0, 5); next }
            if ($0 ~ /^[[:space:]]*$/) { print ""; next }
            exit
        }
    ' "$ebuild"
}

# --------------------------------------------------------------------------- #
# GitHub release / asset operations
# --------------------------------------------------------------------------- #

# Echoes the release id for a tag, creating the release if missing.
ensure_release() {
    local token="$1" tag="$2" payload response
    if response=$(gh_curl "$token" "$API/repos/$REPO/releases/tags/$tag" 2>/dev/null); then
        jq -r '.id' <<<"$response"
        return
    fi
    log "creating release $tag"
    payload=$(jq -n --arg tag "$tag" '{tag_name:$tag, name:$tag}')
    response=$(gh_curl "$token" -X POST -H 'Content-Type: application/json' \
                   --data "$payload" "$API/repos/$REPO/releases") || \
        die "failed to create release $tag"
    jq -r '.id' <<<"$response"
}

# Echoes the asset id (if any) for a filename on a release.
find_asset_id() {
    local token="$1" release_id="$2" filename="$3" response
    response=$(gh_curl "$token" "$API/repos/$REPO/releases/$release_id/assets?per_page=100") || return 1
    jq -r --arg n "$filename" '.[] | select(.name==$n) | .id' <<<"$response"
}

upload_asset() {
    local token="$1" release_id="$2" file="$3" filename
    filename=$(basename "$file")
    log "uploading $filename"
    gh_curl "$token" -X POST \
            -H 'Content-Type: application/octet-stream' \
            --data-binary "@$file" \
            "$UPLOADS/repos/$REPO/releases/$release_id/assets?name=$(jq -rn --arg n "$filename" '$n|@uri')" \
        >/dev/null
}

delete_asset() {
    local token="$1" asset_id="$2"
    log "deleting old asset id=$asset_id"
    gh_curl "$token" -X DELETE "$API/repos/$REPO/releases/assets/$asset_id" >/dev/null
}

# --------------------------------------------------------------------------- #
# per-package processing
# --------------------------------------------------------------------------- #

process_package() {
    local token="$1" cpn="$2" ebuild="$3"
    local pn p pv tarball tag
    pn=${cpn#*/}
    p=$(basename "$ebuild" .ebuild)
    p=${p%-r[0-9]*}
    pv=$(derive_pv "$pn" "$p")
    tarball="${p}-vendor.tar.xz"
    tag="$tarball"

    log "=== $cpn  ($p) ==="

    # Skip-if-exists check before doing any work.
    if (( ! FORCE )); then
        local rid aid=""
        if rid=$(gh_curl "$token" "$API/repos/$REPO/releases/tags/$tag" 2>/dev/null \
                     | jq -r '.id // empty'); then
            if [[ -n $rid ]]; then
                aid=$(find_asset_id "$token" "$rid" "$tarball" || true)
                if [[ -n $aid ]]; then
                    log "$tarball already exists on release $tag (asset id $aid); skipping (use --force to replace)"
                    return 0
                fi
            fi
        fi
    fi

    # Extract recipe.
    local recipe
    recipe=$(extract_recipe "$ebuild")
    [[ -n $recipe ]] || { warn "could not extract recipe from $ebuild"; return 1; }

    printf -- '--- recipe for %s ---\n%s\n--- end recipe ---\n' "$p" "$recipe"

    if (( DRY_RUN )); then
        log "dry-run: would fetch distfiles, run recipe, and upload $tarball"
        return 0
    fi

    confirm "Run this recipe?" || { warn "skipped $cpn by user"; return 0; }

    local workdir
    workdir=$(mktemp -d -t "vendor-${pn}.XXXXXX")
    local _cleanup_workdir="$workdir"
    trap 'rm -rf "${_cleanup_workdir:-}"' RETURN

    # Bootstrap base distfiles into $workdir. We do NOT use `ebuild fetch`
    # because for a freshly-bumped ebuild the Manifest does not yet contain
    # the new file's hash, so portage refuses to keep the download.
    # Instead, expand SRC_URI via portageq and download each entry directly
    # (skipping the vendor tarball, which is what we're about to generate).
    local url name
    while IFS=$'\t' read -r url name; do
        [[ -z $url ]] && continue
        if [[ $name == "$tarball" ]]; then continue; fi
        if [[ -f "$DISTDIR/$name" ]]; then
            log "using cached $name from $DISTDIR"
            cp -- "$DISTDIR/$name" "$workdir/$name"
        else
            log "fetching $url -> $name"
            curl --silent --show-error --fail-with-body --location \
                 --proto '=https' --proto-redir '=https' \
                 -o "$workdir/$name" "$url" || \
                die "fetch failed: $url"
        fi
    done < <(expand_src_uri "$cpn" "$p")

    # The recipe is trusted input: it is authored in this overlay's own
    # ebuilds, not fetched from anywhere. It runs in a clean bash -e process;
    # the shell exits non-zero if any command in the recipe fails.
    # GITHUB_TOKEN is NOT exported here.
    if ! ( cd "$workdir" && P="$p" PN="$pn" PV="$pv" bash -eo pipefail -c "$recipe" ); then
        warn "recipe failed for $p"
        return 1
    fi

    if [[ ! -f $workdir/$tarball ]]; then
        warn "recipe did not produce $tarball"
        return 1
    fi

    local rid aid
    rid=$(ensure_release "$token" "$tag")
    [[ -n $rid ]] || die "could not resolve release id for $tag"

    if (( FORCE )); then
        aid=$(find_asset_id "$token" "$rid" "$tarball" || true)
        [[ -n $aid ]] && delete_asset "$token" "$aid"
    fi

    upload_asset "$token" "$rid" "$workdir/$tarball"
    log "uploaded $tarball to release $tag"
    # $workdir is removed by the RETURN trap set above.
}

# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #

main() {
    mapfile -t entries < <(discover_ebuilds)
    if (( ${#entries[@]} == 0 )); then
        if (( ${#FILTERS[@]} )); then
            die "no matching ebuilds with vendor recipes found: ${FILTERS[*]}"
        fi
        die "no ebuilds with vendor recipes found"
    fi

    log "found ${#entries[@]} package(s) with vendor recipes"
    for e in "${entries[@]}"; do log "  ${e%%$'\t'*}"; done

    local token=""
    if (( ! DRY_RUN )); then
        token=$(resolve_token)
        [[ -n $token ]] || die "no GitHub token (use --token, set \$GITHUB_TOKEN, or store it in \`pass\` as $PASS_ENTRY)"
    fi

    local failed=0
    for e in "${entries[@]}"; do
        local cpn=${e%%$'\t'*} ebuild=${e#*$'\t'}
        if ! process_package "$token" "$cpn" "$ebuild"; then
            failed=$((failed + 1))
        fi
    done

    (( failed == 0 )) || die "$failed package(s) failed"
    log "all done"
}

main
