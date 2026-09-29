#!/usr/bin/env bash

set -e

os=$(uname -s | tr "[:upper:]" "[:lower:]")

case $os in
linux)
  filename="deno-x86_64-unknown-linux-gnu.zip"
  ;;
darwin)
  if [ $(uname -m) == "x86_64" ]; then
    filename="deno-x86_64-apple-darwin.zip"
  else
    filename="deno-aarch64-apple-darwin.zip"
  fi
  ;;
esac

curl -L -o "deno-$os.zip" "https://github.com/denoland/deno/releases/latest/download/$filename"
unzip "deno-$os.zip"
