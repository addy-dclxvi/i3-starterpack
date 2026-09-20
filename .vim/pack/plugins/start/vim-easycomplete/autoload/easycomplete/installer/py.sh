#!/usr/bin/env bash

set -e

"$(dirname "$0")/pip_install.sh" pylsp python-lsp-server
