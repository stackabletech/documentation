<!--
    DO NOT REMOVE THIS COMMENT. It is intended for people who might copy/paste from the previous release issue.
    This was created by an PR template: https://github.com/stackabletech/documentation/tree/main/.github/PULL_REQUEST_TEMPLATE/release-notes.md.
-->

<!-- Release placeholders YY.M.X should be replaced. -->
# Release Notes for SDP YY.M.X

> [!CAUTION]
> Please assign the applicable `scheduled-for/YY.M.X` label.

> [!TIP]
> - Use the commented out template headings in [release-notes][template].
> - Begin each sentence on a new line. This helps with review suggestions and diffing.
> - Use xrefs for links to other parts of the documentation so that they remain valid across versions.

[template]: https://github.com/stackabletech/documentation/blob/8dc93f28ac6d20a587f54d0a697c71fe47e8643a/modules/ROOT/pages/release-notes.adoc?plain=1#L11-L56

## Release note compilation tasks

- [ ] Check [Issues](https://github.com/search?q=org%3Astackabletech+label%3Arelease-note%2Crelease-note%2Faction-required+label%3Arelease%YY.M.X%2Cscheduled-for%YY.M.X&type=issues) for Product and Platform release notes
- [ ] Check [PRs](https://github.com/search?q=org%3Astackabletech+label%3Arelease-note%2Crelease-note%2Faction-required+label%3Arelease%YY.M.X%2Cscheduled-for%YY.M.X&type=pullrequests) for Product and Platform release notes
- [ ] Optionally check the [Changelogs](https://github.com/search?q=org%3Astackabletech+path%3A*CHANGELOG.md+%22YY.M.X%22&type=code) in case release notes were missed
- [ ] Compile list of new product versions that are supported and compile a list of new product features to include in the Release Highlights
- [ ] Upgrade guide: Document how to use stackablectl to uninstall all and install new release
- [ ] Upgrade guide: Document how to use helm to uninstall all and install new release
- [ ] Upgrade guide: Every breaking change of all our operators
- [ ] Upgrade guide: List removed product versions (if there are any)
- [ ] Upgrade guide: List removed operators (if there are any)
- [ ] Upgrade guide: List supported Kubernetes versions

Each of the following tasks focuses on a specific goal and should be done once the items above have been completed.

## Release note review tasks

- [ ] Check overall document structure
- [ ] Check spelling, grammar, and correct wording
- [ ] Check that internal links are xrefs
- [ ] Check that rendered links are valid
- [ ] Check that each sentence begins on a new line
