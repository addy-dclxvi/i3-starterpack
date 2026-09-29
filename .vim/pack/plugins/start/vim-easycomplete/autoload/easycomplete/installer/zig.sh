#!/usr/bin/env bash

set -e

#git clone --depth=1 https://github.com/zigtools/zls .
# git clone https://gitee.com/buffed/zls.git .
git clone https://github.com/zigtools/zls .
git checkout "refs/tags/$(git tag | grep "^$(zig version | sed -r 's/\.[0-9]+$//')")"
git submodule update --init --recursive
zig build
mv zig-out/bin/zls .
rm -rf zig-cache zig-out src tests
cat <<EOF >zls.json
{"zig_lib_path":"$(dirname "$(which zig)")/lib/zig","enable_snippets":true,"warn_style":true,"enable_semantic_tokens":true}
EOF

###########################
