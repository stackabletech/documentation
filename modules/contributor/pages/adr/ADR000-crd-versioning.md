The following is an initial (and still rough) draft of the CRD versioning ADR.
It was written in Markdown using a HedgeDoc pad.
This pad can be used for further collaboration if needed.
The ADR will be converted into Asciidoc at the end (sad noises).

# ADR000: CRD Versioning

## Video notes

{%youtube niamejFf5Zk %}

- Alpha versions are considered "free for all"
  - This means introducing breaking changes is possible
  - No stability guarantees for users
  - There is no need for automatic conversion using a webhook between alpha versions
- Beta versions can also be breaking, but try to avoid them
  - Instead, provide instructions on how to upgrade CRDs
  - Automatic conversion from alpha to beta recommended
- Stable versions, basically no changes, stable
  - Automatic conversion from beta to stable recommended
- Staying on alpha has its pros and cons:
  - Pros:
    - no extra code
    - no need to bump
    - good for bug fixes
  - Cons:
    - Not future-proof
    - Can turn away enterprise users
- Using conversion webhook has its pros and cons:
  - Pros:
    - It is live (on-the-fly) and the only K8s-native solution (compared to scripts are other mechanisms)
    - One source of truth, the operator only uses the latest supported version
    - Is integrated into code base
  - Cons:
    - Certificates for the webhook are hard to manage / set up
    - Cluster networking becomes part of the design on how webhooks are deployed
- The webhook definition is part of the CRD, but the webhook deployment is highly context specific. This makes design of the conversion mechanism very hard.
- Try to do as few breaking changes as possible. Try to design the CRD well right from the start. Introduce as many breaking changes as fast as possible to avoid handling versioning. (This recommendation is also mentioned further below in this ADR).

---

{%youtube vZkl9KocroY %}

- TODO: Mention what storage and server fields mean
  - What is stored, when can we switch what is stored
  - What is being served
  - What can be deprecated and/or removed
  - Clients (like `kubectl`) always use the latest version by default
- TODO: Research Storage Version Migrator
  - <https://github.com/kubernetes-sigs/kube-storage-version-migrator>
  - Do we want to implement something custom in Rust instead?
- Lifecycle of CRD looks like:
  1. Introduce a new version while the old versions remains the stored version
  2. Mark the new version as stored=true, mark the old version as deprecated
  3. Remove the deprecation of the old version, mark it as served=false
  4. (Optional) Afterwards, remove the version from the CRD itself, drop support for conversion in the webhook
  - Upstream support for `#[kube(deprecated [= "reason"])]`. See: <https://github.com/kube-rs/kube/pull/1697>
  - Idea: Can we codify this lifecycle? We could add support to specify a date when a version is introduced. This could then be used to automatically set deprecations and served properties. This however has the drawback that CRDs can randomly change on an otherwise unrelated PR. On the other hand, a codified approach could remove the need to manually track CRD lifecycles. It could potentially be used to auto-generate docs which display the lifecycle.

---

{%youtube Xg0NWtSgmUE %}

- No notes yet

---

Our operators use CustomResourceDefinitions to define CustomResources available on a Kubernetes cluster. These definitions can be versioned. General concepts of the versioning mechanism is documented in the official Kubernetes [documentation][k8s-crd-versioning-docs]. The following section summarizes the official documentation while also adding additional details when needed.

Every time changes need to be done to a CRD, its version needs to be adjusted depending on the stability level it is at. There are currently three stability levels: Alpha, Beta, and Stable. Kubernetes API versions use the following well-defined format: `v<MAJOR>(alpha<LEVEL|beta<LEVEL>)`. Stable versions (eg. `v1`) can easily be spotted as they lack *any* level suffix. There are the following types of changes we need to consider:

- Adding a new field
- Renaming a field
- Changing the type of a field
- Deprecating a field (Removing a field)

The official documentation currently lacks any recommendations regarding which type of changes require which version bump. It is however possible to use the API versioning [reference][api-versioning] as well as other sources like blogs, articles and guides as inspiration to define our own rules and how these rules and behaviours can be best be expressed using Rust. Each section will detail how the Rust code and resulting schema will look like. Sections start with a brief explanation for which use-cases the approach can be used via a blockquote.

## Change: Adding a new field

The newly added field can either be required or optional. These two options can be expressed in three different ways using Rust. The following sections describe the behaviour when the resource is applied using the **new** version of the definition. Using an older version *can* be handled by conversion mechanisms.

### Required struct field

> [!TIP]
> This approach can be used to introduce fields which are strictly required (eg. by the operator or the product the operator manages) and there is **no** obvious default value to use because it is highly dependant on the context it is running in.

```rust
struct MyResource {
    foo: usize,

    // This field is newly introduced.
    bar: String,
}
```

