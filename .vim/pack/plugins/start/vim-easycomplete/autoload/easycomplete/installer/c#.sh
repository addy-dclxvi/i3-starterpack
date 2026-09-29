#!/usr/bin/env bash

set -e

os=$(uname -s | tr "[:upper:]" "[:lower:]")
arch="-x64"

case $os in
linux) ;;
darwin)
  os="osx"
  arch=""
  ;;
*)
  printf "%s doesn't supported by bash installer" "$os"
  exit 1
  ;;
esac

url="https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-$os$arch.tar.gz"
curl -L -o "omnisharp.tar.gz" "$url"
tar -xzvf omnisharp.tar.gz

chmod +x run

cat <<EOF >omnisharp-lsp
#!/usr/bin/env bash
DIR=\$(cd \$(dirname \$0); pwd)
\$DIR/run \$*
EOF

chmod +x omnisharp-lsp

