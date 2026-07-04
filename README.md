# rules_latex_host

[![Test](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/test.yml/badge.svg)](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/test.yml)
[![Tag and Release](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/tag-and-release.yml/badge.svg)](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/tag-and-release.yml)
[![Publish](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/publish.yml/badge.svg)](https://github.com/filmil/bazel_rules_latex_host/actions/workflows/publish.yml)

Bazel rules that build **LaTeX** PDFs by shelling out to the **host** TeX
toolchain — `pdflatex` plus `poppler-utils` (`pdfinfo`, `pdfunite`) and
`ghostscript` (`gs`). It is deliberately **non-hermetic** (hence *host*): the
tools come from a Bazel *toolchain* whose default implementation wraps the
binaries found on the machine. The toolchain boundary means you can later swap
in a hermetic (vendored) TeX distribution without touching any document target.

## What you get

- `latex_document(name, main, deps)` — compiles `main.tex` → `main.pdf` with
  three `pdflatex` passes (resolves cross-references, `longtable`
  continued-headers, and the in-document `thebibliography`). `deps` are extra
  files the master `\input`s, e.g. `glob(["sections/*.tex"])`.
- `combined_pdf(name, out, parts)` — concatenates several PDFs with `pdfunite`
  and adds a top-level PDF outline via ghostscript.
- A `//latex:toolchain_type` and a `system_latex` toolchain, auto-registered by
  the module.

## Prerequisites

Install the host tools once:

```sh
bazel run @rules_latex_host//latex:install_tools
# or:  bash latex/install-tools.sh
```

(TeX Live + poppler-utils + ghostscript, via the platform package manager.)

## Usage

`.bazelrc` — add this registry (it hosts the module), keeping BCR too:

```
common --registry=https://raw.githubusercontent.com/filmil/bazel-registry/main
common --registry=https://bcr.bazel.build
```

`MODULE.bazel`:

```starlark
bazel_dep(name = "rules_latex_host", version = "0.0.1")
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

## Swapping in a hermetic toolchain

Document rules depend only on `//latex:toolchain_type`. To go hermetic, make the
real binaries available as Bazel targets (e.g. an `http_archive` of a vendored
TeX Live / poppler / ghostscript), declare a `latex_toolchain` pointing at them
(see [`latex/toolchain.bzl`](./latex/toolchain.bzl)), and `register_toolchains`
it ahead of the system one — no document `BUILD` file changes.

## License

Apache License 2.0 — see [LICENSE](./LICENSE).
