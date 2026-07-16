// Keeps the "Supported versions" lists on released docs versions in sync with
// the Stackable Hub (whose data comes from the Portal, the source of truth for
// what a release ships).
//
// At build time, the supported-versions.adoc partial of every product operator
// module is regenerated from https://hub.stackable.tech/api/v1/components/<slug>
// - but only for release versions of the docs. The nightly version keeps the
// hand-maintained partial from the operator repo, because the Hub only knows
// released data.
//
// API responses are cached in the Antora cache dir. When the Hub is not
// reachable and no cache exists, the partial is left untouched. This extension
// never fails the build and only logs at info level - the production playbook
// fails builds on warnings, and Hub downtime must never break a docs build.
//
// Useful links:
// Extensions: https://docs.antora.org/antora/latest/extend/extensions/
// Types of events: https://docs.antora.org/antora/latest/extend/generator-events-reference/
'use strict'

const fs = require('fs')
const ospath = require('path')

const HUB_API = 'https://hub.stackable.tech/api/v1/components'

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
}

module.exports.register = function () {
  const logger = this.getLogger('hub-supported-versions')

  this.once('contentAggregated', async ({ playbook, contentAggregate }) => {
    const cacheDir = ospath.join(playbook.dir || '.', playbook.runtime.cacheDir || './cache', 'hub')
    const components = await fetchComponents(cacheDir, logger)
    if (!components) return

    let regenerated = 0
    for (const bucket of contentAggregate) {
      // Only the 'home' component carries operator docs; nightly (main) keeps
      // the partial from the repo since the Hub has no data for unreleased state.
      if (bucket.name !== 'home' || bucket.version === 'nightly') continue
      for (const file of bucket.files) {
        const match = file.path.match(/^modules\/([^/]+)\/partials\/supported-versions\.adoc$/)
        if (!match) continue
        const slug = MODULE_TO_SLUG[match[1]]
        if (!slug) continue
        const release = (components[slug] || { releases: [] }).releases
          .find((r) => r.release === bucket.version)
        if (!release) {
          logger.info(`no Hub data for ${slug} in SDP ${bucket.version}, keeping the partial from the repo`)
          continue
        }
        const lines = release.versions.map((v) => `- ${v.version}${STATUS_SUFFIX[v.status] || ''}`)
        file.contents = Buffer.from(
          `// Regenerated at build time from ${HUB_API}/${slug} (SDP ${bucket.version}).\n` +
          `// The Portal is the source of truth for released product versions.\n` +
          lines.join('\n') + '\n', 'utf8')
        regenerated++
      }
    }
    logger.info(`regenerated ${regenerated} supported-versions partial(s) from the Hub`)
  })
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
      logger.info('no cached Hub data available, supported-versions partials are used as-is')
      return undefined
    }
  }
}

async function getJson (url) {
  const response = await fetch(url)
  if (!response.ok) throw new Error(`${url} returned ${response.status}`)
  return await response.json()
}
