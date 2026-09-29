#!/usr/bin/env bash

# Usage
# $ go_install [GO_GET_URLPATH]

set -e

export GOPROXY=https://mirrors.aliyun.com/goproxy/
GOPATH=$(pwd) GOBIN=$(pwd) GO111MODULE=on go get -v "$1"
GOPATH=$(pwd) GO111MODULE=on go clean -modcache
rm -rf src pkg 2> /dev/null
