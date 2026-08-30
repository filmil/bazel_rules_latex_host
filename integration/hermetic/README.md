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

This module exercises **both** ways of adding what the base distribution does
not carry.

`texlive_packages` installs with `tlmgr` at fetch time. `paper.tex` is an
IEEEtran document with a tikz figure, and IEEEtran sets `\texttt` in Courier, so
it needs three packages with dependencies of their own. That convenience costs
network access to a live mirror and a host perl, and is not content-addressed.

`texlive_archives` pins package archives by sha256 instead. `note.tex` is set
in XCharter, which is in no TinyTeX variant, so no `texlive_url` can reach it.
It is also the interesting case for the mechanism. XCharter ships a font map,
which has to be registered with `updmap-sys`; without that the engine finds the
metrics and cannot embed the glyphs. It also needs three support packages,
which `texlive_archives` does not resolve for you. One of them is easy to miss:
`scalefnt.sty` lives in `carlisle`, not in `graphics` where you would look.

The URLs point at a CTAN mirror rather than `texlive.info`. The latter's dated
snapshots would be the better source, but the host is behind an anti-scraper
that answers an unrecognised client with HTTP 200 and a challenge page instead
of the file, so a Bazel fetch fails there as a checksum mismatch.

## What the targets show

| Target | Shows |
|---|---|
| `//:paper` | a multi-file document (`sections/*.tex` via `deps`) using packages added at fetch time with `texlive_packages` |
| `//:note` | a document set in a font added by `texlive_archives`, the content-addressed path |
| `//:collection` | `combined_pdf` — exercises the other three vendored tools: page counts, the merge, and the PDF outline |

The check that matters for `//:note` is not that it builds. A missing font map
still typesets, in the wrong face. Look at what actually got embedded:

```sh
pdffonts bazel-bin/note.pdf   # XCharter-Roman / XCharter-Bold, Type 1
```

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
