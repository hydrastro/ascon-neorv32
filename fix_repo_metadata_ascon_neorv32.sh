#!/usr/bin/env bash
set -euo pipefail

# Run this from the ascon-neorv32 repository root.

cat > .gitignore <<'EOF'
# Build products
/build/

# Generated simulation vectors copied from core
/sim/generated/*.vh

# Simulator outputs
*.vcd
*.fst
*.vvp

# Patch/editor/archive leftovers
*.rej
*.orig
*.patch
*.zip
*.tar.gz
*~

# Nix/direnv local outputs
/result
/.direnv/
/.envrc
EOF

cat > .gitmodules <<'EOF'
[submodule "deps/ascon-rtl"]
	path = deps/ascon-rtl
	url = https://github.com/hydrastro/ascon-rtl.git
EOF

rm -rf build
rm -f sim/generated/*.vh
rm -f *.patch *.zip *.tar.gz
rm -f ./*.rej ./*.orig

# Remove tracked generated files/artifacts from the index if they were accidentally committed.
git rm -r --cached build sim/generated 2>/dev/null || true
git rm --cached -- *.patch *.zip '*.tar.gz' 2>/dev/null || true

# Make Git re-read the corrected submodule config.
git submodule sync --recursive || true
git submodule update --init --recursive

git add .gitignore .gitmodules deps/ascon-rtl

echo "Fixed ascon-neorv32 metadata/hygiene. Now run:"
echo "  ./scripts/sanity_check_tree.sh"
echo "  make vectors && make sim && make lint-verilator && make sw-host-check"
echo "  git status --short"
