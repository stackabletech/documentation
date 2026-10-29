// Lists only pages that are their own canonical: all of stable, plus older pages
// that no release since still has. Every sitemap URL is a suggested canonical,
// and Google asks that a sitemap not contradict rel=canonical:
// https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls
// Prereleases stay out.
//
// Reads pub.canonicalUrl, which Antora only sets while composing pages, so this
// must run at mapSite or later.
module.exports.register = function () {
  this.once('contextStarted', () => {
    const { mapSite } = this.getFunctions()
    this.replaceFunctions({
      mapSite (playbook, pages) {
        const siteUrl = (playbook.site.url || '').replace(/\/$/, '')
        const { contentCatalog } = this.getVariables()
        return mapSite(playbook, pages.filter((page) => isOwnCanonical(page, siteUrl, contentCatalog)))
      },
    })
  })
}

function isOwnCanonical (page, siteUrl, contentCatalog) {
  const version = contentCatalog.getComponentVersion(page.src.component, page.src.version)
  if (version && version.prerelease) return false
  const canonical = page.pub.canonicalUrl
  return canonical === undefined || canonical === siteUrl + page.pub.url
}
