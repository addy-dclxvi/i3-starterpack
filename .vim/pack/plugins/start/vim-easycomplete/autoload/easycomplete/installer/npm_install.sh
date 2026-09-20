#!/usr/bin/env bash

# Usage
# $ npm_install [EXECUTABLE_NAME] [NPM_NAME]

set -e

# Supporting multiple npm packages(e.g. typescript-language-server uses typescript-language-server and tsserver).
# If package.json exists, skip calling npm init.
if [ ! -f package.json ]; then
  # Avoid the problem of not being able to install the same package as name in package.json.
  # Create an empty package.json.
  npm init -y
  echo '{"name": ""}' >package.json
fi

npm install "$2"
ln -s "./node_modules/.bin/$1" .
