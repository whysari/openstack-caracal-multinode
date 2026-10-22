#!/usr/bin/env bash
#
# Static validation for the repository. Run from the repo root:
#
#   ./scripts/validate.sh
#
# Checks:
#   - shell syntax and executable bits
#   - INI/config parsing (except sysctl and rsyncd, which are not INI)
#   - netplan YAML parsing (PyYAML, with a Ruby fallback)
#   - SVG/XML parsing
#   - relative Markdown links
#   - accidental private keys / cloud tokens
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
ok()   { printf '  [ok]   %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; fail=1; }

echo "== shell =="
while IFS= read -r f; do
    if bash -n "$f"; then
        ok "syntax: $f"
    else
        bad "syntax: $f"
    fi
    if [[ -x "$f" ]]; then
        ok "executable: $f"
    else
        bad "not executable: $f"
    fi
done < <(find scripts configs/ovs -name '*.sh' -type f | sort)

echo "== INI/config files =="
python3 - <<'PY'
import configparser, glob, sys
skip = {
    'configs/sysctl/90-openstack.conf',      # sysctl format, not INI
    'configs/block/lvm.conf',                # LVM format, not INI
    'configs/block/tgt-cinder.conf',         # tgt include, not INI
    'configs/controller/etcd.conf',          # environment file, not INI
    'configs/object/swift/rsyncd.conf',      # rsyncd global section, not INI
}
files = [f for f in glob.glob('configs/**/*.conf', recursive=True)
         + glob.glob('configs/**/*.ini', recursive=True) if f not in skip]
bad = []
for f in sorted(files):
    cp = configparser.ConfigParser(interpolation=None)
    try:
        cp.read(f)
    except Exception as e:
        bad.append((f, str(e)))
for f, e in bad:
    print(f'  [FAIL] {f}: {e}')
if bad:
    sys.exit(1)
print(f'  [ok]   parsed {len(files)} INI files (skipped {len(skip)} non-INI)')
PY

echo "== netplan YAML =="
python3 - <<'PY'
import glob, sys
try:
    import yaml
except ImportError:
    import shutil, subprocess
    if shutil.which('ruby'):
        code = 'require "yaml"; Dir.glob("configs/**/*.yaml").each { |f| YAML.load_file(f, aliases: true) }'
        result = subprocess.run(['ruby', '-e', code], capture_output=True, text=True)
        if result.returncode:
            print(f'  [FAIL] YAML parse: {result.stderr.strip()}')
            sys.exit(1)
        print('  [ok]   YAML parsed with Ruby (PyYAML not installed)')
        sys.exit(0)
    print('  [skip] no YAML parser available; CI installs PyYAML')
    sys.exit(0)
bad = []
files = sorted(glob.glob('configs/**/*.yaml', recursive=True))
for f in files:
    try:
        list(yaml.safe_load_all(open(f, encoding='utf-8')))
    except Exception as e:
        bad.append((f, str(e)))
for f, e in bad:
    print(f'  [FAIL] {f}: {e}')
if bad:
    sys.exit(1)
print(f'  [ok]   parsed {len(files)} YAML files')
PY

echo "== SVG/XML =="
python3 - <<'PY'
import glob, sys
import xml.etree.ElementTree as ET
bad = []
files = sorted(glob.glob('diagrams/*.svg'))
for f in files:
    try:
        ET.parse(f)
    except Exception as e:
        bad.append((f, str(e)))
for f, e in bad:
    print(f'  [FAIL] {f}: {e}')
if bad:
    sys.exit(1)
print(f'  [ok]   parsed {len(files)} SVG files')
PY

echo "== Markdown links =="
python3 - <<'PY'
import os, re, sys
broken = []
checked = 0
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d != '.git']
    for fn in files:
        if not fn.endswith('.md'):
            continue
        checked += 1
        path = os.path.join(root, fn)
        text = open(path, encoding='utf-8').read()
        for m in re.finditer(r'\[[^\]]*\]\(([^)]+)\)', text):
            link = m.group(1).strip().strip('<>')
            if link.startswith(('http://', 'https://', '#', 'mailto:')):
                continue
            link = link.split('#', 1)[0]
            if not link:
                continue
            target = os.path.normpath(os.path.join(root, link))
            if not os.path.exists(target):
                broken.append((path, link))
for path, link in broken:
    print(f'  [FAIL] {path}: missing {link}')
if broken:
    sys.exit(1)
print(f'  [ok]   checked {checked} Markdown files')
PY

echo "== secret scan =="
python3 - <<'PY'
import os, re, sys
patterns = {
    'private key': re.compile(r'-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----'),
    'GitHub token': re.compile(r'\b(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b'),
    'AWS access key': re.compile(r'\bAKIA[0-9A-Z]{16}\b'),
    'Slack token': re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{10,}\b'),
}
hits = []
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d != '.git']
    for fn in files:
        path = os.path.join(root, fn)
        if os.path.getsize(path) > 2_000_000:
            continue
        try:
            text = open(path, encoding='utf-8').read()
        except (UnicodeDecodeError, OSError):
            continue
        for name, pat in patterns.items():
            if pat.search(text):
                hits.append((path, name))
for path, name in hits:
    print(f'  [FAIL] {path}: possible {name}')
if hits:
    sys.exit(1)
print('  [ok]   no private keys or cloud tokens found')
PY

echo
if (( fail )); then
    echo "validation failed"
    exit 1
fi
echo "validation passed"
