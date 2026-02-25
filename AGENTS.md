# Agents Guide — Stackable Documentation

This file helps AI coding agents (and humans) understand how to work with this repository.

## Project Overview

This is the **Stackable Documentation** site, built with [Antora](https://antora.org/).
It aggregates AsciiDoc content from this repo plus ~18 operator repos from the `stackabletech` GitHub org.
The UI comes from a git submodule in `ui/` (the [documentation-ui](https://github.com/stackabletech/documentation-ui) repo).

## Prerequisites

- Node.js (tested with v22)
- npm
- make
- Python 3 (only for `make serve`)

## Setup

```sh
git submodule update --init        # fetch the UI submodule
npm ci                             # install dependencies
```

## Build Targets

All build targets first run `build-ui` (gulp bundles the UI into `ui/build/ui-bundle.zip`).

Pass extra Antora flags via `ANTORAFLAGS`, e.g. `make ANTORAFLAGS=--fetch <target>`.

### Recommended build

For normal use this is the recommended build target:

```sh
make ANTORAFLAGS=--fetch build-only-dev
```

This will _not_ work if you want to test documentation changes that are under development in sibling repositories.

### Important: the `--fetch` flag

Antora caches cloned git repos in `./cache/`. Without `--fetch`, it reuses stale cached content.
**On first build or whenever operator repos have new content, you must pass `--fetch`:**

```sh
make ANTORAFLAGS=--fetch build-only-dev
```

Without `--fetch`, you will see errors like `target of xref not found` because the cached operator docs are outdated.
These errors are fatal because `runtime.log.failure_level` is set to `warn` in the playbooks.

### Cleaning up

```sh
make clean       # removes build/ and cache/ directories
```

### Serving locally

```sh
make serve       # python3 HTTP server on port 8000 serving build/site/
```

Then open http://localhost:8000.

## Quick Start (copy-paste)

```sh
git submodule update --init
npm ci
make ANTORAFLAGS=--fetch build-only-dev
make serve
```

## Repository Structure

- `antora.yml` — Defines the `home` Antora component (version, nav, attributes)
- `modules/` — Platform-level documentation content (concepts, guides, tutorials, operators, etc.)
- `ui/` — Git submodule pointing to [documentation-ui](https://github.com/stackabletech/documentation-ui); bundled by gulp
- `supplemental-ui/` — UI overrides and the `stackable-operator-helpers.js` Antora extension
- `*-playbook.yml` — Antora playbook files (see Build Targets above)
- `cache/` — Antora's git cache directory (gitignored, remove with `make clean`)
- `build/site/` — Generated static site output

## Diagnosing Broken xrefs

When you see `target of xref not found: kafka:some-page.adoc`:

### Finding the correct page path

Operator docs are cached in `./cache/content/`. To find the right path:

```sh
# List the cached repos:
ls cache/content/

# List pages in an operator's docs (e.g. kafka):
git -C cache/content/<kafka-repo>.git ls-tree -r --name-only main:docs/modules/kafka/pages/

# Check if a specific page exists:
git -C cache/content/<kafka-repo>.git show main:docs/modules/kafka/pages/usage-guide/security.adoc

# Search for a heading/anchor:
git -C cache/content/<kafka-repo>.git show main:docs/modules/kafka/pages/usage-guide/security.adoc | grep -i "authorization"
```

## Checking the build output

After building, the generated HTML lives in `build/site/`:

```sh
# Find operator pages:
ls build/site/home/nightly/kafka/
```


## Common Issues

### Beware of redirect aliases

Antora creates redirect pages when pages are renamed (via `page-aliases` in AsciiDoc). A link like `kafka:usage.adoc` may produce a valid HTML file (`usage.html`) that is just a redirect to `usage-guide/index.html`. Antora will **not** flag this as broken, but the link points to the wrong place. Always verify that an xref points to the intended content, not just that the build passes.

### Build fails with "target of xref not found"

This almost always means cached operator repos are stale. Fix: `make ANTORAFLAGS=--fetch <target>` or `make clean` first.

### `build-truly-local` fails with missing xrefs

This requires all operator repos to be cloned as sibling directories at matching branches.
Cross-repo xrefs will break if any sibling repo is on a different branch or has stale content.

### UI bundle not found

Run `git submodule update --init` to fetch the UI submodule, then `npm ci` to install dependencies (including gulp).

## Agent Skills

Reusable skills for AI agents are in `.agents/skills/` following the [Agent Skills](https://agentskills.io) open standard:

- [documentation-reviewer](.agents/skills/documentation-reviewer/SKILL.md) — Review documentation for clarity, consistency, and best practices. Use when creating or editing documentation files.

## Notes for AI Agents

- The **safest and fastest** local build is `make ANTORAFLAGS=--fetch build-only-dev`.
- Read the comment in Makefile for more options to build
- Avoid `build-prod` unless explicitly asked — it fetches all release branches from ~18 repos and is very slow.
- The `failure_level: warn` setting in playbooks means any asciidoctor warning/error is fatal. Broken xrefs will fail the build.
- Content from operator repos (e.g. `airflow:index.adoc`) lives in those repos under `docs/`, not in this repo.
- Cross-repo xrefs use Antora component names like `airflow:`, `kafka:`, `trino:` etc.
- After editing AsciiDoc content, run the build to verify no broken xrefs were introduced.
- After building, run `lychee --offline --no-progress --root-dir build/site 'build/site/home/nightly/**/*.html'` to catch broken HTML links that Antora's xref checker misses.
- When fixing a broken xref, check the cached repo to find the correct page path rather than guessing (see "Diagnosing Broken xrefs" above).
- Watch out for redirect aliases: a "resolved" xref may still link to the wrong content.
