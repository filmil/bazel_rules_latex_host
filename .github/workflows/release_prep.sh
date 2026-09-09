#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Builds the release source archive and prints the release notes to stdout.
#
# bazel-contrib's release_ruleset.yaml runs this as
# `release_prep.sh TAG > release_notes.txt`, requires this exact path, and
# uploads and attests the archive it produces. The archive keeps the name and
# the layout the previous release step gave it: .bcr/source.template.json
# names it, and the Bazel Central Registry compares the checked-in
# MODULE.bazel against the one in the archive.
#
# `git archive`, as before: the archive is exactly the committed tree at the
# tag, with no build output and no `bazel-*` symlink, and the reusable
# workflow has checked that tag out.
set -o errexit -o nounset -o pipefail

TAG="$1"
VERSION="${TAG#v}"
ARCHIVE="bazel_rules_latex_host-${TAG}.zip"

git archive --format=zip --output="${ARCHIVE}" "${TAG}"

cat <<NOTES
## Using Bzlmod

\`\`\`starlark
bazel_dep(name = "rules_latex_host", version = "${VERSION}")
\`\`\`

With filmil/bazel-registry ahead of the Bazel Central Registry in \`.bazelrc\`:

\`\`\`
common --registry=https://raw.githubusercontent.com/filmil/bazel-registry/main
common --registry=https://bcr.bazel.build
\`\`\`
NOTES
