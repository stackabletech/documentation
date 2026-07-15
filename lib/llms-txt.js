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

    for (const component of contentCatalog.getComponents()) {
      const version = component.latest
      const pages = contentCatalog
        .findBy({ component: component.name, version: version.version, family: 'page' })
        .filter((page) => page.out)
        .sort((a, b) => a.pub.url.localeCompare(b.pub.url))
      const byModule = new Map()
      for (const page of pages) {
        const module = page.src.module
        if (!byModule.has(module)) byModule.set(module, [])
        byModule.get(module).push(page)
      }
      for (const [module, modulePages] of byModule) {
        lines.push('', `## ${component.title}: ${module === 'ROOT' ? 'general' : module}`, '')
        for (const page of modulePages) {
          const title = (page.asciidoc && page.asciidoc.doctitle ? page.asciidoc.doctitle : page.src.stem)
            .replace(/<[^>]+>/g, '')
          const description = page.asciidoc && page.asciidoc.attributes['description']
          const source = sourceUrl(page.src)
          let entry = `- [${title}](${siteUrl}${page.pub.url})`
          if (description) entry += `: ${description.replace(/\s+/g, ' ').trim()}`
          if (source) entry += ` (source: ${source})`
          lines.push(entry)
        }
      }
    }

    siteCatalog.addFile({
      contents: Buffer.from(lines.join('\n') + '\n', 'utf8'),
      out: { path: 'llms.txt' },
    })
  })
}

function sourceUrl (src) {
  const origin = src.origin
  if (!origin || !origin.url || !origin.url.startsWith('https://github.com/')) return undefined
  const repo = origin.url.replace(/\.git$/, '')
  const start = origin.startPath ? `${origin.startPath}/` : ''
  return `${repo}/blob/${origin.refname}/${start}${src.path}`
}
