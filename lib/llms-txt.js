// Generates /llms.txt following https://llmstxt.org/ so that AI agents can
// discover the documentation without scraping HTML, plus a Markdown copy of
// every indexed page next to its HTML (index.md beside index.html, as the spec
// proposes) and /llms-full.txt, all of those pages in one file. llms-full.txt
// is a widespread convention rather than part of the spec.
// It was cheap to include here.
//
// For every component, only the version that 'stable' points to is indexed
// (the latest release, or nightly when building without release branches).
// Each entry has the Markdown page URL, the page description and a link
// to the AsciiDoc source on GitHub, so agents can both read a page and find
// the file to change.
//
// A page with the attribute `:page-llms-ignore:` is left out of all of it.
//
// Useful links:
// Extensions: https://docs.antora.org/antora/latest/extend/extensions/
// Types of events: https://docs.antora.org/antora/latest/extend/generator-events-reference/
const { createConverter } = require('./html-to-markdown')

// Pages on how Stackable builds SDP go under "Optional", the llms.txt convention
// for links an agent can skip when context is short (https://llmstxt.org/).
// They are left out of llms-full.txt for the same reason.
const OPTIONAL_MODULES = new Set(['contributor', 'internal'])

// This is the entry point to the entire plugin.
// Antora works in "phases" and here we hook into them.
module.exports.register = function () {
  const markdown = new Map()

  // The first phase we hook into is "documentsConverted" where Asciidoctor has
  // turned every page into HTML.
  // Page contents are only the article HTML at this point. Later in the build
  // Antora wraps each page in the site layout, header and navigation included.
  // (That phase is called "pagesComposed")
  // And because we don't need all that ceremony we convert every HTML
  // page to Markdown right here
  this.once('documentsConverted', ({ playbook, contentCatalog }) => {
    const siteUrl = (playbook.site.url || '').replace(/\/$/, '')
    const pages = indexedPages(contentCatalog)
    const convert = createConverter(new Map(pages.map((page) => [`${siteUrl}${page.pub.url}`, markdownUrl(page, siteUrl)])))
    for (const page of pages) {
      markdown.set(page, convert(page.contents.toString(), `${siteUrl}${page.pub.url}`))
      // The UI reads this as page.attributes.markdown-url to link the Markdown version in the page head.
      page.asciidoc.attributes['page-markdown-url'] = markdownUrl(page, siteUrl)
    }
  })

  // This is the second phase we hook into. The site is finished at this point and
  // Antora is about to write the actual files to disk and we add our own files.
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
      'Every entry below links the page as Markdown and, in parentheses, its AsciiDoc',
      'source on GitHub. To suggest a change to a page, edit that source file.',
      `All pages outside "Optional" are also available in one file: ${siteUrl}/llms-full.txt`,
    ]
    const optional = []
    const full = []

    // Here we iterate over every page of every component and add the markdown versions to the
    // "siteCatalog" using their markdown path. So that's where Antora is going to publish them.
    // We separate here between "optional" modules and non-optional ones.
    // Every page gets its Markdown file (optional and non-optional).
    // Pages from optional modules are listed under "Optional" at the end of llms.txt and left
    // out of llms-full.txt. All others are listed per module and included in llms-full.txt.
    for (const component of contentCatalog.getComponents()) {
      const byModule = new Map()
      for (const page of indexedPages(contentCatalog, component)) {
        const body = markdown.get(page)
        siteCatalog.addFile({ contents: Buffer.from(markdownPage(page, body), 'utf8'), out: { path: markdownPath(page) } })
        const module = page.src.module
        if (OPTIONAL_MODULES.has(module)) {
          optional.push(page)
          continue
        }
        full.push(markdownPage(page, body, `${siteUrl}${page.pub.url}`))
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

    siteCatalog.addFile({ contents: Buffer.from(lines.join('\n') + '\n', 'utf8'), out: { path: 'llms.txt' } })
    siteCatalog.addFile({ contents: Buffer.from(full.join('\n\n'), 'utf8'), out: { path: 'llms-full.txt' } })
  })
}

// Sorted by the site navigation, which is the reading order we consciously chose.
// This means that the markdown pages will also appear in "our" order in llms.txt later.
// Pages that are not in the navigation come after it, sorted by URL.
// The navigation only exists from navigationBuilt (another phase) on,
// so earlier callers (like our "documentsConverted" call above) get URL order,
// but for that call it doesn't matter because it only needs a full table of all pages
// to convert them to markdown.
function indexedPages (contentCatalog, component) {
  const components = component ? [component] : contentCatalog.getComponents()
  return components.flatMap((it) => {
    const rank = navigationRank(it.latest.navigation || [])
    const position = (page) => (rank.has(page.pub.url) ? rank.get(page.pub.url) : Infinity)

    // Here we find all pages, then remove all those with a page-llms-ignore attribute
    // and compare the rest by their "position" (see above) or URL as fallback.
    return contentCatalog
      .findBy({ component: it.name, version: it.latest.version, family: 'page' })
      .filter((page) => page.out && !('page-llms-ignore' in page.asciidoc.attributes))
      .sort((a, b) => {
        if (position(a) !== position(b)) return position(a) - position(b)
        return a.pub.url.localeCompare(b.pub.url)
      })
  })
}

// This builds an "order" of all pages by walking the entire tree of our pages.
// As if you opened every section/subsection and noted down every page
// along the way.
function navigationRank (navigation) {
  const rank = new Map()
  const visit = (items) => {
    for (const item of items) {
      const url = item.urlType === 'internal' && item.url.split('#')[0]
      if (url && !rank.has(url)) rank.set(url, rank.size)
      visit(item.items || [])
    }
  }
  visit(navigation)
  return rank
}

function markdownPath (page) {
  return page.out.path.replace(/\.html$/, '.md')
}

function markdownUrl (page, siteUrl) {
  return `${siteUrl}/${markdownPath(page)}`
}

function titleOf (page) {
  return decodeEntities(
    (page.asciidoc.doctitle ? page.asciidoc.doctitle : page.src.stem).replace(/<[^>]+>/g, '')
  )
}

function descriptionOf (page) {
  const description = page.asciidoc.attributes['description']
  return description ? decodeEntities(description.replace(/\s+/g, ' ').trim()) : undefined
}

function markdownPage (page, body, htmlUrl) {
  const head = [`# ${titleOf(page)}`]
  if (htmlUrl) head.push(`URL: ${htmlUrl}`)
  const description = descriptionOf(page)
  if (description) head.push(`> ${description}`)
  return `${head.join('\n\n')}\n\n${body}\n`
}

function entryFor (page, siteUrl) {
  const url = markdownUrl(page, siteUrl)
  const description = descriptionOf(page)
  const source = sourceUrl(page.src)
  let entry = `- [${titleOf(page)}](${url})`
  if (description) entry += `: ${description}`
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
