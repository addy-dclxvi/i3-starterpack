#!/usr/bin/env bash

set -e

if  command -v nimlsp > /dev/null; then
  echo "install already"
else
  echo "nimlsp is installing"
  nimble -y --nimbledir=$(pwd) install nimlsp
  ln -s $(pwd)/bin/nimlsp .
  # nimble install nimlsp
fi

#cat <<EOF >nimlsp
##!/usr/bin/env bash
#DIR=\$(cd \$(dirname \$0); pwd)
#\$DIR/nimlsp \$*
#EOF

#chmod +x nimlsp
