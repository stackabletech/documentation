// Generates /llms.txt following https://llmstxt.org/ so that AI agents can
// discover the documentation without scraping HTML.
//
// For every component, only the version that 'stable' points to is indexed
// (the latest release, or nightly when building without release branches).
// Each entry carries the published page URL, the page description and a link
// to the AsciiDoc source on GitHub, so agents can both read a page and find
// the file to change.
//
// Useful links:
// Extensions: https://docs.antora.org/antora/latest/extend/extensions/
// Types of events: https://docs.antora.org/antora/latest/extend/generator-events-reference/

// Pages on how Stackable builds SDP go under "Optional", the llms.txt convention
// for links an agent can skip when context is short (https://llmstxt.org/).
const OPTIONAL_MODULES = new Set(['contributor', 'internal'])

module.exports.register = function () {
  this.once('beforePublish', ({ playbook, contentCatalog, siteCatalog }) => {
    const siteUrl = (playbook.site.url || '').replace(/\/$/, '')
    const lines = [
      '# Stackable Data Platform Documentation',
      '',
      '> Documentation for the Stackable Data Platform (SDP), a curated selection of',
      '> open source data apps like Apache Kafka, Apache Druid, Apache Trino and',
      '> Apache Spark, all working together seamlessly on Kubernetes.',
      '',
      'Machine-readable release, component and CRD data is available from the',
      'Stackable Hub: https://hub.stackable.tech/llms.txt',
      '',
      'Every entry below links the published page and, in parentheses, its AsciiDoc',
      'source on GitHub. To suggest a change to a page, edit that source file.',
    ]
    const optional = []

    for (const component of contentCatalog.getComponents()) {
      const version = component.latest
      const pages = contentCatalog
        .findBy({ component: component.name, version: version.version, family: 'page' })
        .filter((page) => page.out)
        .sort((a, b) => a.pub.url.localeCompare(b.pub.url))
      const byModule = new Map()
      for (const page of pages) {
        const module = page.src.module
        if (OPTIONAL_MODULES.has(module)) {
          optional.push(page)
          continue
        }
        if (!byModule.has(module)) byModule.set(module, [])
        byModule.get(module).push(page)
      }
      for (const [module, modulePages] of byModule) {
        lines.push('', `## ${component.title}: ${module === 'ROOT' ? 'general' : module}`, '')
        for (const page of modulePages) lines.push(entryFor(page, siteUrl))
      }
    }

    if (optional.length) {
      lines.push('', '## Optional', '')
      for (const page of optional) lines.push(entryFor(page, siteUrl))
    }

    siteCatalog.addFile({
      contents: Buffer.from(lines.join('\n') + '\n', 'utf8'),
      out: { path: 'llms.txt' },
    })
  })
}

function entryFor (page, siteUrl) {
  const title = decodeEntities(
    (page.asciidoc && page.asciidoc.doctitle ? page.asciidoc.doctitle : page.src.stem).replace(/<[^>]+>/g, '')
  )
  const description = page.asciidoc && page.asciidoc.attributes['description']
  const source = sourceUrl(page.src)
  let entry = `- [${title}](${siteUrl}${page.pub.url})`
  if (description) entry += `: ${decodeEntities(description.replace(/\s+/g, ' ').trim())}`
  if (source) entry += ` (source: ${source})`
  return entry
}

// Asciidoctor escapes the doctitle and header attributes such as description for
// HTML, so "&" arrives as "&amp;" and "'" as "&#8217;".
// Decode in a single pass so "&amp;lt;" stays the literal text "&lt;".
const NAMED_ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" }

function decodeEntities (text) {
  return text.replace(/&(?:#(\d+)|#x([0-9a-f]+)|(amp|lt|gt|quot|apos));/gi, (match, dec, hex, name) => {
    if (dec) return String.fromCodePoint(Number(dec))
    if (hex) return String.fromCodePoint(parseInt(hex, 16))
    return NAMED_ENTITIES[name.toLowerCase()]
  })
}

function sourceUrl (src) {
  const origin = src.origin
  if (!origin || !origin.url || !origin.url.startsWith('https://github.com/')) return undefined
  const repo = origin.url.replace(/\.git$/, '')
  const start = origin.startPath ? `${origin.startPath}/` : ''
  return `${repo}/blob/${origin.refname}/${start}${src.path}`
}
