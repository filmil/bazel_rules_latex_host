"""LaTeX build rules that consume the `//latex:toolchain_type` toolchain.

`latex_document` compiles `<main>.tex` -> `<main>.pdf` with three engine passes
(enough for cross-references, longtable continued-headers, and the in-document
`thebibliography`). `combined_pdf` concatenates several PDFs and adds a
top-level per-part outline. Neither rule names a binary directly — the TeX
engine and PDF utilities come from the registered LaTeX toolchain, so they can
be swapped (system today, hermetic later) without touching any document target.
"""

_TC = "//latex:toolchain_type"

def _rel(f, pkg):
    """Path of file `f` relative to its package dir `pkg`."""
    sp = f.short_path
    if pkg and sp.startswith(pkg + "/"):
        return sp[len(pkg) + 1:]
    return sp

def _latex_document_impl(ctx):
    tc = ctx.toolchains[_TC].latex
    main = ctx.attr.main
    out = ctx.actions.declare_file(main[:-len(".tex")] + ".pdf")
    pkg = ctx.label.package

    copies = []
    for f in ctx.files.srcs + ctx.files.data:
        rel = _rel(f, pkg)
        d = rel.rsplit("/", 1)[0] if "/" in rel else "."
        copies.append('mkdir -p "$W/' + d + '" && cp "' + f.path + '" "$W/' + rel + '"')

    lines = [
        "set -e",
        'export PATH="/usr/bin:/bin:/usr/local/bin:${PATH:-}"',
        'PDFLATEX="$(pwd)/' + tc.pdflatex.path + '"',
        'W="$(mktemp -d)"',
        'export HOME="$(mktemp -d)"',
    ] + copies + [
        '( cd "$W" && for i in 1 2 3; do "$PDFLATEX" -interaction=nonstopmode ' +
        '-halt-on-error "' + main + '" > build.log 2>&1 || { echo "== LaTeX ' +
        'failed: ' + main + ' =="; tail -n 40 build.log; exit 1; }; done )',
        'cp "$W/' + main[:-len(".tex")] + '.pdf" "' + out.path + '"',
        'rm -rf "$W" "$HOME"',
    ]

    ctx.actions.run_shell(
        inputs = ctx.files.srcs + ctx.files.data,
        # `tc.files` is empty for the system toolchain and the whole vendored
        # TeX tree for a hermetic one; declaring it keeps the action sandboxable.
        tools = depset([tc.pdflatex], transitive = [tc.files]),
        outputs = [out],
        command = "\n".join(lines),
        mnemonic = "LaTeX",
        progress_message = "LaTeX %s (3 passes)" % out.short_path,
    )
    return [DefaultInfo(files = depset([out]))]

_latex_document = rule(
    implementation = _latex_document_impl,
    attrs = {
        "main": attr.string(mandatory = True, doc = "Main .tex filename in this package."),
        "srcs": attr.label_list(allow_files = [".tex"], mandatory = True),
        # Everything else the document reads: figures, a bibliography, a
        # class or style file that ships with the paper. Each is copied
        # into the work directory under its package relative path, so
        # \includegraphics{figures/plot} finds figures/plot.png.
        "data": attr.label_list(allow_files = True),
    },
    toolchains = [_TC],
)

def latex_document(name, main, deps = [], data = [], visibility = ["//visibility:public"], **kwargs):
    """Compile `main` (a .tex file in this package) to a PDF via three passes.

    Args:
      name: target name.
      main: the main .tex file (e.g. "paper.tex").
      deps: the other .tex files it `\\input`s (e.g.
        glob(["sections/*.tex"])).
      data: everything else the document reads: figures, a bibliography,
        a class or style file (e.g. glob(["figures/*.png"])). Each is
        copied into the work directory under its package relative path,
        so `\\includegraphics{figures/plot}` finds `figures/plot.png`.
      visibility: target visibility (public by default so a `combined_pdf`
        target can consume the produced PDF across packages).
      **kwargs: forwarded to the underlying rule.
    """
    _latex_document(
        name = name,
        main = main,
        srcs = [main] + deps,
        data = data,
        visibility = visibility,
        **kwargs
    )

def _combined_pdf_impl(ctx):
    tc = ctx.toolchains[_TC].latex
    out = ctx.actions.declare_file(ctx.attr.out)
    pdfs = ctx.files.parts
    combine = ctx.file._combine

    # Outline titles: one per part, in order. Written to a file (line i names
    # part i); combine.sh falls back to "Part <n>" for any part without a title.
    titles_file = ctx.actions.declare_file(ctx.attr.out + ".titles.txt")
    ctx.actions.write(titles_file, "".join([t + "\n" for t in ctx.attr.bookmarks]))

    args = " ".join(['"' + f.path + '"' for f in pdfs])
    command = "\n".join([
        "set -e",
        'export PATH="/usr/bin:/bin:/usr/local/bin:${PATH:-}"',
        'PDFINFO="$(pwd)/' + tc.pdfinfo.path + '" ' +
        'PDFUNITE="$(pwd)/' + tc.pdfunite.path + '" ' +
        'GS="$(pwd)/' + tc.gs.path + '" ' +
        'bash "' + combine.path + '" "' + out.path + '" "' + titles_file.path + '" ' + args,
    ])

    ctx.actions.run_shell(
        inputs = pdfs + [combine, titles_file],
        tools = depset([tc.pdfinfo, tc.pdfunite, tc.gs], transitive = [tc.files]),
        outputs = [out],
        command = command,
        mnemonic = "PdfCombine",
        progress_message = "Merging %s" % out.short_path,
    )
    return [DefaultInfo(files = depset([out]))]

combined_pdf = rule(
    implementation = _combined_pdf_impl,
    attrs = {
        "out": attr.string(mandatory = True, doc = "Output PDF filename."),
        "parts": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "PDFs to concatenate, in order.",
        ),
        "bookmarks": attr.string_list(
            default = [],
            doc = "Optional top-level outline titles, one per part, in the same " +
                  "order as `parts`. Parts without a title fall back to " +
                  "\"Part <n>\".",
        ),
        "_combine": attr.label(default = Label("//latex:combine.sh"), allow_single_file = True),
    },
    toolchains = [_TC],
)
