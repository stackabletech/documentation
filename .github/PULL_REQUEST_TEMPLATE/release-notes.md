---
name: Release Notes
about: This template can be used to track the progress of the SDP Release Notes compilation
title: "chore(tracking): Release Notes for SDP YY.(M)M.X"
assignees: ''
---

<!--
    DO NOT REMOVE THIS COMMENT. It is intended for people who might copy/paste from the previous release issue.
    This was created by an issue template: https://github.com/stackabletech/issues/issues/new/choose.
-->

## Release Notes for SDP XX.(X)X

> [!TIP]
> - Use the commented out template headings in [release-notes][template].
> - Begin each sentence on a new line. This helps with review suggestions and diffing.
> - Use xrefs for links to other parts of the documentation so that they remain valid across versions.

[template]: https://github.com/stackabletech/documentation/blob/8dc93f28ac6d20a587f54d0a697c71fe47e8643a/modules/ROOT/pages/release-notes.adoc?plain=1#L11-L56

```[tasklist]
#### Release note compilation tasks
- [ ] Check [Issues](https://github.com/search?q=org%3Astackabletech+label%3Arelease-note%2Crelease-note%2Faction-required+label%3Arelease%2FYYYY-MM%2Cscheduled-for%2FYYYY-MM&type=issues&ref=advsearch) for Product and Platform release notes
- [ ] Check [PRs](https://github.com/search?q=org%3Astackabletech+label%3Arelease-note%2Crelease-note%2Faction-required+label%3Arelease%2FYYYY-MM%2Cscheduled-for%2FYYYY-MM&type=pullrequests&ref=advsearch) for Product and Platform release notes
- [ ] Optionally check the [Changelogs](https://github.com/search?q=org%3Astackabletech+path%3A*CHANGELOG.md+%22YY.MM.X%22&type=code&ref=advsearch) in case release notes were missed
- [ ] Compile list of new product versions that are supported and compile a list of new product features to include in the Release Highlights
- [ ] Upgrade guide: Document how to use stackablectl to uninstall all and install new release
- [ ] Upgrade guide: Document how to use helm to uninstall all and install new release
- [ ] Upgrade guide: Every breaking change of all our operators
- [ ] Upgrade guide: List removed product versions (if there are any)
- [ ] Upgrade guide: List removed operators (if there are any)
- [ ] Upgrade guide: List supported Kubernetes versions
```

Once the above items are complete, the following checks need to be done
Each task focuses on a specific element

```[tasklist]
#### Release note review tasks
- [ ] Check overall document structure
- [ ] Check spelling, grammar, and correct wording
- [ ] Check that internal links are xrefs
- [ ] Check that rendered links are valid
- [ ] Check that each sentence begins on a new line
```
