#!/usr/bin/env bash

set -e

curl -L "http://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz" | tar zx
curl -o lombok.jar 'https://projectlombok.org/downloads/lombok.jar'


osType="$(uname -s)"
case "${osType}" in
Darwin*) configDir=config_mac ;;
Linux*) configDir=config_linux ;;
*) configDir=config_linux ;;
esac

cat <<EOF >eclipse-jdt-ls
#!/usr/bin/env bash
DIR=\$(cd \$(dirname \$0); pwd)
LAUNCHER=\$(ls \$DIR/plugins/org.eclipse.equinox.launcher_*.jar)

java \
  -Declipse.application=org.eclipse.jdt.ls.core.id1 \
  -Dosgi.bundles.defaultStartLevel=4 \
  -Declipse.product=org.eclipse.jdt.ls.core.product \
  -Dlog.level=ALL \
  -noverify \
  -Xmx1G \
  --add-modules=ALL-SYSTEM \
  --add-opens java.base/java.util=ALL-UNNAMED \
  --add-opens java.base/java.lang=ALL-UNNAMED \
  -jar \$LAUNCHER \
  -configuration \$DIR/$configDir \
  -data ./ \
  -javaagent:\$DIR/lombok.jar \
  --add-modules=ALL-SYSTEM --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED \
  -XX:+AggressiveOpts \
  -XX:PermSize=512m -XX:MaxPermSize=512m \
  -Xmx2048m \
  -Xms512m \
  -Xmn512m \
  -Xss2m \
  -XX:+UseG1GC \
  -XX:+UseLargePages
EOF

chmod +x eclipse-jdt-ls

