#!/usr/bin/env bash
# Bump packages/llama.cpp-sycl-bin to the latest upstream llama.cpp release.
# Resolves the SYCL asset by PATTERN and regenerates .SRCINFO. No-op if current.
set -euo pipefail
cd "$(dirname "$0")/../packages/llama.cpp-sycl-bin"

auth=(); [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
rel="$(curl -fsSL "${auth[@]}" https://api.github.com/repos/ggml-org/llama.cpp/releases/latest)"
tag="$(jq -r .tag_name <<<"$rel")"
[[ $tag == b* ]] || { echo "bump-sycl: unexpected tag '$tag'" >&2; exit 1; }

asset="$(jq -r '.assets[].name | select(test("ubuntu-sycl-fp16-x64\\.tar\\.gz$"))' <<<"$rel" | head -1)"
[[ -n $asset ]] || { echo "bump-sycl: release $tag lacks the sycl-fp16 asset — skipping" >&2; exit 0; }

cur="$(sed -nE 's/^pkgver=(.*)$/\1/p' PKGBUILD)"
[[ $tag == "$cur" ]] && { echo "bump-sycl: already at $tag"; exit 0; }

echo "bump-sycl: $cur -> $tag"
sha="$(curl -fsSL "${auth[@]}" "https://github.com/ggml-org/llama.cpp/releases/download/$tag/$asset" | sha256sum | cut -d' ' -f1)"
sed -i -e "s/^pkgver=.*/pkgver=${tag}/" -e "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
# First sha256sums entry is the tarball; the launcher stays SKIP.
awk -v s="$sha" '
  /^sha256sums=\(/ {inb=1; n=0; print; next}
  inb && /^\)/ {inb=0; print; next}
  inb {n++; if(n==1) sub(/'\''[0-9a-f]+'\''/, "'\''" s "'\''"); print; next}
  {print}' PKGBUILD > PKGBUILD.tmp && mv PKGBUILD.tmp PKGBUILD
makepkg --printsrcinfo > .SRCINFO
echo "bump-sycl: updated to $tag"
