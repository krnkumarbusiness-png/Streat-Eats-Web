#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="${PATH}:$(pwd)/flutter/bin"
flutter precache --web
flutter pub get
flutter build web --release --no-tree-shake-icons
