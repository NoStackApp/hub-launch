#!/bin/sh
# HubLaunch (`hula`) standalone installer — no Node required.
#
# Installs the latest stable `hula` CLI as a self-contained binary. This is the
# curl install channel, advertised as:
#
#   curl -fsSL https://hublaunch.site/install.sh | sh
#
# Prefer to read before you run? (recommended) Download, review, then run:
#
#   curl -fsSL https://hublaunch.site/install.sh -o install.sh
#   less install.sh      # review it
#   sh install.sh
#
# The npm channel is unchanged and still available for Node users:
#
#   npm install -g hub-launch     # or: pnpm add -g hub-launch
#
# What this script does:
#   1. Detects your OS/arch and picks the matching standalone binary.
#   2. Downloads that binary and the release's SHA256SUMS manifest.
#   3. Verifies the binary against SHA256SUMS — a mismatch ABORTS and removes
#      the partial download (fail-closed; never "best effort").
#   4. Installs to ~/.hublaunch/bin (override with HULA_INSTALL_DIR), never sudo.
#   5. Installs the global Claude Code slash commands (~/.claude/commands/hula-*.md),
#      like the npm package's postinstall does.
#   6. Prints the PATH line to add if that directory isn't already on PATH.
#
# Environment overrides:
#   HULA_INSTALL_DIR            install location (default: ~/.hublaunch/bin)
#   HULA_RELEASE_REPO           GitHub repo to download from (default: NoStackApp/hub-launch)
#   HULA_SKIP_CLAUDE_COMMANDS=1 skip installing the global Claude Code slash commands
#
# SECURITY: These binaries are currently UNSIGNED. The one-time Gatekeeper
# (macOS) / SmartScreen (Windows) "allow anyway" step is described at the end.
# Signed/notarized binaries are a prerequisite for advertising this channel
# widely; until then, the checksum verification above is your integrity check.
#
# Dependencies: POSIX sh plus the ubiquitous curl, uname, mktemp, chmod, mv,
# and either sha256sum or shasum.

set -eu

# ── Configuration ───────────────────────────────────────────────────────────
REPO="${HULA_RELEASE_REPO:-NoStackApp/hub-launch}"
INSTALL_DIR="${HULA_INSTALL_DIR:-$HOME/.hublaunch/bin}"
BIN_NAME="hula"

# ── Output helpers ──────────────────────────────────────────────────────────
info() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }

# Cleanup state: TMPDIR_PATH is removed on any exit once set.
TMPDIR_PATH=""
cleanup() {
  [ -n "$TMPDIR_PATH" ] && rm -rf "$TMPDIR_PATH" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

abort() {
  err "$1"
  exit 1
}

# ── Detect OS/arch → asset name ───────────────────────────────────────────────
detect_asset() {
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin) os_tag="darwin" ;;
    Linux)  os_tag="linux" ;;
    *)
      abort "Unsupported OS '$os'. Install via npm instead: npm install -g hub-launch"
      ;;
  esac

  case "$arch" in
    arm64 | aarch64) arch_tag="arm64" ;;
    x86_64 | amd64)  arch_tag="x64" ;;
    *)
      abort "Unsupported architecture '$arch'. Install via npm instead: npm install -g hub-launch"
      ;;
  esac

  # Only the combinations we actually publish binaries for.
  case "${os_tag}-${arch_tag}" in
    darwin-arm64 | darwin-x64 | linux-x64 | linux-arm64)
      ASSET="hula-${os_tag}-${arch_tag}"
      ;;
    *)
      abort "No standalone binary is published for ${os_tag}/${arch_tag}. Install via npm instead: npm install -g hub-launch"
      ;;
  esac
}

# ── SHA-256 of a file (portable: sha256sum or shasum) ─────────────────────────
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    abort "Neither sha256sum nor shasum is available; cannot verify the download."
  fi
}

