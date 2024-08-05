; (function () {
  'use strict'

  function openSearchPopover () {
    document.getElementById('search-background').style.display = 'block'
    document.getElementById('search').style.display = 'block'
    var searchInput = document.querySelector('.pagefind-modular-input')
    if (!searchInput) return
    searchInput.focus()
  }

  // open the popover when clicking the magnifying glass search icon
  var searchButton = document.getElementById('search-button')
  if (!searchButton) return
  searchButton.addEventListener('click', function (event) {
    event.stopPropagation()
    openSearchPopover()
  })

  // open the popover with ctrl+k
  document.addEventListener('keydown', function (event) {
    if (event.ctrlKey && event.key === 'k') {
      event.preventDefault() // prevent focussing the URL bar in the browser
      openSearchPopover()
    }
  })

  // close functionality when clicking the background
  var searchBackground = document.getElementById('search-background')
  if (!searchBackground) return
  searchBackground.addEventListener('click', function (e) {
    e.stopPropagation() // trap event
    document.getElementById('search-background').style.display = 'none'
    document.getElementById('search').style.display = 'none'
  })
})()
