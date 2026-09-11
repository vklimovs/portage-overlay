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
#   --verify     Re-run each recipe and compare against the Manifest instead of
#                uploading. Needs no token. Exits non-zero on mismatch.
#   --from DIR   Take ${P}-vendor.tar.xz from DIR instead of running the recipe,
#                for builds produced elsewhere. The Manifest check still applies.
#   --published  Download each released asset and check it against the Manifest.
#                Implies --verify. Needs no token.
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
#   upload_vendor_tarballs.sh --verify --yes        # rebuild and check every hash
#   upload_vendor_tarballs.sh --published           # check what users actually fetch
#   upload_vendor_tarballs.sh --from ~/jail/distfiles --force --yes

set -euo pipefail

readonly REPO="vklimovs/portage-overlay"
readonly RECIPE_MARKER="generate the vendor tarball:"
readonly API="https://api.github.com"
readonly UPLOADS="https://uploads.github.com"
readonly PASS_ENTRY="Github/portage-overlay-releases"

DRY_RUN=0
VERIFY=0
PUBLISHED=0
FROM_DIR=""
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

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; }

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

# Empty is not fatal here -- main decides that.
resolve_token() {
    if [[ -n $TOKEN_ARG ]]; then printf '%s' "$TOKEN_ARG"
    elif [[ -n ${GITHUB_TOKEN:-} ]]; then printf '%s' "$GITHUB_TOKEN"
    elif (( ! NO_PASS )) && command -v pass >/dev/null 2>&1; then
        pass show "$PASS_ENTRY" 2>/dev/null | head -n1 || true
    fi
}

# The Authorization header comes from stdin so the token stays out of argv,
# which is world-readable via /proc.
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
        --verify)  VERIFY=1 ;;
        --published) PUBLISHED=1; VERIFY=1 ;;
        --from)    shift; (( $# )) || die "--from requires an argument"; FROM_DIR="$1" ;;
        --from=*)  FROM_DIR="${1#--from=}" ;;
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

require_cmd curl jq awk portageq b2sum sha512sum

OVERLAY_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$OVERLAY_ROOT"
[[ -d profiles ]] || die "$OVERLAY_ROOT does not look like a Gentoo overlay"

DISTDIR=$(portageq envvar DISTDIR 2>/dev/null || echo /var/cache/distfiles)
[[ -d $DISTDIR ]] || die "DISTDIR $DISTDIR does not exist"

# --------------------------------------------------------------------------- #
# package discovery
# --------------------------------------------------------------------------- #

# Every version with a recipe, not just the newest: a package can keep an LTS
# and a feature release side by side and both need their tarball.
discover_ebuilds() {
    while IFS= read -r -d '' ebuild; do
        grep -qF "$RECIPE_MARKER" "$ebuild" || continue
        ebuild=${ebuild#./}
        local cpn=${ebuild%/*}
        if (( ${#FILTERS[@]} )); then
            [[ " ${FILTERS[*]} " == *" $cpn "* ]] || continue
        fi
        printf '%s\t%s\n' "$cpn" "$ebuild"
    done < <(find . -type f -name '*.ebuild' -not -path './.git/*' -print0) | sort
}

# Emits "url<TAB>filename" per source. USE conditionals are flattened rather
# than evaluated, which holds only because no vendor recipe depends on USE.
expand_src_uri() {
    local cpn="$1" p="$2" raw
    raw=$(PORTDIR_OVERLAY="$OVERLAY_ROOT" \
          portageq metadata / ebuild "${cpn%/*}/$p" SRC_URI 2>/dev/null) || return 0
    awk '{
        for (i = 1; i <= NF; i++) {
            t = $i
            if (t ~ /\?$/ || t == "(" || t == ")") continue
            if ($(i+1) == "->") { print t "\t" $(i+2); i += 2; continue }
            n = t; sub(".*/", "", n); print t "\t" n
        }
    }' <<<"$raw"
}

# The body ends at the first line not indented by "#   ".
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

# Echoes "size blake2b sha512", or nothing when the entry is absent.
manifest_entry() {
    local manifest="$1" filename="$2"
    [[ -f $manifest ]] || return 0
    awk -v n="$filename" '$1=="DIST" && $2==n {
        for (i = 4; i < NF; i += 2) h[$i] = $(i+1)
        print $3, h["BLAKE2B"], h["SHA512"]
        exit
    }' "$manifest"
}

# 0 = match, 1 = mismatch, 2 = no Manifest entry to check against.
verify_tarball() {
    local ebuild="$1" file="$2" filename entry size b2 sha got
    filename=$(basename "$file")
    entry=$(manifest_entry "$(dirname "$ebuild")/Manifest" "$filename")
    [[ -n $entry ]] || { warn "no Manifest entry for $filename"; return 2; }
    read -r size b2 sha <<<"$entry"
    got="$(stat -c %s "$file") $(b2sum "$file" | cut -d' ' -f1) $(sha512sum "$file" | cut -d' ' -f1)"
    if [[ $got == "$size $b2 $sha" ]]; then
        log "MATCH $filename"
        return 0
    fi
    warn "MISMATCH $filename"
    warn "  manifest: $size $b2 $sha"
    warn "  local:    $got"
    return 1
}

