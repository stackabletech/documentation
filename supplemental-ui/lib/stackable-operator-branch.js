// This is so we can map `nightly` (from the release dropdown) to the `main`
// branch, and `YY.M` -> `release-YY.M`.
//
// In adocs, you can access it via {stackable-operator-branch}.
//
// Useful links:
// Extensions: https://docs.antora.org/antora/latest/extend/extensions/
// Types of events: https://docs.antora.org/antora/latest/extend/generator-events-reference/
module.exports.register = function () {
  this.once('contentClassified', ({ playbook, contentCatalog }) => {
    contentCatalog.getComponents().forEach((component) => {
      component.versions.forEach((componentVersion) => {
        const operatorBranch = componentVersion.version === 'nightly'
          ? 'main'
          : `release-${componentVersion.version}`

        // Not sure why we need a new object, but _they_ do it.
        // See: https://github.com/couchbase/docs-site/blob/b7db9602fc035945ace72e3152e9fb83ef7cba51/lib/antora-component-version-rank.js
        componentVersion.asciidoc = {
          ...componentVersion.asciidoc,
          attributes: {
            ...componentVersion.asciidoc.attributes,
            'stackable-operator-branch': operatorBranch
          }
        }
      })
    })
  })
}