In this case, the new version of CRD **requires** this field to be set for every MyResource resource. It is not optional, so cannot be set to null or left out, and there is no default value if not set. This change is breaking and thus requires a version bump.

```yaml
# ...
spec:
  foo: 42
  bar: "hello, world" # Now required
```

### Optional struct field

> [!TIP]
> This approach can be used for fields which opt into optional (experimental) features but still providing the ability to customize using the field. Using `Option<T>` will push the responsibility of dealing with `None` (eg. using a default fallback value) to the operator.

**TODO:** Can we detect the addition of an optional field and thus enable not needing to bump / introduce a new version? We *can* somehow reliable detect `Option`, but it is not guaranteed to be the `Option` (from the standard library) we expect.

```rust
struct MyResource {
    foo: usize,

    // This field is newly introduced.
    bar: Option<String>,
}
```

In this case, the new version of the CRD allows to **optionally** set this field. This field is now nullable, meaning the default value when unset is `None`. This enables the following three options to define the CustomResource:

```yaml
# ...
spec:
  foo: 42
  bar: "hello, world" # Setting an optional value
```

```yaml
# ...
spec:
  foo: 42
  bar: null # Explicitly setting the field to null
```

```yaml
# ...
spec:
  foo: 42
          # Not setting the field at all
```

### Optional Serde field

> [!TIP]
> This approach is useful for required features for which a default config value can be used. This is only the case when the value of the config field is **not** highly dependend on the context the operator runs in. An example of such a field might be a *timeout duration*.

```rust
struct MyResource {
    foo: usize,

    // This field is newly introduced.
    #[serde(default = default_bar)]
    bar: String,
}

fn default_bar() -> String {
    String::from("hello, world")
}
```

In this case, the new version of the CRD allows to **optionally** set this field. This field is now nullable, meaning the default value is set during deserialization by Serde (using the default function `default_bar`). This enables the same three options to define the resource as above.

The only difference is how the CRD is structured in code. The field `bar` will always have a value (no `None`). The operator can always use this value as is without implementing its own fallback value / logic.

---

Each of the three options above can be used based on the behaviour the operator wants to achieve. The `stackable-versioned` crate can handle all solutions like this:

```rust
#[versioned(
    version(name = "v1alpha1"),
    version(name = "v1alpha2")
)]
struct Foo {
    bar: bool,

    // In this case, the field is required to set when the
    // CustomResource is submitted using v1alpha2. When
    // submitting the resource using v1alpha1, automatic
    // conversion can be done which will use a default value.
    // By default, `Default::default()` is used, resulting in
    // a value of `0` in this case. The function used can
    // however be customized.
    #[versioned(added(since = "v1alpha2"))]
    baz: usize,
}
```

<!-- TODO: Add summary of the section clearly stating the way to handle this situation -->

## Change: Renaming a field

A renamed field can **always** be modelled as a non-breaking change which is also backwards compatible, meaning that a newer version of a field can be converted back to an older version.

> [!TIP]
> This type of change is useful when a field is renamed to better indicate the use of said field. A simple example might be renaming `key` to `sshKey` to more clearly indicate for what the field is used.

> [!WARNING]
> Care should be taken, when the name of the field also changes the type it expects. This is not a simple rename anymore, but also changes the type of the field in addition to the name. One such example might be renaming `durationSeconds` to `duration` and changing the type from a `u64` to `Duration`. This type of change is discussed in the next section.

```rust
#[versioned(
    version(name = "v1alpha1"),
    version(name = "v1alpha2")
)]
struct Foo {
    #[versioned(changed(since = "v1alpha2", from_name = "bar"))]
    baz: usize,
}
```

In this example, the field `bar` of the struct is renamed to `baz` since version `v1alpha2`. Its type **does not** change and as such can be considered a non-breaking change if automatic conversion (via a webhook for example) is applied. The `changed` action is detailed [here][versioned-changed-action].

<details>
<summary>Expanded code</summary>

```rust
#[automatically_derived]
mod v1alpha1 {
    use super::*;
    pub struct Foo {
        pub bar: usize,
    }
}
#[automatically_derived]
impl ::std::convert::Fromv1alpha1::Foo for v1alpha2::Foo {
    fn from(__sv_foo: v1alpha1::Foo) -> Self {
        Self {
            // The into call is strictly speaking not needed,
            // but we need to include it generally to support
            // cases where the type of the field changes. This
            // is due to the fact that macros don't have access
            // to any type information and as such we cannot
            // reason about the type of the field bar and baz.
            baz: __sv_foo.bar.into(),
        }
    }
}
#[automatically_derived]
mod v1alpha2 {
    use super::*;
    pub struct Foo {
        pub baz: usize,
    }
}
```

For simple cases, the automatically generated `From` implementation for conversion between versions can be used. This is especially true for these type of changes: renames of fields. Currently, only **up**grades of versions are supported with the automatic conversions, meaning that there will be a `From` implementation which converts from `v1alpha1` to `v1alpha2` but there isn't one for the other way round. This is however on the roadmap and should be supported in the future.

