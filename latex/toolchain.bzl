"""LaTeX toolchain definition.

Factors the external binaries the build shells out to — the TeX engine plus the
PDF utilities — behind a Bazel toolchain. Document `BUILD` files depend only on
`//latex:toolchain_type`; the *concrete* tools are chosen by whichever toolchain
is registered. By default that is the `system` toolchain (thin wrappers around
the host binaries); to go hermetic, register a different `latex_toolchain` whose
tools come from a vendored TeX Live / poppler / ghostscript (e.g. via an
`http_archive` + module extension) — no document `BUILD` file needs to change.
"""

LatexInfo = provider(
    doc = "The set of external tools the LaTeX build shells out to.",
    fields = {
        "pdflatex": "File: the TeX engine that emits PDF.",
        "pdfinfo": "File: poppler `pdfinfo` (page counts).",
        "pdfunite": "File: poppler `pdfunite` (concatenate PDFs).",
        "gs": "File: ghostscript (adds the PDF outline).",
    },
)

def _latex_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        latex = LatexInfo(
            pdflatex = ctx.file.pdflatex,
            pdfinfo = ctx.file.pdfinfo,
            pdfunite = ctx.file.pdfunite,
            gs = ctx.file.gs,
        ),
    )]

latex_toolchain = rule(
    implementation = _latex_toolchain_impl,
    attrs = {
        "pdflatex": attr.label(allow_single_file = True, mandatory = True),
        "pdfinfo": attr.label(allow_single_file = True, mandatory = True),
        "pdfunite": attr.label(allow_single_file = True, mandatory = True),
        "gs": attr.label(allow_single_file = True, mandatory = True),
    },
    doc = "Binds a concrete set of LaTeX/PDF tool executables into a toolchain.",
)
