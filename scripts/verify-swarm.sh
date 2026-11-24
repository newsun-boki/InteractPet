#!/bin/zsh
set -eu
cd "${0:A:h:h}"
zsh ./build.sh
OUT="$PWD/validation/swarm-v010"
mkdir -p "$OUT"
S="$PWD/work/octopus-pet/Sources"
T="$PWD/work/octopus-pet/Tests"
COMMON=("$S/Motion.swift" "$S/BoundaryMotion.swift" "$S/Locomotion.swift" "$S/FiveCatsMotion.swift" "$S/CatFormation.swift" "$S/CatSkeleton.swift" "$S/CatTailMotion.swift" "$S/SwarmMotion.swift")
for NAME in SwarmTests ContinuousLetterTests CatGroupTests CatTailTests; do
  xcrun swiftc -O -module-cache-path "$PWD/.cache/swift" "${COMMON[@]}" "$T/$NAME.swift" -o "$OUT/$NAME"
  "$OUT/$NAME"
done
"dist/Taro Octopus.app/Contents/MacOS/TaroOctopus" --verify-swarm --health-file "$OUT/native-menu.json"
"dist/Taro Octopus.app/Contents/MacOS/TaroOctopus" --verify-skins --health-file "$OUT/native-skins.json"
if [[ "${1:-}" == "--preview" ]]; then
  xcrun swiftc -O -module-cache-path "$PWD/.cache/swift" "${COMMON[@]}" "$S/Skins.swift" "$S/SwarmRendering.swift" "$T/SwarmPreview.swift" -framework AppKit -o "$OUT/SwarmPreview"
  "$OUT/SwarmPreview" "$OUT/gallery"
fi
