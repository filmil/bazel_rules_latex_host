# rules_latex_host

[![Test](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/test.yml/badge.svg)](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/test.yml)
[![Tag and Release](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/tag-and-release.yml/badge.svg)](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/tag-and-release.yml)
[![Publish](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/publish.yml/badge.svg)](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/publish.yml)

Bazel rules that build **LaTeX** PDFs from `pdflatex` plus `poppler-utils`
(`pdfinfo`, `pdfunite`) and `ghostscript` (`gs`). Those tools come from a Bazel
*toolchain*, and there are two implementations:

- **host** (the default, hence the name) — thin wrappers around the binaries
  installed on the machine. Deliberately non-hermetic; nothing to download.
- **hermetic** — a pinned TeX distribution and PDF utilities that Bazel fetches,
  so the build needs nothing installed and can run sandboxed. See
  [Hermetic toolchain](#hermetic-toolchain).

Document targets are identical either way: the rules depend on a toolchain type,
never on a binary, so switching is a `MODULE.bazel` edit.

## What you get

- `latex_document(name, main, deps)` — compiles `main.tex` → `main.pdf` with
  three `pdflatex` passes (resolves cross-references, `longtable`
  continued-headers, and the in-document `thebibliography`). `deps` are extra
  files the master `\input`s, e.g. `glob(["sections/*.tex"])`.
- `combined_pdf(name, out, parts)` — concatenates several PDFs with `pdfunite`
  and adds a top-level PDF outline via ghostscript.
- A `//latex:toolchain_type` and a `system_latex` toolchain, auto-registered by
  the module.
- A `hermetic_latex` module extension that vendors the tools instead.

## Prerequisites

Install the host tools once:

```sh
bazel run @rules_latex_host//latex:install_tools
# or:  bash latex/install-tools.sh
```

(TeX Live + poppler-utils + ghostscript, via the platform package manager.)
Nothing to install if you use the [hermetic toolchain](#hermetic-toolchain).

## Usage

`.bazelrc` — this module lives in a custom registry, so name it. Naming any
`--registry` **replaces** the built-in default rather than adding to it, so BCR
has to be listed again or the module's own dependencies stop resolving.
Registries are consulted in the order given:

```
common --registry=https://raw.githubusercontent.com/filmil/bazel-registry/main
common --registry=https://bcr.bazel.build
```

`MODULE.bazel`:

```starlark
bazel_dep(name = "rules_latex_host", version = "0.0.5")
```

`BUILD.bazel`:

```starlark
load("@rules_latex_host//latex:defs.bzl", "latex_document", "combined_pdf")

latex_document(
    name = "paper",
    main = "paper.tex",
    deps = glob(["sections/*.tex"]),   # files the master \input's
)
```

```sh
bazel build //:paper      # -> bazel-bin/paper.pdf
```

The `system_latex` toolchain registers automatically, so no toolchain wiring is
needed in the consumer.

## Hermetic toolchain

The host tools are the default, not the only option. The `hermetic_latex` module
extension fetches a pinned TeX distribution and PDF utilities and binds them
into a toolchain, so a build needs nothing installed on the machine and its
actions run in the sandbox. **No document target changes** — the rules name a
toolchain type, never a binary.

In your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_latex_host", version = "0.0.5")

hermetic_latex = use_extension(
    "@rules_latex_host//latex:extensions.bzl",
    "hermetic_latex",
)
hermetic_latex.toolchain()
use_repo(hermetic_latex, "hermetic_latex")

register_toolchains("@hermetic_latex//:all")
```

That is the whole change. Skip `install_tools`; `bazel build //:paper` now
compiles with the downloaded engine. To see which one actually ran, compare
`pdfinfo bazel-bin/paper.pdf | grep Producer` against your host `pdflatex
--version`.

### What gets vendored

| Contract in `LatexInfo` | Provided by | Why |
|---|---|---|
| `pdflatex` | [TinyTeX](https://github.com/rstudio/tinytex-releases) (TeX Live) | the one TeX distribution published as a small relocatable per-platform tarball — it locates its own `texmf-dist`, so there is no install step |
| `pdfinfo`, `pdfunite` | [qpdf](https://github.com/qpdf/qpdf) + shims | poppler publishes no prebuilt binaries; only the page-count and concatenate behaviour the rules use is emulated |
| `gs` | [Ghostscript](https://github.com/ArtifexSoftware/ghostpdl-downloads) 10.0.0 | the last release with a prebuilt Linux binary; used only for the combined-PDF outline |

Each is fetched by SHA-256 — see
[`latex/hermetic/versions.bzl`](./latex/hermetic/versions.bzl) for the pins.
Ghostscript's prebuilt binaries are the binding constraint, so the shipped pins
cover **linux-x86_64**. The generated toolchain carries matching
`exec_compatible_with` constraints, so on any other platform it is skipped and
resolution falls back to the `system` toolchain — a mixed fleet keeps working.

### Adding packages

The default distribution (`TinyTeX-1`, ~54 MB) has the LaTeX base and the common
packages, but not everything — IEEEtran and pgf/tikz, for instance, are not in
it. Three ways to get them:

```starlark
# 1. Pin the package archives. Content-addressed, so the fetch is reproducible
#    byte for byte. Dependencies are NOT resolved: list what a package needs
#    alongside it.
hermetic_latex.toolchain(
    texlive_archives = {
        "https://ftp.fau.de/ctan/systems/texlive/tlnet/archive/xcharter.tar.xz": "92ae1526...",
        "https://ftp.fau.de/ctan/systems/texlive/tlnet/archive/xstring.tar.xz": "55356a92...",
    },
)

# 2. Install at fetch time. Resolves dependencies, but costs network access to
#    a live mirror and a host perl, and is not content-addressed.
hermetic_latex.toolchain(
    texlive_packages = ["ieeetran", "pgf", "courier"],
)

# 3. Pin a bigger tarball. Content-addressed, but limited to what the
#    distribution ships: XCharter and Erewhon, for instance, are in no TinyTeX
#    variant, so this cannot reach them.
hermetic_latex.toolchain(
    texlive_url = "https://github.com/rstudio/tinytex-releases/releases/download/v2026.08/TinyTeX-linux-x86_64-v2026.08.tar.xz",
    texlive_sha256 = "...",
)
```

`texlive_archives` takes `{url: sha256}`. Each archive is unpacked into the
distribution's `texmf-dist`, so it must be **texmf-relative** (`tex/latex/...`,
`fonts/type1/...`), which is exactly the layout of TeX Live's own per-package
archives. Every CTAN mirror serves them under
`systems/texlive/tlnet/archive/<package>.tar.xz`. After unpacking, the rule
runs `mktexlsr` so kpathsea sees the new files, and `updmap-sys` for any font
map the package brought, without which the engine finds the metrics but cannot
embed the glyphs.

Two things to know before reaching for it:

- **Do not fetch from `texlive.info`.** Its tlnet snapshots look like the ideal
  source: dated, immutable, already in the right layout. But the host sits
  behind an anti-scraper. It answers an unrecognised client with HTTP 200 and a
  challenge page *instead of the file*. Bazel therefore fails with a checksum
  mismatch rather than a download error, which is a confusing way to learn
  this. Use a CTAN mirror, or re-host the archives yourself.
- **CTAN's `tlnet` tree tracks the current TeX Live**, so a package's archive
  is replaced when it is updated upstream. The sha256 pin turns that into a
  loud failure rather than silent drift, but it does mean the pin needs
  refreshing occasionally. Re-host the archives if you need them frozen.

Note the asymmetry in what each option costs the build's reproducibility: with
only `texlive_archives` the extension still reports `reproducible`, so no
lockfile entry is needed. One `texlive_packages` entry gives that up, because a
live mirror serves whatever it serves today.

Every pin is overridable the same way (`qpdf_*`, `gs_*`, `exec_compatible_with`,
…) — see the tag attributes in
[`latex/extensions.bzl`](./latex/extensions.bzl). Pointing them at your own
archives is also how you extend the toolchain to another platform.

### Trying it

[`integration/hermetic/`](./integration/hermetic/) is a self-standing module —
its own `MODULE.bazel`, `.bazelrc` and `.bazelversion`, built from that
directory — that compiles an IEEEtran paper with tikz figures, a plain-article
note, and a combined edition of both, with no TeX installed:

```sh
cd integration/hermetic && bazel build //...
```

Its sibling [`integration/system/`](./integration/system/) does the same against
the host toolchain. Copying either one out into a repository of your own takes
deleting its `local_path_override` — see the
[module's README](./integration/hermetic/README.md).

### Rolling your own

The extension is a convenience, not a requirement. `latex_toolchain`
(see [`latex/toolchain.bzl`](./latex/toolchain.bzl)) takes four executables plus
a `files` list of everything they need at run time; declare one over targets of
your choosing and register it. The four executables only have to honour the CLI
contract documented on `LatexInfo` — the hermetic toolchain's `pdfinfo`, for
one, is a qpdf shim rather than poppler.

## License

Apache License 2.0 — see [LICENSE](./LICENSE).
