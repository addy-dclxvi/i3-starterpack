#!/usr/bin/env bash

set -e

version="0.5.2"
curl -L -o server.zip "https://github.com/fwcd/kotlin-language-server/releases/download/$version/server.zip"
unzip server.zip
rm server.zip

ln -s server/bin/kotlin-language-server .
