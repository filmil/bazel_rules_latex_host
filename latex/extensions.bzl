"""Module extension that sets up a hermetic LaTeX toolchain.

Usage from a consumer's `MODULE.bazel` — the defaults need no arguments:

    bazel_dep(name = "rules_latex_host", version = "0.0.5")

    hermetic_latex = use_extension(
        "@rules_latex_host//latex:extensions.bzl",
        "hermetic_latex",
    )
    hermetic_latex.toolchain()
    use_repo(hermetic_latex, "hermetic_latex")

    register_toolchains("@hermetic_latex//:all")

`register_toolchains` in the root module takes precedence over the `system`
toolchain this module registers for itself, so documents build against the
vendored tools with no change to any `BUILD` file. Where the pinned binaries do
not match the exec platform, the hermetic toolchain is skipped and the system
one is used instead.

Every pin is overridable, e.g. a bigger TeX distribution and extra CTAN
packages:

    hermetic_latex.toolchain(
        texlive_url = "https://.../TinyTeX-linux-x86_64-v2026.08.tar.xz",
        texlive_sha256 = "...",
        texlive_packages = ["ieeetran", "pgf"],
    )
"""

load(
    "//latex/hermetic:repositories.bzl",
    "ghostscript_repository",
    "hermetic_latex_hub_repository",
    "qpdf_repository",
    "texlive_repository",
)
load(
    "//latex/hermetic:versions.bzl",
    "EXEC_COMPATIBLE_WITH",
    "GHOSTSCRIPT",
    "QPDF",
    "TEXLIVE",
)

_DEFAULT_NAME = "hermetic_latex"

_toolchain = tag_class(
    doc = "Declares one hermetic LaTeX toolchain from pinned archives.",
    attrs = {
        "name": attr.string(
            default = _DEFAULT_NAME,
            doc = "Name of the generated hub repository; `use_repo` this name " +
                  "and register `@<name>//:all`.",
        ),
        "texlive_url": attr.string(default = TEXLIVE["url"]),
        "texlive_sha256": attr.string(default = TEXLIVE["sha256"]),
        "texlive_strip_prefix": attr.string(default = TEXLIVE["strip_prefix"]),
        "texlive_engine": attr.string(
            default = TEXLIVE["engine"],
            doc = "pdflatex path inside the stripped TeX archive.",
        ),
        "texlive_packages": attr.string_list(
            default = [],
            doc = "Extra TeX Live packages to install with `tlmgr` after " +
                  "extraction (e.g. [\"ieeetran\", \"pgf\"]). Costs fetch-time " +
                  "network access and a host perl, and is not content-addressed.",
        ),
        "qpdf_url": attr.string(default = QPDF["url"]),
        "qpdf_sha256": attr.string(default = QPDF["sha256"]),
        "qpdf_strip_prefix": attr.string(default = QPDF["strip_prefix"]),
        "qpdf_binary": attr.string(default = QPDF["binary"]),
        "qpdf_lib_dir": attr.string(default = QPDF["lib_dir"]),
        "gs_url": attr.string(default = GHOSTSCRIPT["url"]),
        "gs_sha256": attr.string(default = GHOSTSCRIPT["sha256"]),
        "gs_strip_prefix": attr.string(default = GHOSTSCRIPT["strip_prefix"]),
        "gs_binary": attr.string(default = GHOSTSCRIPT["binary"]),
        "exec_compatible_with": attr.string_list(
            default = EXEC_COMPATIBLE_WITH,
            doc = "Exec constraints of the pinned binaries. Loosen or change " +
                  "this when pinning archives for another platform.",
        ),
    },
)

def _pins(tag):
    """The pins that decide what a hub repository actually contains."""
    return (
        tag.texlive_url,
        tag.texlive_sha256,
        tag.texlive_strip_prefix,
        tag.texlive_engine,
        tuple(tag.texlive_packages),
        tag.qpdf_url,
        tag.qpdf_sha256,
        tag.qpdf_strip_prefix,
        tag.qpdf_binary,
        tag.qpdf_lib_dir,
        tag.gs_url,
        tag.gs_sha256,
        tag.gs_strip_prefix,
        tag.gs_binary,
        tuple(tag.exec_compatible_with),
    )

def _hermetic_latex_impl(mctx):
    # Resolve first, declare second: a repository name may only be declared
    # once, so which tag wins has to be settled before anything is created.
    chosen = {}  # name -> (tag, pins, from_root)

    for mod in mctx.modules:
        for tag in mod.tags.toolchain:
            pins = _pins(tag)
            previous = chosen.get(tag.name)
            if previous == None:
                chosen[tag.name] = (tag, pins, mod.is_root)
                continue

            _, previous_pins, previous_from_root = previous
            if previous_pins == pins:
                continue
            if mod.is_root:
                # The root module has the last word on what a shared name
                # resolves to.
                chosen[tag.name] = (tag, pins, True)
            elif not previous_from_root:
                fail(
                    "two modules declare the hermetic LaTeX toolchain '%s' " % tag.name +
                    "with different pins. Give one of them a distinct `name`, " +
                    "or align the attributes.",
                )

    fetches_packages = False
    for tag, _, _ in chosen.values():
        if tag.texlive_packages:
            fetches_packages = True
        _declare(tag)

    # `reproducible` says the repositories need no lockfile entry because
    # fetching them is fully content-addressed. A `tlmgr install` talks to a
    # CTAN mirror whose contents move, so that stops being true as soon as any
    # module asks for extra packages.
    return mctx.extension_metadata(reproducible = not fetches_packages)

def _declare(tag):
    texlive = tag.name + "_texlive"
    qpdf = tag.name + "_qpdf"
    gs = tag.name + "_ghostscript"

    texlive_repository(
        name = texlive,
        url = tag.texlive_url,
        sha256 = tag.texlive_sha256,
        strip_prefix = tag.texlive_strip_prefix,
        engine = tag.texlive_engine,
        packages = tag.texlive_packages,
    )
    qpdf_repository(
        name = qpdf,
        url = tag.qpdf_url,
        sha256 = tag.qpdf_sha256,
        strip_prefix = tag.qpdf_strip_prefix,
        binary = tag.qpdf_binary,
        lib_dir = tag.qpdf_lib_dir,
    )
    ghostscript_repository(
        name = gs,
        url = tag.gs_url,
        sha256 = tag.gs_sha256,
        strip_prefix = tag.gs_strip_prefix,
        binary = tag.gs_binary,
    )
    hermetic_latex_hub_repository(
        name = tag.name,
        texlive_repo = texlive,
        qpdf_repo = qpdf,
        gs_repo = gs,
        # Canonical labels, so the generated BUILD file resolves them no matter
        # what the consumer calls this module.
        toolchain_bzl = str(Label("//latex:toolchain.bzl")),
        toolchain_type = str(Label("//latex:toolchain_type")),
        exec_compatible_with = [str(Label(c)) for c in tag.exec_compatible_with],
    )

hermetic_latex = module_extension(
    implementation = _hermetic_latex_impl,
    tag_classes = {"toolchain": _toolchain},
    doc = "Fetches a pinned TeX distribution, qpdf and ghostscript, and binds " +
          "them into a `latex_toolchain` ready for `register_toolchains`.",
)
