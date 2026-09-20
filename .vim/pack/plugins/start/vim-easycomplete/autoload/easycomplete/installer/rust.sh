#!/usr/bin/env bash

set -e

os=$(uname -s | tr "[:upper:]" "[:lower:]")

case $os in
linux)
  platform="x86_64-unknown-linux-gnu"
  ;;
darwin)
  platform="x86_64-apple-darwin"
  ;;
esac

echo "https://github.com/rust-analyzer/rust-analyzer/releases/download/2025-07-28/rust-analyzer-$platform.gz"

curl -L -o "rust-analyzer-$platform.gz" "https://github.com/rust-analyzer/rust-analyzer/releases/download/2021-09-27/rust-analyzer-$platform.gz"
gzip -d "rust-analyzer-$platform.gz"

mv rust-analyzer-$platform rust-analyzer
chmod +x rust-analyzer