# Extract the expected digest for ASSET from a SHA256SUMS manifest. Tolerates
# the binary-mode "*" marker and a leading "./" on the filename.
expected_digest() {
  awk -v f="$ASSET" '
    {
      name = $2
      sub(/^\*/, "", name)
      sub(/^\.\//, "", name)
      if (name == f) { print $1; exit }
    }
  ' "$1"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  command -v curl >/dev/null 2>&1 || abort "curl is required but not found."

  detect_asset

  info "Installing the latest stable hula ($ASSET) from $REPO…"

  # GitHub's /releases/latest/download/<asset> always resolves to the newest
  # non-prerelease, non-draft release, so prereleases are skipped by design and
  # no JSON parsing is needed. The binary and the SHA256SUMS manifest come from
  # the same release.
  base_url="https://github.com/${REPO}/releases/latest/download"

  TMPDIR_PATH="$(mktemp -d "${TMPDIR:-/tmp}/hula-install.XXXXXX")"
  bin_tmp="${TMPDIR_PATH}/${ASSET}"
  sums_tmp="${TMPDIR_PATH}/SHA256SUMS"

  info "Downloading binary…"
  curl -fsSL "${base_url}/${ASSET}" -o "$bin_tmp" \
    || abort "Failed to download ${base_url}/${ASSET}. No stable release, or network error."

  info "Downloading checksums…"
  curl -fsSL "${base_url}/SHA256SUMS" -o "$sums_tmp" \
    || abort "Failed to download SHA256SUMS for the latest release."

  # ── Fail-closed checksum verification ──
  info "Verifying checksum…"
  expected="$(expected_digest "$sums_tmp")"
  [ -n "$expected" ] || abort "SHA256SUMS has no entry for ${ASSET}; refusing to install an unverifiable binary."

  actual="$(sha256_of "$bin_tmp")"
  if [ "$actual" != "$expected" ]; then
    err "Checksum verification FAILED — aborting (nothing was installed)."
    err "  expected $expected"
    err "  actual   $actual"
    exit 1
  fi
  info "Checksum OK."

  # ── Install (atomic, no sudo) ──
  if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
    abort "Could not create install directory '$INSTALL_DIR'. Set HULA_INSTALL_DIR to a writable path (never use sudo)."
  fi
  if [ ! -w "$INSTALL_DIR" ]; then
    abort "Install directory '$INSTALL_DIR' is not writable. Set HULA_INSTALL_DIR to a writable path (never use sudo)."
  fi

  chmod +x "$bin_tmp"
  target="${INSTALL_DIR}/${BIN_NAME}"
  # Stage within the destination dir so the final mv is atomic (same filesystem).
  staged="${INSTALL_DIR}/.${BIN_NAME}.download.$$"
  mv "$bin_tmp" "$staged"
  mv "$staged" "$target"

  info ""
  info "✓ Installed hula to $target"

  # ── Global Claude Code slash commands (the npm postinstall's job) ──
  if [ "${HULA_SKIP_CLAUDE_COMMANDS:-}" != "1" ]; then
    "$target" install-claude-commands \
      || warn "Could not install the Claude Code slash commands; run 'hula install-claude-commands' later."
  fi

  # ── PATH guidance ──
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*)
      info "  $INSTALL_DIR is already on your PATH."
      ;;
    *)
      info ""
      info "Add $INSTALL_DIR to your PATH by appending this line to your shell profile"
      info "(~/.zshrc, ~/.bashrc, or ~/.profile), then restart your shell:"
      info ""
      info "  export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac

  # ── Unsigned-binary note ──
  info ""
  info "NOTE: this binary is currently UNSIGNED."
  os="$(uname -s)"
  if [ "$os" = "Darwin" ]; then
    info "  macOS Gatekeeper may block it on first run. If so, allow it with:"
    info "    xattr -d com.apple.quarantine \"$target\" 2>/dev/null || true"
    info "  or open System Settings → Privacy & Security and click \"Allow Anyway\"."
  fi

  info ""
  info "Get started:"
  info "  hula init      # configure a project and log in"
  info ""
  info "Prefer the npm channel instead? npm install -g hub-launch (or pnpm add -g hub-launch)"
}

main "$@"
