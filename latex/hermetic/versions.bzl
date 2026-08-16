"""Pinned archives the hermetic LaTeX toolchain is built from.

Every default here is a released artifact with a stable URL and a recorded
SHA-256, so a fetch is reproducible. Each is overridable per-attribute on the
`hermetic_latex.toolchain()` tag — see `//latex:extensions.bzl` and the README
section "Hermetic toolchain".

Why these three:

  * **TinyTeX** (TeX Live, packaged by RStudio) is the only TeX distribution
    published as a small, self-contained, per-platform tarball. `bin/<arch>/`
    holds relocatable binaries that locate their own `texmf-dist` — no install
    step, no `texmf.cnf` patching. The `-1` variant (~54 MB) carries the LaTeX
    base plus the common packages and no documentation. Fuller variants exist;
    see `TEXLIVE_VARIANTS` and the README.
  * **qpdf** ships a self-contained Linux binary release. It backs the
    `pdfinfo`/`pdfunite` contract (poppler publishes no prebuilt binaries).
  * **Ghostscript** 10.0.0 is the newest release Artifex published a prebuilt
    Linux x86_64 binary for; it is used only for the combined-PDF outline.

Only `linux-x86_64` has a default for all three (ghostscript is the binding
constraint). On any other platform the hermetic toolchain simply does not match
and resolution falls through to the registered `system` toolchain.
"""

TINYTEX_VERSION = "v2026.08"

QPDF_VERSION = "12.4.0"

GHOSTSCRIPT_VERSION = "10.0.0"

# TeX engine. `strip_prefix` drops the archive's leading `.TinyTeX/`; `engine`
# is the pdflatex path inside the stripped tree (a symlink to `pdftex` — the
# engine picks its format from argv[0], so it must be exec'd under this name).
TEXLIVE = {
    "url": "https://github.com/rstudio/tinytex-releases/releases/download/{v}/TinyTeX-1-linux-x86_64-{v}.tar.xz".format(v = TINYTEX_VERSION),
    "sha256": "6bcde65cbbc147d6e492fa105a7210a06792d609358ef74a14a95228e3e36656",
    "strip_prefix": ".TinyTeX",
    "engine": "bin/x86_64-linux/pdflatex",
}

# Other TinyTeX variants, for `hermetic_latex.toolchain(texlive_url = ...)`.
# `TinyTeX-1` is the default above; `TinyTeX` is the larger R Markdown set.
# Neither carries IEEEtran or pgf/tikz — install those at fetch time with the
# `texlive_packages` attribute, or point the attributes at your own tarball.
TEXLIVE_VARIANTS = {
    "TinyTeX-0": "https://github.com/rstudio/tinytex-releases/releases/download/{v}/TinyTeX-0-linux-x86_64-{v}.tar.xz",
    "TinyTeX-1": "https://github.com/rstudio/tinytex-releases/releases/download/{v}/TinyTeX-1-linux-x86_64-{v}.tar.xz",
    "TinyTeX": "https://github.com/rstudio/tinytex-releases/releases/download/{v}/TinyTeX-linux-x86_64-{v}.tar.xz",
}

# Backs the `pdfinfo` and `pdfunite` contract. The zip has `bin/qpdf` plus the
# shared libraries it links against under `lib/`.
QPDF = {
    "url": "https://github.com/qpdf/qpdf/releases/download/v{v}/qpdf-{v}-bin-linux-x86_64.zip".format(v = QPDF_VERSION),
    "sha256": "a3bca240f3bb61efdc3a90be89d1da4ed5e125326c3458c4e62df53ff4f153e3",
    "strip_prefix": "",
    "binary": "bin/qpdf",
    "lib_dir": "lib",
}

# A single statically-resourced binary; needs nothing else from the archive.
GHOSTSCRIPT = {
    "url": "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs1000/ghostscript-{v}-linux-x86_64.tgz".format(v = GHOSTSCRIPT_VERSION),
    "sha256": "176ad1cbad402ae5930521f954ad70dffaaf8d625cf508feeea4f9bf2e61f3d4",
    "strip_prefix": "ghostscript-{v}-linux-x86_64".format(v = GHOSTSCRIPT_VERSION),
    "binary": "gs-1000-linux-x86_64",
}

# The exec platform the pinned defaults above are binaries for. A toolchain that
# does not match is skipped, so registering the hermetic toolchain on a macOS or
# arm64 host is harmless — the system toolchain is used there.
EXEC_COMPATIBLE_WITH = [
    "@platforms//os:linux",
    "@platforms//cpu:x86_64",
]
