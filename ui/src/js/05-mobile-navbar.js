;(function () {
  'use strict'

  var navbarBurger = document.querySelector('.navbar-burger')
  if (!navbarBurger) return
  navbarBurger.addEventListener('click', toggleNavbarMenu.bind(navbarBurger))

  function toggleNavbarMenu (e) {
    e.stopPropagation() // trap event
    document.documentElement.classList.toggle('is-clipped--navbar')
    this.classList.toggle('is-active')
    var menu = document.getElementById(this.dataset.target)
    menu.classList.toggle('is-active')
  }
})()

;(function () {
  'use strict'

  var versionButton = document.querySelector('.version-button')
  if (!versionButton) return
  versionButton.addEventListener('click', toggleVersionDropdown.bind(versionButton))

  function toggleVersionDropdown (e) {
    e.stopPropagation() // trap event
    var menu = document.getElementById(this.dataset.target)
    menu.classList.toggle('is-active')
  }
})()
