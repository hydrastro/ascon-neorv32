#!/usr/bin/env bash
set -euo pipefail

if [ ! -d rtl ] || [ ! -d sw/neorv32 ] || [ ! -f Makefile ]; then
  echo "ERROR: run this from the ascon-neorv32 repo root" >&2
  exit 1
fi

cat > .gitignore <<'GITIGNORE'
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
GITIGNORE

rm -rf build
rm -f sim/generated/*.vh
rm -f *.patch *.zip *.tar.gz *.rej *.orig

if [ ! -f .gitmodules ]; then
  echo "WARNING: .gitmodules is missing. Your deps/ascon-rtl directory looks like a submodule checkout," >&2
  echo "but the parent repo will not reproduce it without .gitmodules and a gitlink." >&2
  echo "Recommended repair:" >&2
  echo "  rm -rf deps/ascon-rtl" >&2
  echo "  git submodule add <YOUR_ASCON_RTL_GIT_URL> deps/ascon-rtl" >&2
  echo "  git add .gitmodules deps/ascon-rtl" >&2
else
  echo ".gitmodules present. Good."
fi

echo "Cleaned ascon-neorv32 hygiene files. Now run:"
echo "  git submodule update --init --recursive"
echo "  ./scripts/sanity_check_tree.sh"
echo "  make vectors && make sim && make lint-verilator && make sw-host-check"
echo "Then check tracked artifacts with:"
echo "  git status --short"
echo "  git ls-files build sim/generated '*.patch' '*.zip' '*.tar.gz'"
