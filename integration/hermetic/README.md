# Hermetic-toolchain integration module

A self-standing Bazel module — its own `MODULE.bazel`, `.bazelrc` and
`.bazelversion`, built from this directory, not from the repository root — that
builds LaTeX PDFs **without a TeX installation**. The engine, the PDF utilities
and every `.sty` file they read are archives Bazel downloads by SHA-256 and
passes to the actions as declared inputs.

Its sibling [`../system`](../system) is the same idea against the host TeX
toolchain. Compare the two: the `BUILD.bazel` files are written the same way,
and everything that differs is in `MODULE.bazel`.

```sh
bazel build //...
# -> bazel-bin/paper.pdf, bazel-bin/note.pdf, bazel-bin/collection.pdf
```

No `apt-get install texlive`, no `install_tools` step. On a machine that *does*
have TeX, the vendored engine is still the one that runs — which you can check:

```sh
pdfinfo bazel-bin/paper.pdf | grep Producer   # the pinned TinyTeX pdfTeX
pdflatex --version | head -1                  # ... not this one
```

## Consuming a module from a custom registry

`rules_latex_host` is published in a personal registry, not in the Bazel Central
Registry, so [`.bazelrc`](./.bazelrc) has to say where to look:

```
common --registry=https://raw.githubusercontent.com/filmil/bazel-registry/main
common --registry=https://bcr.bazel.build
```

Two things about those lines are easy to get wrong:

1. **BCR must be repeated.** Naming any `--registry` replaces the built-in
   default instead of adding to it. Drop the second line and the build fails
   resolving `platforms`, `rules_shell` and everything else that *is* in BCR.
2. **Order is significant.** Registries are consulted in the order given, so the
   custom one goes first; a module present in both resolves from it.

With that in place, [`MODULE.bazel`](./MODULE.bazel) is ordinary:

```starlark
bazel_dep(name = "rules_latex_host", version = "0.0.5")
```

## Turning on the hermetic toolchain

```starlark
hermetic_latex = use_extension(
    "@rules_latex_host//latex:extensions.bzl",
    "hermetic_latex",
)
hermetic_latex.toolchain(
    texlive_packages = ["ieeetran", "pgf", "courier"],
)
use_repo(hermetic_latex, "hermetic_latex")

register_toolchains("@hermetic_latex//:all")
```

`register_toolchains` belongs in the **root** module: registrations there are
matched before those a dependency makes for itself, which is how this wins over
the `system` toolchain `rules_latex_host` registers. Where the pinned binaries
do not fit the exec platform, the hermetic toolchain is skipped and the system
one is used — so a repository shared across a mixed fleet still builds.

`texlive_packages` is what the base distribution does not carry: `paper.tex` is
an IEEEtran document with a tikz figure, and IEEEtran sets `\texttt` in Courier.
Those are installed with `tlmgr` when the repository is fetched, which needs
network access to a CTAN mirror and a host perl at fetch time — pin a larger
tarball with `texlive_url`/`texlive_sha256` if you would rather not depend on
either. [`note.tex`](./note.tex) needs none of this and builds against the base
distribution as it comes.

## What the targets show

| Target | Shows |
|---|---|
| `//:paper` | a multi-file document (`sections/*.tex` via `deps`) using packages added at fetch time |
| `//:note` | the same rules against the stock vendored distribution |
| `//:collection` | `combined_pdf` — exercises the other three vendored tools: page counts, the merge, and the PDF outline |

[`BUILD.bazel`](./BUILD.bazel) is worth a look for what it *doesn't* contain:
no tool paths, no toolchain wiring, nothing hermetic-specific. It is byte for
byte what you would write for a host-TeX build.

## Lifting this out into your own repository

Everything here is a working starting point; copy the directory and make two
edits:

1. Delete the `local_path_override` from `MODULE.bazel`. It only exists because
   this module sits inside the rules repository and should build against the
   checked-out rules; a real consumer resolves `rules_latex_host` from the
   registry named in `.bazelrc`.
2. Keep `.bazelrc` as it is — the two `--registry` lines are exactly what a
   consumer outside this repository needs.

Nothing else here is in-repo-specific.

## See also

- The [Hermetic toolchain](../../README.md#hermetic-toolchain) section of the
  top-level README — the toolchain contract, the pins, and how to override them.
- [`filmil/bazel-registry`](https://github.com/filmil/bazel-registry) — the
  registry the `bazel_dep` resolves from once the override is gone.
