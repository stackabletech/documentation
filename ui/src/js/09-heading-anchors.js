;(function () {
  'use strict'

  // Asciidoctor emits section anchors as an empty <a class="anchor"> inside the
  // heading, so they are links with no accessible name.
  // The glyph comes from CSS, so there is no text to find: name them after the heading they link to.
  var anchors = document.querySelectorAll('.doc a.anchor')
  Array.prototype.forEach.call(anchors, function (anchor) {
    if (anchor.getAttribute('aria-label')) return
    var heading = anchor.parentNode
    if (!heading) return
    var text = heading.textContent.trim()
    if (text) anchor.setAttribute('aria-label', 'Link to ' + text)
  })
})()
