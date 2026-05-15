#!/usr/bin/env bash
# maclocalai top-level installer.
# Lists available stacks and dispatches to each one's install.sh.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

stacks=()
for dir in "$ROOT_DIR"/*/; do
  if [ -f "${dir}install.sh" ]; then
    stacks+=("$(basename "$dir")")
  fi
done

if [ ${#stacks[@]} -eq 0 ]; then
  echo "No stacks found."
  exit 1
fi

echo "Available stacks:"
for i in "${!stacks[@]}"; do
  echo "  $((i+1)). ${stacks[$i]}"
done
echo "  a. all"
echo "  q. quit"
echo ""
read -r -p "Pick one or more (e.g. '1', '1 2', 'a'): " choice

run_stack() {
  local name="$1"
  echo ""
  echo "=== Installing stack: $name ==="
  bash "$ROOT_DIR/$name/install.sh"
}

case "$choice" in
  q|Q) exit 0 ;;
  a|A)
    for s in "${stacks[@]}"; do run_stack "$s"; done
    ;;
  *)
    for n in $choice; do
      idx=$((n-1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#stacks[@]}" ]; then
        run_stack "${stacks[$idx]}"
      else
        echo "Skipping invalid selection: $n"
      fi
    done
    ;;
esac