# --------------------------------------------------------------------------- #
# GitHub release / asset operations
# --------------------------------------------------------------------------- #

# Creates the release if the tag has none.
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

# Mismatch is fatal. A missing entry is not -- that is an upload made before
# `pkgdev manifest` has seen the file.
publish_tarball() {
    local token="$1" ebuild="$2" file="$3" tag="$4" tarball="$5" rc=0

    verify_tarball "$ebuild" "$file" || rc=$?
    case $rc in
        0) ;;
        2) warn "uploading $tarball unverified" ;;
        *) die "refusing to upload $tarball: does not match the Manifest" ;;
    esac

    local rid aid
    rid=$(ensure_release "$token" "$tag")
    [[ -n $rid ]] || die "could not resolve release id for $tag"

    if (( FORCE )); then
        aid=$(find_asset_id "$token" "$rid" "$tarball" || true)
        [[ -n $aid ]] && delete_asset "$token" "$aid"
    fi

    upload_asset "$token" "$rid" "$file"
    log "uploaded $tarball to release $tag"
}

# --------------------------------------------------------------------------- #
# per-package processing
# --------------------------------------------------------------------------- #

process_package() {
    local token="$1" cpn="$2" ebuild="$3"
    local pn p pv tarball tag
    pn=${cpn#*/}
    p=${ebuild##*/}
    p=${p%.ebuild}
    p=${p%-r[0-9]*}
    pv=${p#"${pn}-"}
    tarball="${p}-vendor.tar.xz"
    tag="$tarball"

    log "=== $cpn  ($p) ==="

    if (( ! FORCE && ! VERIFY )); then
        local rid aid
        rid=$(gh_curl "$token" "$API/repos/$REPO/releases/tags/$tag" 2>/dev/null \
                  | jq -r '.id // empty') || rid=""
        aid=$([[ -n $rid ]] && find_asset_id "$token" "$rid" "$tarball" || true)
        if [[ -n $aid ]]; then
            log "$tarball already on release $tag (asset id $aid), skipping (use --force to replace)"
            return 0
        fi
    fi

    # A Manifest bumped without the upload happening passes every other check.
    if (( PUBLISHED )); then
        local pubdir
        pubdir=$(mktemp -d -t "vendor-${pn}.XXXXXX")
        trap 'rm -rf "$pubdir"' RETURN
        if ! curl --silent --show-error --fail --location \
                  --proto '=https' --proto-redir '=https' \
                  -o "$pubdir/$tarball" \
                  "https://github.com/$REPO/releases/download/$tag/$tarball"; then
            warn "not published: $tarball"
            return 1
        fi
        verify_tarball "$ebuild" "$pubdir/$tarball" || return 1
        return 0
    fi

    # Nothing is rebuilt, so the Manifest check is all that vouches for these.
    if [[ -n $FROM_DIR ]]; then
        local src="$FROM_DIR/$tarball"
        [[ -f $src ]] || { warn "no $tarball in $FROM_DIR"; return 1; }

        if (( VERIFY )); then
            verify_tarball "$ebuild" "$src" || return 1
            return 0
        fi

        if (( DRY_RUN )); then
            log "dry-run: would check $src against the Manifest and upload it"
            return 0
        fi

        publish_tarball "$token" "$ebuild" "$src" "$tag" "$tarball"
        return
    fi

    local recipe
    recipe=$(extract_recipe "$ebuild")
    [[ -n $recipe ]] || { warn "could not extract recipe from $ebuild"; return 1; }

    printf -- '--- recipe for %s ---\n%s\n--- end recipe ---\n' "$p" "$recipe"

    if (( DRY_RUN )); then
        if (( VERIFY )); then
            log "dry-run: would fetch distfiles, run recipe, and check $tarball against the Manifest"
        else
            log "dry-run: would fetch distfiles, run recipe, and upload $tarball"
        fi
        return 0
    fi

    confirm "Run this recipe?" || { warn "skipped $cpn by user"; return 0; }

    local workdir
    workdir=$(mktemp -d -t "vendor-${pn}.XXXXXX")
    trap 'rm -rf "$workdir"' RETURN

    # Not `ebuild fetch`: on a fresh bump the Manifest lacks the new hash, so
    # portage discards the download.
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

    # Trusted input -- it comes from this overlay's own ebuilds. The token is
    # deliberately not exported into it.
    if ! ( cd "$workdir" && P="$p" PN="$pn" PV="$pv" bash -eo pipefail -c "$recipe" ); then
        warn "recipe failed for $p"
        return 1
    fi

    if [[ ! -f $workdir/$tarball ]]; then
        warn "recipe did not produce $tarball"
        return 1
    fi

    if (( VERIFY )); then
        verify_tarball "$ebuild" "$workdir/$tarball" || return 1
        return 0
    fi

    publish_tarball "$token" "$ebuild" "$workdir/$tarball" "$tag" "$tarball"
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
    if (( ! DRY_RUN && ! VERIFY )); then
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

    if (( VERIFY )); then
        (( failed == 0 )) || die "$failed package(s) did not match the Manifest"
        log "all ${#entries[@]} package(s) match the Manifest"
        return
    fi
    (( failed == 0 )) || die "$failed package(s) failed"
    log "all done"
}

main