</details>

## Change: Changing the type of a field

A field type change **cannot** always be modelled as non-breaking, for both up and downgrades. However, at least the upgrade path should ideally be performed without being fallible.

> [!TIP]
> This type of change can be used to change the underlying type of a field. One such example might be renaming `durationSeconds` to `duration` and changing the type from a `u64` to `Duration`.

Because renaming a field and changing its type is often done at the same time, this change can also be modelled using a single attribute argument: `changed()`.

```rust
#[versioned(
    version(name = "v1alpha1"),
    version(name = "v1alpha2")
)]
struct Foo {
    // Here, only the type of the field is changed. Its
    // name stays the same across versions.
    #[versioned(changed(since = "v1alpha2", from_type = "u16"))]
    baz: usize,
}
```

<details>
<summary>Expanded code</summary>

```rust
#[automatically_derived]
mod v1alpha1 {
    use super::*;
    pub struct Foo {
        pub baz: u16,
    }
}
#[automatically_derived]
impl ::std::convert::Fromv1alpha1::Foo for v1alpha2::Foo {
    fn from(__sv_foo: v1alpha1::Foo) -> Self {
        Self {
            baz: __sv_foo.baz.into(),
        }
    }
}
#[automatically_derived]
mod v1alpha2 {
    use super::*;
    pub struct Foo {
        pub baz: usize,
    }
}
```

</details>

The following example details both a change in name and type which will likely be the most frequent type of change (especially when stability levels of `alpha1` and `beta` are used).

```rust
#[versioned(
    version(name = "v1alpha1"),
    version(name = "v1alpha2")
)]
struct Foo {
    #[versioned(changed(
        since = "v1alpha2",
        from_type = "u16",
        from_name = "bar"
    ))]
    baz: usize,
}
```

<details>
<summary>Expanded code</summary>

```rust
#[automatically_derived]
mod v1alpha1 {
    use super::*;
    pub struct Foo {
        pub bar: u16,
    }
}
#[automatically_derived]
impl ::std::convert::Fromv1alpha1::Foo for v1alpha2::Foo {
    fn from(__sv_foo: v1alpha1::Foo) -> Self {
        Self {
            baz: __sv_foo.bar.into(),
        }
    }
}
#[automatically_derived]
mod v1alpha2 {
    use super::*;
    pub struct Foo {
        pub baz: usize,
    }
}
```

</details>

The upgrade process can be automatically handled by using a `From` implementation for converting from the old to the new type. The are however instances in which the is no sensible default `From` implementation which then requires a customized conversion (`skip(from)`). One such an example is when changing a field to use `Duration`. The conversion now depends on how the field was previously named / what kind of value it represented:

- A field named `durationHours` with a type of `u64` represents a duration specified in full hours.
- A field named `durationSeconds` with a type of `u64` represents a duration specified in full seconds.

In such a case, there is no implementation in which `From<u64> for Duration` will always produce the expected value, because the code is unaware of the context (the previous name of the field).

## Change: Deprecating a field

A deprecation of a field can always be modelled as a non-breaking change. Deprecated fields are not removed entirely, but instead renamed to `deprecated<FIELD_NAME>`. This technically also enables downgrades, because previously used values can be re-populated/re-hydrated using the deprecated fields. As mentioned above, downgrades are currently not supported by the macro.

> [!TIP]
> This type of change can be used to indicate fields are deprecated and should no longer be used in future versions of the CRD.

```rust
#[versioned(
  version(name = "v1alpha1"),
  version(name = "v1alpha2")
)]
struct Foo {
    #[versioned(deprecated(since = "v1alpha2"))]
    deprecated_baz: usize,
}
```

<details>
<summary>Expanded code</summary>

```rust
#[automatically_derived]
mod v1alpha1 {
    use super::*;
    pub struct Foo {
        pub baz: usize,
    }
}
#[automatically_derived]
#[allow(deprecated)]
impl ::std::convert::Fromv1alpha1::Foo for v1alpha2::Foo {
    fn from(__sv_foo: v1alpha1::Foo) -> Self {
        Self {
            deprecated_baz: __sv_foo.baz.into(),
        }
    }
}
#[automatically_derived]
mod v1alpha2 {
    use super::*;
    pub struct Foo {
        #[deprecated]
        pub deprecated_baz: usize,
    }
}
```

</details>

Complete removal of fields is currently (and deliberately) not supported because CRD versions with removed fields cannot be downgraded again. The deleted field (and as such the value) is not available and thus we cannot re-hydrate the field with the correct previous value.

## Source code style guide

### Referencing versioned items

Use the versioned module name to clearly indicate which version of the CRD or other versioned structs is used. The following two examples depict correct and incorrect code for this rule.

