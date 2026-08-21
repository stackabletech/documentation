// Keeps the "Supported versions" lists in sync with the Stackable Hub.
//
// At build time the supported-versions.adoc partial of every product operator
// module is generated from https://hub.stackable.tech/api/v1/components/<slug>.
//
// * Released docs versions map to that SDP release
// * Nightly maps to the _next_ upcoming release if there is one
// * If there is no upcoming release yet on the Hub it will say so ("not decided yet")
//
// We usually have a gap after a release was made before we decide on the versions for the next one.
//
// Because we need the partials there is a cache of Hub data which is used while/if it is unavailable.
//
// Useful links:
// Extensions: https://docs.antora.org/antora/latest/extend/extensions/
// Types of events: https://docs.antora.org/antora/latest/extend/generator-events-reference/
'use strict'

const fs = require('fs')
const ospath = require('path')

const HUB_API = 'https://hub.stackable.tech/api/v1/components'
const PARTIAL = 'supported-versions.adoc'
const HUB_TIMEOUT_MS = 10_000

// docs module name -> Hub component slug
const MODULE_TO_SLUG = {
  airflow: 'airflow',
  druid: 'druid',
  hbase: 'hbase',
  hdfs: 'hdfs',
  hive: 'hive',
  kafka: 'kafka',
  nifi: 'nifi',
  opa: 'opa',
  opensearch: 'opensearch',
  'spark-k8s': 'spark',
  superset: 'superset',
  trino: 'trino',
  zookeeper: 'zookeeper',
}

const STATUS_SUFFIX = {
  lts: ' (LTS)',
  deprecated: ' (deprecated)',
  experimental: ' (experimental)',
  preview: ' (preview)',
}

module.exports.register = function () {
  const logger = this.getLogger('hub-supported-versions')

  // contentClassified rather than contentAggregated: the content catalog is what
  // can add a file, and partials are resolved later, when pages are converted.
  this.once('contentClassified', async ({ playbook, contentCatalog }) => {
    const cacheDir = ospath.join(playbook.dir || '.', playbook.runtime.cacheDir || './cache', 'hub')
    const components = await fetchComponents(cacheDir, logger)

    const component = contentCatalog.getComponent('home')
    if (!component) return logger.info('no home component, nothing to do')

    let written = 0
    for (const { version } of component.versions) {
      for (const [moduleName, slug] of Object.entries(MODULE_TO_SLUG)) {
        const existing = contentCatalog.getById({
          component: 'home', version, module: moduleName, family: 'partial', relative: PARTIAL,
        })
        // A module we do not carry in this docs version at all: nothing includes
        // the partial, so do not invent one.
        if (!existing && !contentCatalog.getById({
          component: 'home', version, module: moduleName, family: 'page', relative: 'index.adoc',
        })) continue

        const body = renderPartial({
          components, slug, version, logger, hasRepoCopy: Boolean(existing),
        })
        if (!body) continue // the repo ships a copy and the Hub has nothing better

        if (existing) {
          existing.contents = Buffer.from(body, 'utf8')
        } else {
          contentCatalog.addFile({
            contents: Buffer.from(body, 'utf8'),
            src: { component: 'home', version, module: moduleName, family: 'partial', relative: PARTIAL },
          })
        }
        written++
      }
    }
    logger.info(`wrote ${written} supported-versions partial(s) from the Hub`)
  })
}

