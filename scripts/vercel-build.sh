#!/bin/sh
set -eu

FLUTTER_ROOT="$HOME/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter build web --release
