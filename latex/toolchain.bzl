"""LaTeX toolchain definition.

Factors the external binaries the build shells out to — the TeX engine plus the
PDF utilities — behind a Bazel toolchain. Document `BUILD` files depend only on
`//latex:toolchain_type`; the *concrete* tools are chosen by whichever toolchain
is registered.

Two implementations ship with this module:

  * `//latex:system_latex` — thin wrappers that `exec` the host binaries. Auto-
    registered by `//MODULE.bazel`, non-hermetic (hence *host*).
  * the `hermetic_latex` module extension (`//latex:extensions.bzl`) — tools
    from pinned, downloaded archives. See the README.

Both satisfy the same small CLI contract (see `LatexInfo`), so no document
`BUILD` file changes when you switch between them.
"""

LatexInfo = provider(
    doc = """The external tools the LaTeX build shells out to.

    Each field is an executable honouring a fixed CLI contract, which is what a
    toolchain implementation really has to provide:

      pdflatex  [-interaction=...] [-halt-on-error] MAIN.tex
                compiles MAIN.tex in the working directory to MAIN.pdf.
      pdfinfo   FILE.pdf
                writes a line matching `Pages: <n>` to stdout.
      pdfunite  IN1.pdf IN2.pdf ... OUT.pdf
                concatenates the inputs into the last argument.
      gs        -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=OUT IN...
                applies pdfmark input (used to add the combined-PDF outline).

    The implementation behind a field need not be the program it is named after
    — the hermetic toolchain, for instance, satisfies `pdfinfo`/`pdfunite` with
    qpdf-backed shims. Only the contract above matters.
    """,
    fields = {
        "pdflatex": "File: the TeX engine that emits PDF.",
        "pdfinfo": "File: reports page counts.",
        "pdfunite": "File: concatenates PDFs.",
        "gs": "File: PostScript/PDF interpreter (adds the PDF outline).",
        "files": "depset[File]: everything the tools above need at run time " +
                 "(a vendored texmf tree, shared libraries, ...). Empty for a " +
                 "toolchain whose tools come from the host.",
    },
)

def _latex_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        latex = LatexInfo(
            pdflatex = ctx.file.pdflatex,
            pdfinfo = ctx.file.pdfinfo,
            pdfunite = ctx.file.pdfunite,
            gs = ctx.file.gs,
            files = depset(ctx.files.files),
        ),
    )]

latex_toolchain = rule(
    implementation = _latex_toolchain_impl,
    attrs = {
        "pdflatex": attr.label(allow_single_file = True, mandatory = True),
        "pdfinfo": attr.label(allow_single_file = True, mandatory = True),
        "pdfunite": attr.label(allow_single_file = True, mandatory = True),
        "gs": attr.label(allow_single_file = True, mandatory = True),
        "files": attr.label_list(
            allow_files = True,
            default = [],
            doc = "Runtime files the tools need in the action sandbox besides " +
                  "the executables themselves — e.g. a vendored TeX Live tree " +
                  "or the shared libraries a tool links against. A host-tools " +
                  "toolchain leaves this empty; a hermetic one lists the whole " +
                  "extracted distribution.",
        ),
    },
    doc = "Binds a concrete set of LaTeX/PDF tool executables into a toolchain.",
)
