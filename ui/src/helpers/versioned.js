// A helper to generate the correct link stub from the current page.
// if we're already in the same component, generate a link that links to the same version too.
// targetComponentName: string - name of the component where to link to
// pageInfo: Object - the 'page' template object: https://docs.antora.org/antora-ui-default/templates
// path: string - the rest of the link path, inside the target component
module.exports = (targetComponentName, pageInfo, path) => {
  // if either the current page is not part of the component or of a different component
  // or of the same component with the latest version, link to the component and to 'stable',
  // the latest version
  if ((pageInfo.component === undefined) ||
      (targetComponentName !== pageInfo.component.name) ||
      (pageInfo.version === pageInfo.component.latest.version)) {
    return '/' + targetComponentName + '/stable/' + path
  // otherwise, link to the current version.
  } else {
    return '/' + targetComponentName + '/' + pageInfo.version + '/' + path
  }
}
