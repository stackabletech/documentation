// This is so we can map `nightly` (from the release dropdown) to the `main`
// branch and 0.0.0-dev version, and `YY.M` to the `release-YY.M` branch and
// YY.M.0 version.
//
// In adocs, you can access it via {stackable-operator-branch} and {stackable-operator-version}.
//
// Useful links:
// Extensions: https://docs.antora.org/antora/latest/extend/extensions/
// Types of events: https://docs.antora.org/antora/latest/extend/generator-events-reference/
module.exports.register = function () {
  this.once('contentClassified', ({ playbook, contentCatalog }) => {
    contentCatalog.getComponents().forEach((component) => {
      component.versions.forEach((componentVersion) => {
        const operatorInfo = componentVersion.version === 'nightly'
          ? { branch: 'main', version: '0.0.0-dev' }
          // TODO: Be clever about the patch level (eg: pull from the release repo: https://github.com/stackabletech/release/blob/main/releases.yaml)
          : { branch: `release-${componentVersion.version}`, version: `${componentVersion.version}.0` }

        // Not sure why we need a new object, but _they_ do it.
        // See: https://github.com/couchbase/docs-site/blob/b7db9602fc035945ace72e3152e9fb83ef7cba51/lib/antora-component-version-rank.js
        componentVersion.asciidoc = {
          ...componentVersion.asciidoc,
          attributes: {
            ...componentVersion.asciidoc.attributes,
            'stackable-operator-branch': operatorInfo.branch,
            'stackable-operator-version': operatorInfo.version,
          }
        }
      })
    })
  })
}
