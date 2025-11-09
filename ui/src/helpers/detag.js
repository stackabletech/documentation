'use strict'

const TAG_ALL_RX = /<[^>]+>/g

module.exports = (html, options) => {
  if (!html) return html
  let result = html.replace(TAG_ALL_RX, '')
  if (options.hash.attribute) {
    result = result.replace(/"/g, '&quot;')
  }
  return result
}
