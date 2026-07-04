# Example `rules_latex_host` usage

A minimal, self-contained module that consumes `rules_latex_host` to build a
PDF from a `.tex` source.

- [`MODULE.bazel`](./MODULE.bazel) pulls in `rules_latex_host` via `bazel_dep`
  and, for this in-repo example, a `local_path_override` so it always builds
  against the checked-out rules.
- [`BUILD.bazel`](./BUILD.bazel) calls `latex_document(name = "hello", main =
  "hello.tex")`.

Build it:

```sh
bazel build //:hello      # -> bazel-bin/hello.pdf
```

The host TeX tools must be installed first (the rules shell out to them):

```sh
bazel run @rules_latex_host//latex:install_tools
```
