#!/usr/bin/env bash

set -e

git clone --depth=1 https://github.com/castwide/solargraph .
bundle install --without development --path vendor/bundle

cat <<EOF >solargraph
#!/usr/bin/env bash
DIR=\$(cd \$(dirname \$0); pwd)
BUNDLE_GEMFILE=\$DIR/Gemfile bundle exec ruby \$DIR/bin/solargraph \$*
EOF

chmod +x solargraph
