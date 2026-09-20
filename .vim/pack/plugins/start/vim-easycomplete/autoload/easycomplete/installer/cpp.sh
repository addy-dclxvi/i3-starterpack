#!/usr/bin/env bash

set -e

# On MacOS, use clangd in Command Line Tools for Xcode.
if command -v xcrun 2>/dev/null && xcrun --find clangd 2>/dev/null; then
  cat <<'EOF' >clangd
#!/usr/bin/env bash
exec xcrun --run clangd "$@"
EOF
  chmod +x clangd
  exit
fi

if command -v lsb_release 2>/dev/null; then
  distributor_id=$(lsb_release -a 2>&1 | grep 'Distributor ID' | awk '{print $3}')
elif [ -e /etc/fedora-release ]; then
  distributor_id="Fedora"
elif [ -e /etc/redhat-release ]; then
  distributor_id=$(cat /etc/redhat-release | cut -d ' ' -f 1)
elif [ -e /etc/arch-release ]; then
  distributor_id="Arch"
elif [ -e /etc/SuSE-release ]; then
  distributor_id="SUSE"
elif [ -e /etc/mandriva-release ]; then
  distributor_id="Mandriva"
elif [ -e /etc/vine-release ]; then
  distributor_id="Vine"
elif [ -e /etc/gentoo-release ]; then
  distributor_id="Gentoo"
else
  distributor_id="Unknown"
fi

filename() {
  local distributor_id=$1
  local version=$2

  local os
  os=$(uname -s | tr "[:upper:]" "[:lower:]")

  case $os in
  linux)
    local platform="pc-linux-gnu"
    ;;
  darwin)
    local platform="apple-darwin"
    ;;
  esac

  case $distributor_id in
  # Check Ubuntu version
  Ubuntu)
    local ubuntu_version
    ubuntu_version=$(lsb_release -a 2>&1 | grep 'Release' | awk '{print $2}')
    case $ubuntu_version in
    14.04 | 16.04 | 18.04 | 20.04)
      local platform="linux-gnu-ubuntu-$ubuntu_version"
      ;;
    esac
    ;;
  # Check LinuxMint version
  LinuxMint)
    local linuxmint_version
    linuxmint_version=$(lsb_release -a 2>&1 | grep 'Release' | awk '{print $2}')
    case $linuxmint_version in
    19 | 19.1 | 19.2 | 19.3)
      local platform="linux-gnu-ubuntu-18.04"
      ;;
    18 | 18.1 | 18.2 | 18.3)
      local platform="linux-gnu-ubuntu-16.04"
      ;;
    esac
    ;;
  # Check RedHat OS version
  Fedora | Oracle | CentOS)
    case $version in
    9.0.0 | 10.0.0)
      local platform="linux-sles11.3"
      ;;
    11.0.0)
      local platform="linux-sles12.4"
      ;;
    esac
    ;;
  esac

  # Check Architecture
  local arch
  arch=$(uname -m)
  case $arch in
  aarch64)
    local platform="linux-gnu"
    ;;
  esac

  echo "clang+llvm-$version-$arch-$platform"
}

filename_v9="$(filename "$distributor_id" '9.0.0')"
url_v9="http://releases.llvm.org/9.0.0/$filename_v9.tar.xz"
filename_v10="$(filename "$distributor_id" '10.0.0')"
url_v10="https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/$filename_v10.tar.xz"
filename_v11="$(filename "$distributor_id" '11.0.0')"
url_v11="https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/$filename_v11.tar.xz"

response_code=$(curl -sIL "${url_v11}" -o /dev/null -w "%{response_code}")

if [ "${response_code}" == "404" ]; then
  response_code=$(curl -sIL "${url_v10}" -o /dev/null -w "%{response_code}")

  if [ "${response_code}" == "404" ]; then
    url="${url_v9}"
    filename="${filename_v9}"
  else
    url="${url_v10}"
    filename="${filename_v10}"
  fi
else
  url="${url_v11}"
  filename="${filename_v11}"
fi

echo "Downloading clangd and LLVM..."
curl -L "$url" | unxz | tar x --strip-components=1 "$filename"/
ln -sf bin/clangd .
./clangd --version
