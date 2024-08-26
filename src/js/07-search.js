; (function () {
  'use strict'

  function openSearchPopover () {
    document.getElementById('search-background').style.display = 'block'
    document.getElementById('search').style.display = 'block'
    // focus the textbox after popover appears
    var searchInput = document.querySelector('.pagefind-modular-input')
    if (searchInput) {
      searchInput.focus()
    }
  }

  function closeSearchPopover () {
    document.getElementById('search-background').style.display = 'none'
    document.getElementById('search').style.display = 'none'
  }

  // open the popover when clicking the magnifying glass search icon
  var searchButton = document.getElementById('search-button')
  if (searchButton) {
    searchButton.addEventListener('click', function (event) {
      event.stopPropagation()
      openSearchPopover()
    })
  }

  // close functionality when clicking the background
  var searchBackground = document.getElementById('search-background')
  if (searchBackground) {
    searchBackground.addEventListener('click', function (e) {
      e.stopPropagation() // trap event
      closeSearchPopover()
    })
  }

  // open/close with keyboard
  document.addEventListener('keydown', function (event) {
    if (event.ctrlKey && event.key === 'k') {
      event.preventDefault() // prevent focussing the URL bar in the browser
      openSearchPopover()
    }
    if (event.key === 'Escape') {
      closeSearchPopover()
    }
  })
})()
