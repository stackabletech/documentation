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
    # Enrich each item with its comments and a trimmed set of fields, so the
    # release-note text (which authors write free-form, in the body OR a
    # comment) is available in one place for a human/agent to read and
    # interpret. Deliberately NO regex extraction here - see the note below.
    jq -c '.[]' "$ITEMS_FILE" | while IFS= read -r item; do
        full=$(echo "$item" | jq -r '.repository_url | sub(".*/repos/";"")')
        number=$(echo "$item" | jq -r '.number')
        comments=$(gh api "repos/$full/issues/$number/comments" --jq '[.[] | {author: .user.login, body}]' 2>/dev/null || echo '[]')
        echo "$item" | jq -c --argjson comments "$comments" '{
            repo: (.repository_url | sub(".*/repos/";"")),
            number, title, html_url, state,
            is_pr: (.pull_request != null),
            merged: (.pull_request.merged_at != null),
            labels: [.labels[].name],
            action_required: (any(.labels[].name; . == "release-note/action-required")),
            body: (.body // ""),
            comments: $comments
        }'
    done | jq -s '.'
    exit 0
fi

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
# Item inventory grouped by repository (metadata only).
#
# NOTE: we deliberately do NOT try to extract the release-note text here.
# Authors write it free-form - under headings like `### Release notes`, an
# inline `Release-Note:` label, a bare `# Release notes` in a *linked* comment,
# or interleaved with reviewer instructions. A regex can't reliably tell a real
# note from a template checklist line ("- [ ] Release note snippet added") or
# reviewer chatter. Reading and interpreting that text is the skill's job:
# run this script with `--json` to get each item's full body + comments, then
# read them. This inventory is just the deterministic "what's in the release".
# ------------------------------
echo "## Item inventory grouped by repository"
echo "# For the release-note text of each item, run this script with --json and read the body + comments."

REPOS=$(jq -r '[.[] | .repository_url | sub(".*/repos/stackabletech/";"")] | unique | .[]' "$ITEMS_FILE")

while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    echo
    echo "### $repo"
    jq -r --arg R "$repo" '
        def kind: if .pull_request == null then "issue"
                  elif .pull_request.merged_at != null then "PR-merged"
                  else "PR-" + .state end;
        def ar: if any(.labels[].name; . == "release-note/action-required")
                then " **ACTION-REQUIRED**" else "" end;
        [.[] | select((.repository_url | sub(".*/repos/stackabletech/";"")) == $R)]
        | sort_by(.number)[]
        | "- #\(.number) [\(kind)]\(ar) \(.title)\n  \(.html_url)\n  labels: \([.labels[].name] | join(", "))"
    ' "$ITEMS_FILE"
done <<< "$REPOS"
