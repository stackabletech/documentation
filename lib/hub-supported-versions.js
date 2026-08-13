// Keeps the "Supported versions" lists in sync with the Stackable Hub, whose data
// comes from the Portal, the source of truth for what a release ships.
//
// At build time the supported-versions.adoc partial of every product operator
// module is generated from https://hub.stackable.tech/api/v1/components/<slug>.
// Released docs versions map to that SDP release; nightly maps to the Hub's next
// *public* upcoming release. The Hub keeps provisional plans private and only
// exposes an upcoming release once it is deliberately published, so between a
// release shipping and the next one being planned there is legitimately nothing
// to show - that window renders as "not decided yet" rather than a stale or
// guessed list.
//
// The partial is created if it does not exist, not merely rewritten. That is what
// lets the operator repos delete their hand-maintained copies: two places include
// it (an operator's own index.adoc and this repo's platform-wide
// operators:supported_versions.adoc), and both must keep resolving.
//
// Because of that, the extension is load-bearing for the build once the repo
// copies are gone, so it must always leave a usable partial behind. API responses
// are cached in the Antora cache dir; if the Hub is unreachable and there is no
// cache, an existing partial is left alone and a missing one gets a short
// "unavailable" note. It never fails the build and only logs at info level - the
// production playbook fails builds on warnings, and Hub downtime must never break
// a docs build.
//
// Useful links:
// Extensions: https://docs.antora.org/antora/latest/extend/extensions/
// Types of events: https://docs.antora.org/antora/latest/extend/generator-events-reference/
'use strict'

const fs = require('fs')
const ospath = require('path')

const HUB_API = 'https://hub.stackable.tech/api/v1/components'
const PARTIAL = 'supported-versions.adoc'

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

        const body = renderPartial({ components, slug, version, logger })
        if (!body) continue // no data and a repo copy is present: leave it alone

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
function renderPartial ({ components, slug, version, logger }) {
  const header = `// Generated at build time from ${HUB_API}/${slug}.\n` +
    '// Do not edit: the Portal is the source of truth. See lib/hub-supported-versions.js.\n'

  if (!components) {
    // No Hub data at all. An existing partial is better than anything we can say,
    // but a missing one still has to resolve or the include fails the build.
    return `${header}// The Stackable Hub was unreachable during this build.\n` +
      'The supported version list is temporarily unavailable.\n'
  }

  const component = components[slug]
  const target = version === 'nightly' ? nextUpcoming(component) : releaseFor(component, version)

  if (!target || !target.versions || !target.versions.length) {
    if (version === 'nightly') {
      logger.info(`no public upcoming release for ${slug}, rendering the undecided note on nightly`)
      return `${header}// No upcoming SDP release is public yet, so there is nothing to list.\n` +
        'The product versions for the next Stackable Data Platform release have not been decided yet.\n'
    }
    logger.info(`no Hub data for ${slug} in SDP ${version}, keeping the partial from the repo`)
    return undefined
  }

  const lines = target.versions.map((v) => `- ${v.version}${STATUS_SUFFIX[v.status] || ''}`)
  const provisional = version === 'nightly'
    ? `// Provisional: SDP ${target.release || 'next'} has not been released yet.\n` +
      `NOTE: These are the planned product versions for the next release, SDP ${target.release || 'next'}. They may still change.\n\n`
    : ''
  return header + provisional + lines.join('\n') + '\n'
}

function releaseFor (component, version) {
  return (component?.releases || []).find((r) => r.release === version)
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

async function getJson (url) {
  const response = await fetch(url)
  if (!response.ok) throw new Error(`${url} returned ${response.status}`)
  return await response.json()
}