**Correct**

```rust
// Import the versioned module from the CRD module.
// If multiple versions of the CRD are used, import
// additional versions explicitly as well.
use crate::crd::{v1alpha1, v1beta1};

// Importing the versioned module then enables developers
// to clearly indicate which version is used in places like
// function signatures, struct definitions or impl blocks.
fn my_func(crd: v1alpha1::MyCrd) -> &str {
    &crd.metadata.name
}

struct MyWrapper(v1beta1::MyCrd);

impl From<v1alpha1::MyCrd> for MyWrapper {
    fn from(value: v1alpha1::MyCrd) -> MyWrapper {
        MyWrapper(value.into())
    }
}
```

**Incorrect**

```rust
// This produces conflicts, because an item named
// "MyCrd" is imported multiple times (twice in this case).
// This can only be solved by renaming the imported item
// which is NOT recommended.
use crate::crd::{v1alpha1::MyCrd, v1beta1::MyCrd};

// Renaming imports like this is NOT recommended.
use crate::crd::{v1alpha1::MyCrd as MyCrdV1Alpha1, v1beta1::MyCrd as MyCrdV1Beta1};
```

If only a single CRD version is needed, it is still recommended to import the versioned module instead of using the fully-qualified item name like this:

```rust
use crate::crd::v1alpha1::MyCrd;

// This function signature does not clearly indicate on
// which version of "MyCrd" it operates on and as such is
// NOT recommended. This is also true for uses in struct
// definitions and impl blocks.
fn my_func(crd: MyCrd) -> &str {
    &crd.metadata.name
}
```

---

Sometimes, there are multiple CRDs for a single operator. These are usually defined in different submodules in the `crd` module. There are cases, where files need access to two or more of these CRDs, which makes it impossible to import the same version module multiple times. Instead, it is recommended to use the following import style:

**Correct**

```rust
// The "main" CRD (located at the top-level of the crd module)
// will use the versioned module directly as shown in other
// examples above. All CRDs located in submodules are instead
// referenced by the module they are defined in.
use crate::crd::{v1alpha1, submodule};

// This function signature makes it clear, which version of the
// CRDs it operates on. It also cleary indicates, that one of the
// CRDs is defined in a submodule.
fn my_func(crd: v1alpha1::MyCrd, sub_crd: submodule::v1alpha1::MyCrd) {
    return;
}
```

**Incorrect**

```rust
// This produces conflicts, because a module named "v1alpha1" is
// imported multiple times (twice in this case).
use crate::crd::{v1alpha1, submodule::v1alpha1};

// It is NOT recommended to mix import styles and additionally
// import the CRD directly due to reasons mentioned above.
use crate::crd::{v1alpha1, submodule::v1alpha1::MyCrd};
```

### Introducing new CRDs

New CRDs should start with an unstable version, like `v1alpha1`. This clearly indicates, that it shouldn't be considered stable by users, as well as the possibility that it will likely change in the future.

Fields should be well named and well typed right from the start to avoid potentially breaking changes. A few examples:

- Use `endpoint` instead of `httpEndpoint` and `httpsEndpoint`. The protocol used can instead be indicated by the scheme of the endpoint, eg. `http://` vs `https://`.
- Use `duration` instead of `durationSeconds` or `durationMinutes` in combination with human-readable duration strings like `2h24m10s`. The same applies for all other time related fields, like `timeout`, `ttl`, `lifetime`, etc.

If we are confident that a new CRD is already in a very stable form at the time of releasing, we can instead opt to use a more majure stablity level like `v1` or `v1beta1`.

## Macro Idea Section

This section will be removed in the final ADR. This just temporarily serves as a place to write down ideas for the macro.

### Make containers versioned in a module easier to customize

```rust
#[versioned(
    version("0.0.0-dev", date = "2025-02-21", skip(from)),
    version("v1beta1"),
    version("v1")
)]
mod versioned {
    #[versioned(
        version("v1alpha1", skip(version)),
        version("v1beta1", skip(from))
    )]
    struct Foo {
        bar: usize,
    }
}
```

### Provide custom conversion function for a particular field

```rust
#[versioned(
    version(name = "v1alpha1"),
    version(name = "v1beta1"),
    version(name = "v1")
)]
mod versioned {
    struct Foo {
        #[versioned(changed(
            since = "v1alpha1",
            from_type = u64,
            convert_with = "from_u64_to_duration"
        ))]
        bar: Duration,
    }
}

fn from_u64_to_duration(seconds: u64) -> Duration {
    todo!()
}
```

[k8s-crd-versioning-docs]: https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/
[api-versioning]: https://kubernetes.io/docs/reference/using-api/#api-versioning
[versioned-changed-action]: https://stackabletech.github.io/operator-rs/stackable_versioned_macros/attr.versioned.html#changed-action
