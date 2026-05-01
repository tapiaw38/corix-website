#!/usr/bin/env sh
set -eu

APP_NAME="coren"
SERVER_BIN="coren-proxi"
CLI_BIN="corend"
ALIAS_BIN="cor"

RELEASES_BASE_URL="${RELEASES_BASE_URL:-https://github.com/tapiaw38/coren-website/releases}"
VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-}"
CHECKSUMS_FILE="SHA256SUMS"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

detect_os() {
  os="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux|darwin) printf '%s\n' "$os" ;;
    *)
      echo "error: unsupported operating system: $os" >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  arch="$(uname -m 2>/dev/null)"
  case "$arch" in
    x86_64|amd64) printf 'amd64\n' ;;
    arm64|aarch64) printf 'arm64\n' ;;
    *)
      echo "error: unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac
}

detect_shell() {
  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh|bash) printf '%s\n' "$shell_name" ;;
    *) printf 'zsh\n' ;;
  esac
}

default_install_dir() {
  if [ -n "${INSTALL_DIR}" ]; then
    printf '%s\n' "$INSTALL_DIR"
    return
  fi

  if [ -t 0 ] && [ -t 1 ]; then
    printf '%s\n' "$HOME/.local/bin"
  else
    printf '%s\n' "$HOME/.local/bin"
  fi
}

prompt_install_dir() {
  default_dir="$HOME/.local/bin"
  system_dir="/usr/local/bin"

  if [ ! -t 0 ] || [ ! -t 1 ]; then
    printf '%s\n' "$default_dir"
    return
  fi

  printf '%s\n' "Install location:"
  printf '%s\n' "  1) $default_dir (user, no sudo)"
  printf '%s\n' "  2) $system_dir (system-wide, may need sudo)"
  printf '%s' "Choose [1/2] (default 1): "
  read answer || answer=""

  case "${answer:-1}" in
    2) printf '%s\n' "$system_dir" ;;
    *) printf '%s\n' "$default_dir" ;;
  esac
}

build_download_url() {
  os="$1"
  arch="$2"
  bundle="coren_${os}_${arch}.tar.gz"

  if [ "$VERSION" = "latest" ]; then
    printf '%s\n' "${RELEASES_BASE_URL}/latest/download/${bundle}"
  else
    printf '%s\n' "${RELEASES_BASE_URL}/download/${VERSION}/${bundle}"
  fi
}

build_checksums_url() {
  if [ "$VERSION" = "latest" ]; then
    printf '%s\n' "${RELEASES_BASE_URL}/latest/download/${CHECKSUMS_FILE}"
  else
    printf '%s\n' "${RELEASES_BASE_URL}/download/${VERSION}/${CHECKSUMS_FILE}"
  fi
}

download_file() {
  url="$1"
  out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
    return
  fi

  echo "error: curl or wget is required" >&2
  exit 1
}

sha256_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s\n' "sha256sum"
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    printf '%s\n' "shasum -a 256"
    return
  fi

  echo "error: sha256sum or shasum is required for checksum verification" >&2
  exit 1
}

verify_checksum() {
  archive_path="$1"
  checksums_path="$2"
  archive_name="$3"
  checksum_tool="$(sha256_cmd)"

  expected_line="$(grep "  ${archive_name}\$" "$checksums_path" || true)"
  if [ -z "$expected_line" ]; then
    echo "error: checksum entry not found for $archive_name" >&2
    exit 1
  fi

  expected_sum="$(printf '%s\n' "$expected_line" | awk '{print $1}')"
  actual_sum="$(sh -c "$checksum_tool \"$archive_path\"" | awk '{print $1}')"

  if [ "$expected_sum" != "$actual_sum" ]; then
    echo "error: checksum verification failed for $archive_name" >&2
    exit 1
  fi
}

