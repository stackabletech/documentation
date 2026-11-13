// Converts the HTML Asciidoctor renders for a page body into Markdown.
//
// Asciidoctor lays out admonitions and callout lists as tables, so without the
// rules below they would come out as Markdown tables with an empty icon column.
const domino = require('@mixmark-io/domino')
const TurndownService = require('turndown')
const { tables } = require('@joplin/turndown-plugin-gfm')

const ADMONITION_LABELS = {
  note: 'Note',
  tip: 'Tip',
  important: 'Important',
  warning: 'Warning',
  caution: 'Caution',
}

function hasClass (node, name) {
  return node.nodeType === 1 && (node.getAttribute('class') || '').split(/\s+/).includes(name)
}

// domino, the DOM turndown runs on in Node, returns lists that are not iterable.
function elements (node, tag) {
  return Array.from(node.getElementsByTagName(tag))
}

function quote (text) {
  return text
    .trim()
    .split('\n')
    .map((line) => (line ? `> ${line}` : '>'))
    .join('\n')
}

function fence (text, info = '') {
  const longestRun = Math.max(0, ...(text.match(/`+/g) || []).map((run) => run.length))
  const marker = '`'.repeat(Math.max(3, longestRun + 1))
  return `\n\n${marker}${info}\n${text.replace(/\n$/, '')}\n${marker}\n\n`
}

// Rewrites the DOM before turndown sees it. Links and images become absolute,
// because llms-full.txt has no directory to resolve relative ones from, and a
// link to a page in markdownUrls goes to its Markdown version instead. The
// Mermaid source becomes a pre, the only element whose whitespace turndown
// keeps; its <br>s in node labels arrive as elements and are turned back into text.
function prepare (html, pageUrl, markdownUrls) {
  const document = domino.createDocument(`<!doctype html><html><body>${html}</body></html>`)
  const base = /^https?:/.test(pageUrl || '') ? pageUrl : undefined
  const absolute = (url) => (!base || /^[a-z][a-z0-9+.-]*:/i.test(url) ? url : new URL(url, base).href)
  for (const [tag, attribute] of [['a', 'href'], ['img', 'src']]) {
    for (const node of elements(document.body, tag)) {
      const value = node.getAttribute(attribute)
      if (value) node.setAttribute(attribute, absolute(value))
    }
  }
  for (const node of elements(document.body, 'a')) {
    const [url, fragment] = (node.getAttribute('href') || '').split('#')
    const markdownUrl = markdownUrls.get(url)
    if (markdownUrl) node.setAttribute('href', fragment === undefined ? markdownUrl : `${markdownUrl}#${fragment}`)
  }
  for (const node of elements(document.body, 'div').filter((div) => hasClass(div, 'mermaid'))) {
    for (const br of elements(node, 'br')) br.parentNode.replaceChild(document.createTextNode('<br>'), br)
    const pre = document.createElement('pre')
    pre.setAttribute('class', 'mermaid')
    pre.textContent = node.textContent
    node.parentNode.replaceChild(pre, node)
  }
  return document.body
}

function createConverter (markdownUrls = new Map()) {
  const turndown = new TurndownService({
    headingStyle: 'atx',
    codeBlockStyle: 'fenced',
    bulletListMarker: '-',
    emDelimiter: '_',
  })
  turndown.use(tables)

  // Section anchors are empty links that only carry a CSS glyph. A rule, not
  // remove(), because turndown consults remove() only after its own link rule.
  turndown.addRule('sectionAnchor', {
    filter: (node) => node.nodeName === 'A' && hasClass(node, 'anchor'),
    replacement: () => '',
  })

  // Asciidoctor marks the language with data-lang; the class turndown reads by
  // default says "language-none" on untagged blocks. Literal blocks are a bare pre.
  turndown.addRule('codeBlock', {
    filter: (node) => node.nodeName === 'PRE',
    replacement: (_content, node) => {
      if (hasClass(node, 'mermaid')) return fence(node.textContent.trim(), 'mermaid')
      const code = node.firstChild && node.firstChild.nodeName === 'CODE' ? node.firstChild : node
      return fence(code.textContent, code.getAttribute('data-lang') || '')
    },
  })

  // A tab set renders as a list of labels followed by the panels, so each panel
  // carries its own label or the alternatives read as consecutive steps.
  turndown.addRule('tabs', {
    filter: (node) => node.nodeName === 'DIV' && hasClass(node, 'tabs'),
    replacement: (_content, node) => {
      const labels = new Map(elements(node, 'li').map((li) => [li.getAttribute('id'), li.textContent.trim()]))
      const panels = elements(node, 'div').filter(
        (div) => hasClass(div, 'tabpanel') && div.parentNode.parentNode === node
      )
      const sections = panels.map((panel) => {
        const label = labels.get(panel.getAttribute('aria-labelledby')) || ''
        return `**Tab: ${label}**\n\n${turndown.turndown(panel.innerHTML)}`
      })
      return `\n\n${sections.join('\n\n')}\n\n`
    },
  })

  turndown.addRule('admonition', {
    filter: (node) => node.nodeName === 'DIV' && hasClass(node, 'admonitionblock'),
    replacement: (_content, node) => {
      const type = Object.keys(ADMONITION_LABELS).find((name) => hasClass(node, name))
      const cell = elements(node, 'td').find((td) => hasClass(td, 'content'))
      const body = cell ? turndown.turndown(cell.innerHTML) : ''
      return `\n\n${quote(`**${ADMONITION_LABELS[type] || 'Note'}:** ${body}`)}\n\n`
    },
  })

  turndown.addRule('calloutList', {
    filter: (node) => node.nodeName === 'DIV' && hasClass(node, 'colist'),
    replacement: (_content, node) => {
      const rows = elements(node, 'tr').map((row) => {
        const [marker, text] = elements(row, 'td')
        return `(${marker.textContent.trim()}) ${turndown.turndown(text.innerHTML).replace(/\n+/g, ' ')}`
      })
      return `\n\n${rows.join('\n')}\n\n`
    },
  })

  turndown.addRule('blockTitle', {
    filter: (node) => node.nodeName === 'DIV' && hasClass(node, 'title'),
    replacement: (content) => `\n\n**${content.trim()}**\n\n`,
  })

  // Paragraphs inside list items leave whitespace-only lines behind.
  return (html, pageUrl) => turndown.turndown(prepare(html, pageUrl, markdownUrls)).replace(/[ \t]+$/gm, '')
}

module.exports = { createConverter }