// Returns the AsciiDoc body, or undefined to mean "leave whatever is there".
function renderPartial ({ components, slug, version, logger, hasRepoCopy }) {
  const header = `// Generated at build time from ${HUB_API}/${slug}.\n` +
    '// Do not edit: the Portal is the source of truth. See lib/hub-supported-versions.js.\n'

  if (!components) {
    // No Hub data at all. An existing partial is better than anything we can say,
    // but a missing one still has to resolve or the include fails the build.
    return `${header}// The Stackable Hub was unreachable during this build.\n` +
      'The supported version list is temporarily unavailable.\n'
  }

  const found = resolveRelease(components[slug], version)

  if (!found || !found.entry.versions || !found.entry.versions.length) {
    if (version === 'nightly') {
      logger.info(`no public upcoming release for ${slug}, rendering the undecided note on nightly`)
      return `${header}// No upcoming SDP release is public yet, so there is nothing to list.\n` +
        'The product versions for the next Stackable Data Platform release have not been decided yet.\n'
    }
    // A docs version the Hub knows nothing about. Prefer the repo's own copy,
    // but if there is none we still have to emit something: an include with no
    // target fails the build, and generating these is what lets the operator
    // repos delete theirs in the first place.
    if (hasRepoCopy) {
      logger.info(`no Hub data for ${slug} in SDP ${version}, keeping the partial from the repo`)
      return undefined
    }
    logger.info(`no Hub data for ${slug} in SDP ${version} and no copy in the repo`)
    return `${header}// The Hub has no data for SDP ${version}.\n` +
      `The supported version list for SDP ${version} is unavailable.\n`
  }

  const lines = found.entry.versions.map((v) => `- ${v.version}${STATUS_SUFFIX[v.status] || ''}`)
  const label = found.entry.release || 'next'
  const provisional = found.provisional
    ? `// Provisional: SDP ${label} has not been released yet.\n` +
      `NOTE: These are the planned product versions for SDP ${label}. They may still change.\n\n`
    : ''
  return header + provisional + lines.join('\n') + '\n'
}

// Resolves a docs version to a Hub release entry, shipped releases first and
// then the public upcoming ones. Nightly is not a release identifier, so it maps
// to whichever upcoming release is next.
//
// Whether the entry came from upcomingReleases is what makes a list provisional
// - not whether the docs version is nightly. A release branch is often cut and
// built before its SDP release ships, so those docs need the upcoming data too.
function resolveRelease (component, version) {
  if (version === 'nightly') {
    const next = nextUpcoming(component)
    return next ? { entry: next, provisional: true } : undefined
  }
  const shipped = (component?.releases || []).find((r) => r.release === version)
  if (shipped) return { entry: shipped, provisional: false }
  const upcoming = (component?.upcomingReleases || []).find((r) => r.release === version)
  return upcoming ? { entry: upcoming, provisional: true } : undefined
}

// The next public upcoming release: earliest planned date, falling back to the
// order the Hub returned. The Hub only lists upcoming releases it considers
// public, so anything here is safe to show.
function nextUpcoming (component) {
  const upcoming = component?.upcomingReleases || []
  if (upcoming.length < 2) return upcoming[0]
  return [...upcoming].sort((a, b) =>
    String(a.plannedReleaseDate || '9999').localeCompare(String(b.plannedReleaseDate || '9999')))[0]
}

async function fetchComponents (cacheDir, logger) {
  const cacheFile = ospath.join(cacheDir, 'components.json')
  try {
    const { components: list } = await getJson(`${HUB_API}`)
    const components = {}
    for (const { slug } of list) {
      components[slug] = await getJson(`${HUB_API}/${slug}`)
    }
    fs.mkdirSync(cacheDir, { recursive: true })
    fs.writeFileSync(cacheFile, JSON.stringify(components))
    return components
  } catch (err) {
    logger.info(`could not fetch ${HUB_API} (${err.message}), trying cache`)
    try {
      return JSON.parse(fs.readFileSync(cacheFile, 'utf8'))
    } catch {
      logger.info('no cached Hub data available')
      return undefined
    }
  }
}

// A Hub that accepts the connection and never answers is not an error, so it
// would otherwise stall the docs build indefinitely rather than falling back to
// the cache. An abort surfaces as a rejection, which the caller already handles.
async function getJson (url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(HUB_TIMEOUT_MS) })
  if (!response.ok) throw new Error(`${url} returned ${response.status}`)
  return await response.json()
}
