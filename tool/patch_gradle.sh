#!/usr/bin/env bash
#
# Enable Java 8+ API desugaring in the app module.
#
# flutter_local_notifications uses java.time, which needs core-library
# desugaring to run on our minSdk (21). The committed build.gradle.kts already
# carries this, so the script is a safety net: it guarantees the block is present
# on any checkout (or after a local `flutter create` regenerates the shell).
# Idempotent: safe to run on an already-patched file.
set -euo pipefail

GRADLE="android/app/build.gradle.kts"
DESUGAR_VERSION="2.1.4"

if [[ ! -f "$GRADLE" ]]; then
  echo "patch_gradle: $GRADLE not found (run 'flutter create' first)" >&2
  exit 1
fi

if grep -q "coreLibraryDesugaring" "$GRADLE"; then
  echo "patch_gradle: desugaring already enabled, nothing to do"
  exit 0
fi

# 1) Flip the flag on inside the first compileOptions { ... } block.
tmp="$(mktemp)"
awk '
  !done && /compileOptions[[:space:]]*\{/ {
    print
    print "        isCoreLibraryDesugaringEnabled = true"
    done = 1
    next
  }
  { print }
' "$GRADLE" > "$tmp"
mv "$tmp" "$GRADLE"

# 2) Add the desugar runtime dependency.
cat >> "$GRADLE" <<EOF

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:${DESUGAR_VERSION}")
}
EOF

echo "patch_gradle: enabled core-library desugaring (desugar_jdk_libs ${DESUGAR_VERSION})"
