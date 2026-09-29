#!/usr/bin/env bash

set -e

## EmmyLua
#version="0.3.6"
#curl -L -o EmmyLua-LS-all.jar "https://github.com/EmmyLua/EmmyLua-LanguageServer/releases/download/$version/EmmyLua-LS-all.jar"

#cat <<EOF >emmylua-ls
##!/usr/bin/env bash
#DIR=\$(cd \$(dirname \$0); pwd)
#java -cp \$DIR/EmmyLua-LS-all.jar com.tang.vscode.MainKt
#EOF

#chmod +x emmylua-ls


# On MacOS, use clangd in Command Line Tools for Xcode.

# --------------------------------------------------------------write config file
cat <<EOF >config.json
{
  "Lua": {
    "workspace.library": {
      "/usr/share/nvim/runtime/lua": true,
      "/usr/share/nvim/runtime/lua/vim": true,
      "/usr/share/nvim/runtime/lua/vim/lsp": true
    },
    "diagnostics": {
      "globals": [ "vim" , "use" , "use_rocks"]
    }
  },
  "sumneko-lua.enableNvimLuaDev": true
}
EOF

echo "write config.json ok."

user_root=$(echo $(pwd) | sed -e "s/\/.config.*$//g")
nvim_lsp_path="$user_root/.local/share/nvim/lsp_servers/sumneko_lua/extension/server/bin"

#---------------------------------------------------------------if
if test -x $nvim_lsp_path/lua-language-server; then
  echo "nvim_lsp_config detecting is ok."
cat <<EOF >sumneko-lua-language-server
#!/usr/bin/env bash
$nvim_lsp_path/lua-language-server -E -e LANG=en $nvim_lsp_path/main.lua \$*
EOF
  chmod +x sumneko-lua-language-server
  echo "install ready!"
  exit

# --------------------------------------------------------------else
else

os=$(uname -s | tr "[:upper:]" "[:lower:]")

version="2.6.6"

case $os in
linux)
  platform="linux-x64"
  ;;
darwin)
  platform="darwin-x64"
  ;;
esac

package_name="vscode-lua-v$version-$platform"

url="https://github.com/sumneko/vscode-lua/releases/download/v$version/$package_name.vsix"
echo "downloading $url"

asset="vscode-lua.vsix"

curl -L "$url" -o "$asset"
unzip "$asset"
rm "$asset"

chmod +x extension/server/bin/lua-language-server

cat <<EOF >sumneko-lua-language-server
#!/usr/bin/env bash
DIR=\$(cd \$(dirname \$0); pwd)/extension/server
\$DIR/bin/lua-language-server -E -e LANG=en \$DIR/main.lua \$*
EOF

chmod +x sumneko-lua-language-server

# --------------------------------------------------------------fi
fi
