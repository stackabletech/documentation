#!/usr/bin/env bash
set -euo pipefail

# Gather the GitHub issues and pull requests that feed the release notes for a
# given SDP release, straight from the stackabletech org.
#
# It searches for items carrying BOTH:
#   - a release label:   release/<major.minor.patch>  OR  scheduled-for/<major.minor.patch>
#   - a release-note label: release-note  OR  release-note/action-required
#
# and prints a report grouped by repository, including the "Release notes"
# snippet from each item body (the section the authors write in the PR template).
#
# It also flags two things that need human attention before a release:
#   - items still labelled `scheduled-for/<version>` (merged PRs should be
#     re-labelled `release/<version>`; open ones need to land or be dropped).
#   - open / unmerged PRs in the set.
#
# Counts are the ground truth from pagination, NOT the GitHub search
# `total_count` (the web UI and that field can be misleading).
#
# Requires: gh (authenticated), jq.
#
# Usage:
#   scripts/gather-release-notes.sh -v <major.minor.patch> [--json]
#
#   -v, --version   Required. e.g. 26.7.0
#       --json      Dump the raw combined JSON (all items) instead of the report.
#
# Examples:
#   scripts/gather-release-notes.sh -v 26.7.0
#   scripts/gather-release-notes.sh -v 26.7.0 --json > items.json

# ------------------------------
# Args parsing
# ------------------------------

VERSION=""
OUTPUT="report"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) VERSION="$2"; shift ;;
        --json) OUTPUT="json" ;;
        -h|--help) sed -n '3,30p' "$0"; exit 0 ;;
        *) echo "Unknown parameter passed: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ -z "$VERSION" ]; then
    echo "Usage: gather-release-notes.sh -v <major.minor.patch> [--json]" >&2
    exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the major.minor.patch format (e.g. 26.7.0)." >&2
    exit 1
fi

for tool in gh jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' not found on PATH." >&2
        exit 1
    fi
done

# Minor version, e.g. 26.7 from 26.7.0
MINOR=$(echo "$VERSION" | cut -d. -f1,2)

RELEASE_LABEL="release/$VERSION"
SCHEDULED_LABEL="scheduled-for/$VERSION"
QUERY="org:stackabletech label:$SCHEDULED_LABEL,$RELEASE_LABEL label:release-note,release-note/action-required"

# ------------------------------
# Fetch (single paginated search; the search API already returns bodies)
# ------------------------------

ITEMS_FILE=$(mktemp)
trap 'rm -f "$ITEMS_FILE"' EXIT

# --paginate over search returns one JSON object per page; slurp the .items
# arrays together and de-duplicate by html_url (defensive against overlap).
gh api -X GET search/issues --paginate -f q="$QUERY" --jq '.items[]' \
    | jq -s 'unique_by(.html_url)' > "$ITEMS_FILE"

if [ "$OUTPUT" = "json" ]; then
    cat "$ITEMS_FILE"
    exit 0
fi

# ------------------------------
# Helper: is this item an action-required one?
# ------------------------------
is_action_required() { echo "$1" | jq -e 'any(.labels[].name; . == "release-note/action-required")' >/dev/null; }

# ------------------------------
# Counts (ground truth = number of items actually returned)
# ------------------------------
TOTAL=$(jq 'length' "$ITEMS_FILE")
N_ISSUES=$(jq '[.[] | select(.pull_request == null)] | length' "$ITEMS_FILE")
N_PRS=$(jq '[.[] | select(.pull_request != null)] | length' "$ITEMS_FILE")

echo "# Release-notes source data for $VERSION (minor: $MINOR)"
echo "#"
echo "# Query: (label:$SCHEDULED_LABEL OR label:$RELEASE_LABEL)"
echo "#        AND (label:release-note OR label:release-note/action-required)"
echo
echo "## Counts (ground truth via pagination, not search total_count)"
echo "  Issues: $N_ISSUES"
echo "  PRs:    $N_PRS"
echo "  Total:  $TOTAL"
echo

# ------------------------------
# Hygiene flags
# ------------------------------
echo "## Hygiene flags"
echo
echo "### Items still labelled '$SCHEDULED_LABEL'"
echo "# (merged PRs should be re-labelled '$RELEASE_LABEL'; open ones must land or be dropped)"
SCHEDULED=$(jq -r --arg L "$SCHEDULED_LABEL" '
    [.[] | select(any(.labels[].name; . == $L))]
    | if length == 0 then "  (none)" else
        .[] | "  \(.repository_url | sub(".*/repos/stackabletech/";"")) #\(.number) [" +
        (if .pull_request == null then "issue"
         elif .pull_request.merged_at != null then "PR-MERGED"
         else "PR-OPEN" end) + "] \(.title)"
      end' "$ITEMS_FILE")
echo "$SCHEDULED"
echo
echo "### Open / unmerged PRs in the set (resolve before release)"
OPEN_PRS=$(jq -r '
    [.[] | select(.pull_request != null and .state == "open")]
    | if length == 0 then "  (none)" else
        .[] | "  \(.repository_url | sub(".*/repos/stackabletech/";"")) #\(.number) \(.title)"
      end' "$ITEMS_FILE")
echo "$OPEN_PRS"
echo

# ------------------------------
# Items grouped by repository, with release-note snippet
# ------------------------------
echo "## Items grouped by repository"

REPOS=$(jq -r '[.[] | .repository_url | sub(".*/repos/stackabletech/";"")] | unique | .[]' "$ITEMS_FILE")

while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    echo
    echo "### $repo"
    # Iterate items for this repo (compact JSON per line)
    jq -c --arg R "$repo" '.[] | select((.repository_url | sub(".*/repos/stackabletech/";"")) == $R)' "$ITEMS_FILE" \
    | while IFS= read -r item; do
        number=$(echo "$item" | jq -r '.number')
        title=$(echo "$item" | jq -r '.title')
        url=$(echo "$item" | jq -r '.html_url')
        labels=$(echo "$item" | jq -r '[.labels[].name] | join(", ")')
        if echo "$item" | jq -e '.pull_request == null' >/dev/null; then
            kind="issue"
        elif echo "$item" | jq -e '.pull_request.merged_at != null' >/dev/null; then
            kind="PR-merged"
        else
            kind="PR-$(echo "$item" | jq -r '.state')"
        fi
        marker=""
        if is_action_required "$item"; then marker=" **ACTION-REQUIRED**"; fi

        echo "- #$number [$kind]$marker $title"
        echo "  $url"
        echo "  labels: $labels"
        # Extract the "Release note(s)" section from the body, if present.
        snippet=$(echo "$item" | jq -r '.body // ""' | awk '
            BEGIN { grab=0 }
            /^#+[[:space:]]*[Rr]elease[[:space:]]*[Nn]ote/ { grab=1; next }
            grab && /^#+[[:space:]]/ { exit }
            grab { print }
        ' | sed 's/^/    /' | sed '/^[[:space:]]*$/d')
        if [ -n "$snippet" ]; then
            echo "  release-note snippet:"
            echo "$snippet"
        else
            echo "  release-note snippet: (none found in body)"
        fi
    done
done <<< "$REPOS"
