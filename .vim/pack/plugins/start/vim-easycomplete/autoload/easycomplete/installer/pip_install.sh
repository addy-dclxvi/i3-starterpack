#!/usr/bin/env bash

# Usage
# $ pip_install [EXECUTABLE_NAME] [PYPI_NAME]

set -e

python3 -m venv ./venv
./venv/bin/pip3 install -U pip
./venv/bin/pip3 install "$2"
# pip3 install "$2"
ln -s "./venv/bin/$1" .