is_in_path() {
  dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_path_in_rc() {
  rc_file="$1"
  dir="$2"

  if grep -Fq "export PATH=\"$dir:\$PATH\"" "$rc_file" 2>/dev/null; then
    echo "PATH already configured in $rc_file"
    return
  fi

  {
    printf '\n'
    printf '# coren\n'
    printf 'export PATH="%s:$PATH"\n' "$dir"
  } >> "$rc_file"

  echo "Added PATH to $rc_file"
}

install_one() {
  src="$1"
  dst="$2"

  if [ -w "$INSTALL_TARGET" ]; then
    install -m755 "$src" "$dst"
  else
    need_cmd sudo
    sudo install -m755 "$src" "$dst"
  fi
}

link_alias() {
  target="$1"
  alias_path="$2"

  if [ -w "$INSTALL_TARGET" ]; then
    ln -sf "$target" "$alias_path"
  else
    need_cmd sudo
    sudo ln -sf "$target" "$alias_path"
  fi
}

need_cmd uname
need_cmd tar
need_cmd mktemp
need_cmd install

OS="$(detect_os)"
ARCH="$(detect_arch)"
URL="$(build_download_url "$OS" "$ARCH")"
CHECKSUMS_URL="$(build_checksums_url)"
BUNDLE_NAME="coren_${OS}_${ARCH}.tar.gz"

if [ -z "${INSTALL_DIR}" ]; then
  INSTALL_TARGET="$(prompt_install_dir)"
else
  INSTALL_TARGET="$(default_install_dir)"
fi

TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="$TMP_DIR/coren.tar.gz"
CHECKSUMS_PATH="$TMP_DIR/$CHECKSUMS_FILE"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

echo "Downloading bundle:"
echo "  $URL"
download_file "$URL" "$ARCHIVE_PATH"

echo "Downloading checksums:"
echo "  $CHECKSUMS_URL"
download_file "$CHECKSUMS_URL" "$CHECKSUMS_PATH"

echo "Verifying checksum for $BUNDLE_NAME"
verify_checksum "$ARCHIVE_PATH" "$CHECKSUMS_PATH" "$BUNDLE_NAME"

tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"

for bin in "$APP_NAME" "$SERVER_BIN" "$CLI_BIN"; do
  if [ ! -f "$TMP_DIR/$bin" ]; then
    echo "error: bundle is missing $bin" >&2
    exit 1
  fi
done

if [ -w "$INSTALL_TARGET" ]; then
  mkdir -p "$INSTALL_TARGET"
else
  need_cmd sudo
  sudo mkdir -p "$INSTALL_TARGET"
fi

install_one "$TMP_DIR/$APP_NAME" "$INSTALL_TARGET/$APP_NAME"
install_one "$TMP_DIR/$SERVER_BIN" "$INSTALL_TARGET/$SERVER_BIN"
install_one "$TMP_DIR/$CLI_BIN" "$INSTALL_TARGET/$CLI_BIN"
link_alias "$INSTALL_TARGET/$APP_NAME" "$INSTALL_TARGET/$ALIAS_BIN"

echo ""
echo "Installed:"
echo "  $INSTALL_TARGET/$APP_NAME"
echo "  $INSTALL_TARGET/$SERVER_BIN"
echo "  $INSTALL_TARGET/$CLI_BIN"
echo "  $INSTALL_TARGET/$ALIAS_BIN -> $INSTALL_TARGET/$APP_NAME"

RC_PATH="$HOME/.$(detect_shell)rc"

if is_in_path "$INSTALL_TARGET"; then
  echo ""
  echo "PATH already includes $INSTALL_TARGET"
elif [ -t 0 ] && [ -t 1 ]; then
  echo ""
  printf '%s' "Add $INSTALL_TARGET to PATH in $RC_PATH? [Y/n]: "
  read answer || answer=""
  case "${answer:-y}" in
    y|Y|yes|YES|"")
      ensure_path_in_rc "$RC_PATH" "$INSTALL_TARGET"
      echo "Run: source $RC_PATH"
      ;;
    *)
      echo "Skipped PATH update. Add $INSTALL_TARGET to PATH manually."
      ;;
  esac
fi

echo ""
echo "Next steps:"
echo "  1. corend init"
echo "  2. coren"
