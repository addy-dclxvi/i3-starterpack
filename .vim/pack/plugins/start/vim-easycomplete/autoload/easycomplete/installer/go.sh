#!/usr/bin/env bash

set -e

export GOPROXY=https://mirrors.aliyun.com/goproxy/
GO111MODULE=on go clean -modcache
go install golang.org/x/tools/gopls@latest
# "$(dirname "$0")/go_install.sh" golang.org/x/tools/gopls@latest
#
