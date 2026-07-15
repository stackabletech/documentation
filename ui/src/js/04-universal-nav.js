;(function () {
  'use strict'

  var disclosure = document.querySelector('.universal-nav__disclosure')
  var sheet = document.getElementById('universal-nav-sheet')
  if (!disclosure || !sheet) return

  function setOpen (open) {
    disclosure.setAttribute('aria-expanded', String(open))
    sheet.hidden = !open
    var label = disclosure.querySelector('.universal-nav__sr')
    if (label) label.textContent = (open ? 'Close' : 'Open') + ' Stackable property switcher'
  }

  disclosure.addEventListener('click', function (e) {
    e.stopPropagation()
    setOpen(sheet.hidden)
  })

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !sheet.hidden) setOpen(false)
  })

  document.addEventListener('click', function (e) {
    if (!sheet.hidden && !sheet.contains(e.target) && !disclosure.contains(e.target)) setOpen(false)
  })
})()
