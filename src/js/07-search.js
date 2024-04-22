; (function () {
  'use strict'

  var searchButton = document.getElementById('search-button')
  if (!searchButton) return
  searchButton.addEventListener('click', toggleNavbarMenu.bind(searchButton))

  function toggleNavbarMenu (e) {
    e.stopPropagation() // trap event
    document.getElementById('search-background').style.display = 'block'
    document.getElementById('search').style.display = 'block'
    var searchInput = document.querySelector('.pagefind-ui__search-input')
    if (!searchInput) return
    searchInput.focus()
  }
})()

; (function () {
  'use strict'

  var searchBackground = document.getElementById('search-background')
  if (!searchBackground) return
  searchBackground.addEventListener('click', toggleNavbarMenu.bind(searchBackground))

  function toggleNavbarMenu (e) {
    e.stopPropagation() // trap event
    document.getElementById('search-background').style.display = 'none'
    document.getElementById('search').style.display = 'none'
  }
})()
