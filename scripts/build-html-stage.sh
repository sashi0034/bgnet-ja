#!/usr/bin/env bash
# Build HTML outputs only and assemble a GitHub Pages–ready directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export LANG="${LANG:-C.UTF-8}"
export BGBSPD_BUILD_DIR="${BGBSPD_BUILD_DIR:-$ROOT/../bgbspd}"
export GUIDE_ID=bgnet

if [[ ! -d "$BGBSPD_BUILD_DIR" ]]; then
  echo "bgbspd not found at $BGBSPD_BUILD_DIR" >&2
  echo "Clone https://github.com/beejjorgensen/bgbspd as a sibling, or set BGBSPD_BUILD_DIR." >&2
  exit 1
fi

# Point example footnote links at this GitHub Pages site
EXAMPLE_BASE="${EXAMPLE_BASE:-https://sashi0034.github.io/bgnet-ja/source/examples/}"
python3 - <<PY
from pathlib import Path
p = Path(r"$BGBSPD_BUILD_DIR") / "bin" / "preproc_config.py"
text = p.read_text(encoding="utf-8")
text2 = text.replace(
    'EXAMPLE_URL = f"https://beej.us/guide/{os.environ[\'GUIDE_ID\']}/source/examples/"',
    'EXAMPLE_URL = "' + r"""$EXAMPLE_BASE""" + '"',
)
if text == text2:
    # Fallback: rewrite any EXAMPLE_URL assignment
    import re
    text2 = re.sub(
        r'^EXAMPLE_URL\s*=.*$',
        'EXAMPLE_URL = "' + r"""$EXAMPLE_BASE""" + '"',
        text,
        count=1,
        flags=re.M,
    )
p.write_text(text2, encoding="utf-8")
print("Patched EXAMPLE_URL -> $EXAMPLE_BASE")
PY

echo "Building HTML (no PDF)..."
make -C src bgnet.html bgnet-wide.html split/index.html split-wide/index.html

SITE="${SITE_DIR:-$ROOT/_site}"
rm -rf "$SITE"
mkdir -p "$SITE/html/split" "$SITE/html/split-wide" "$SITE/source"

cp website/index.html website/index.css "$SITE/"
cp src/bgnet.html "$SITE/html/index.html"
cp src/bgnet-wide.html "$SITE/html/index-wide.html"
cp -r src/split/. "$SITE/html/split/"
cp -r src/split-wide/. "$SITE/html/split-wide/"
# SVGs referenced from HTML live next to the guide pages
cp -f src/*.svg "$SITE/html/" 2>/dev/null || true
cp -f src/*.svg "$SITE/html/split/" 2>/dev/null || true
cp -f src/*.svg "$SITE/html/split-wide/" 2>/dev/null || true
cp -r source/examples "$SITE/source/"
# Drop Apache-only pieces if any were copied
rm -f "$SITE/.htaccess" "$SITE/source/.htaccess" 2>/dev/null || true
touch "$SITE/.nojekyll"

echo "Staged HTML site at $SITE"
