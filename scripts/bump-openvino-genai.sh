#!/usr/bin/env bash
# Bump packages/openvino-genai-bin to the latest OpenVINO GenAI PyPI release.
# Resolves the cp314 (openvino, openvino-genai) and py3 (openvino-tokenizers)
# wheels from PyPI, rewrites URLs + hashes + versions, regenerates .SRCINFO.
set -euo pipefail
cd "$(dirname "$0")/../packages/openvino-genai-bin"

pyver() { curl -fsSL "https://pypi.org/pypi/$1/json" | jq -r .info.version; }

# openvino-genai drives the package version; openvino is its matched runtime.
genai_v="$(pyver openvino-genai)"
cur="$(sed -nE 's/^pkgver=(.*)$/\1/p' PKGBUILD)"
[[ $genai_v == "$cur" ]] && { echo "bump-genai: already at $genai_v"; exit 0; }
echo "bump-genai: $cur -> $genai_v"

# Pull the three wheels' url + sha256 for the current top versions.
pick() { # $1=pkg  $2=filename-regex
  curl -fsSL "https://pypi.org/pypi/$1/json" | python3 -c "
import sys,json,re
d=json.load(sys.stdin); v=d['info']['version']
for f in d['releases'][v]:
    if re.search(r'''$2''', f['filename']):
        print(f['filename']); print(f['url']); print(f['digests']['sha256']); break
"
}
mapfile -t ov   < <(pick openvino            'cp314-cp314-manylinux_2_28_x86_64\.whl$')
mapfile -t tok  < <(pick openvino-tokenizers 'py3-none-manylinux_2_28_x86_64\.whl$')
mapfile -t gen  < <(pick openvino-genai      'cp314-cp314-manylinux_2_28_x86_64\.whl$')
[[ ${#ov[@]} -eq 3 && ${#tok[@]} -eq 3 && ${#gen[@]} -eq 3 ]] || { echo "bump-genai: missing a wheel — skipping" >&2; exit 0; }

ov_v="$(sed -E 's/^openvino-([0-9.]+)-.*/\1/' <<<"${ov[0]}")"

python3 - "$genai_v" "$ov_v" "${ov[0]}" "${ov[1]}" "${ov[2]}" \
             "${tok[0]}" "${tok[1]}" "${tok[2]}" \
             "${gen[0]}" "${gen[1]}" "${gen[2]}" <<'PY'
import sys, re
gv, ovv, ovn, ovu, ovs, tn, tu, ts, gn, gu, gs = sys.argv[1:12]
p = open("PKGBUILD").read()
p = re.sub(r'^pkgver=.*',  f'pkgver={gv}',  p, 1, re.M)
p = re.sub(r'^_ov_ver=.*', f'_ov_ver={ovv}', p, 1, re.M)
p = re.sub(r'^pkgrel=.*',  'pkgrel=1',       p, 1, re.M)
p = re.sub(r'^_ovwhl=.*',    f'_ovwhl="{ovn}"',    p, 1, re.M)
p = re.sub(r'^_tokwhl=.*',   f'_tokwhl="{tn}"',    p, 1, re.M)
p = re.sub(r'^_genaiwhl=.*', f'_genaiwhl="{gn}"',  p, 1, re.M)
p = re.sub(r'source=\([^)]*\)',
           'source=(\n  "%s"\n  "%s"\n  "%s"\n)' % (ovu, tu, gu), p, 1)
p = re.sub(r'sha256sums=\([^)]*\)',
           "sha256sums=(\n  '%s'\n  '%s'\n  '%s'\n)" % (ovs, ts, gs), p, 1)
open("PKGBUILD","w").write(p)
PY
makepkg --printsrcinfo > .SRCINFO
echo "bump-genai: updated to $genai_v (openvino $ov_v)"
