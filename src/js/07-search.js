; (function () {
  'use strict'

  function openSearchPopover () {
    document.getElementById('search-background').style.display = 'block'
    document.getElementById('search').style.display = 'block'

    // focus the textbox after popover appears
    focusSearchInput()
    // add eventlisteners after popover appears
    addNavigationToSearch()
  }

  function closeSearchPopover () {
    document.getElementById('search-background').style.display = 'none'
    document.getElementById('search').style.display = 'none'
  }

  function focusSearchInput () {
    var searchInput = document.querySelector('.pagefind-modular-input')
    if (searchInput) {
      searchInput.focus()
    }
  }

  function addNavigationToSearch () {
    // focus the first search result when pressing enter in search input
    document.getElementById('pfmod-input-0').addEventListener('keydown', goToSearchResultsOnEnter)
  }

  function goToSearchResultsOnEnter (event) {
    var searchResults = document.getElementById('search-results')
    if (event.key === 'Enter' && searchResults.childElementCount > 0) {
      searchResults.firstChild.querySelector('a').focus()
      searchResults.addEventListener('keydown', addNavigationInSearchResults)
    }
  }

  function addNavigationInSearchResults (event) {
    if (event.key === 'ArrowDown' && document.activeElement.classList.contains('pagefind-modular-list-link')) {
      event.preventDefault() // prevent page scrolling
      var nextSibling = document.activeElement.parentElement.parentElement.parentElement.nextElementSibling
      if (nextSibling) {
        nextSibling.querySelector('a').focus()
      }
    }

    if (event.key === 'ArrowUp' && document.activeElement.classList.contains('pagefind-modular-list-link')) {
      event.preventDefault() // prevent page scrolling
      var previousSibling = document.activeElement.parentElement.parentElement.parentElement.previousElementSibling
      if (previousSibling) {
        previousSibling.querySelector('a').focus()
      }
    }
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
    searchBackground.addEventListener('click', function (event) {
      event.stopPropagation() // trap event
      closeSearchPopover()
    })
  }

  document.addEventListener('keydown', function (event) {
    // open search with keyboard
    if (event.ctrlKey && event.key === 'k') {
      event.preventDefault() // prevent focussing the URL bar in the browser
      openSearchPopover()
    }
    // close search with keyboard
    if (event.key === 'Escape') {
      closeSearchPopover()
    }
    // focus the search input when pressing / while search popover is open
    if (event.key === '/') {
      event.preventDefault() // prevent opening the browser search dialog
      focusSearchInput()
    }
  })
})()
