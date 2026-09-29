#!/usr/bin/env bash

set -e

os=$(uname -s | tr "[:upper:]" "[:lower:]")

case $os in
linux)
  platform="linux"
  ;;
darwin)
  platform="macos"
  ;;
esac

filename="dartsdk-$platform-x64-release.zip"

curl -o "$filename" "https://storage.googleapis.com/dart-archive/channels/dev/release/latest/sdk/dartsdk-$platform-x64-release.zip"
unzip "$filename"
rm "$filename"

cat <<EOF >analysis-server-dart-snapshot
#!/usr/bin/env bash
DIR=\$(cd \$(dirname \$0); pwd)/dart-sdk
\$DIR/bin/dart \$DIR/bin/snapshots/analysis_server.dart.snapshot --lsp \$*
EOF

chmod +x analysis-server-dart-snapshot
