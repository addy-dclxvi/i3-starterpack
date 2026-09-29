#!/usr/bin/env fish

# Base path for your plugins
set PLUGIN_DIR "$HOME/.vim/pack/plugins/start"

echo "Sweeping plugins..."

# 1. Force remove all hidden Git, GitHub, and CI/CD directories
find "$PLUGIN_DIR" -type d \( -name ".git" -o -name ".github" -o -name ".circleci" -o -name ".codex" \) -prune -exec rm -rf {} +

# 2. Force remove specific hidden developer configuration files
find "$PLUGIN_DIR" -type f \( \
    -name ".gitignore" -o \
    -name ".gitattributes" -o \
    -name ".gitkeep" -o \
    -name ".editorconfig" -o \
    -name ".luacheckrc" -o \
    -name ".luarc.json" -o \
    -name ".vintrc.yaml" -o \
    -name "FUNDING.yml" \
\) -delete

# 3. Remove all Markdown (READMEs, guides) and License files
find "$PLUGIN_DIR" -type f -iname "*.md" -delete
find "$PLUGIN_DIR" -type f -iname "*.markdown" -delete
find "$PLUGIN_DIR" -type f -iname "license*" -delete

# 4. Remove test and development directories/files specifically from ALE
rm -rf "$PLUGIN_DIR/ale/test"
rm -rf "$PLUGIN_DIR/ale/docker"
rm -f "$PLUGIN_DIR/ale/Dockerfile"
rm -f "$PLUGIN_DIR/ale/dockerignore.txt"
rm -f "$PLUGIN_DIR/ale/run-tests"
rm -f "$PLUGIN_DIR/ale/run-tests.bat"

# 5. Remove media and unnecessary files from Colorizer
rm -f "$PLUGIN_DIR/colorizer/Colorizer.gif"
rm -f "$PLUGIN_DIR/colorizer/screenshot.png"
rm -f "$PLUGIN_DIR/colorizer/todo"
rm -f "$PLUGIN_DIR/colorizer/Colorizer.vmb"
rm -f "$PLUGIN_DIR/colorizer/Makefile"

# 6. Remove miscellaneous plugin artifacts
rm -f "$PLUGIN_DIR/vim-which-key/_config.yml"

# 7. Clean up the leftover text dumps (both local and in .vim)
rm -f "$HOME/.vim/content.txt"
rm -f "$HOME/.vim/content_2.txt"
rm -f "$HOME/.vim/content_3.txt"
rm -f content.txt
rm -f content_2.txt
rm -f content_3.txt

echo "Plugin cleanup fully completed. Bloat removed, docs preserved!"
