#!/usr/bin/env bash
set -euo pipefail

service=$1
checkout=$2

if [[ ! -e "$checkout/.git" ]]; then
    echo "Missing $service checkout: $checkout. Set its path in Makefile.local." >&2
    exit 1
fi

platform=$(uname -s)

case "$platform" in
    Darwin)
        if ! xcode-select -p >/dev/null 2>&1 || ! command -v brew >/dev/null; then
            echo 'Install Xcode Command Line Tools with: xcode-select --install'
            echo 'Install Homebrew from https://brew.sh/, then rerun make.'
            exit 1
        fi
        ;;
    Linux) ;;
    *) echo 'Run Sentry and Relay on Linux or macOS.'; exit 1 ;;
esac

missing=()
tools=(git curl cmake cc pkg-config)
if [[ "$service" == sentry && "$platform" == Linux ]]; then
    tools+=(watchman)
fi
for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null || missing+=("$tool")
done
if ((${#missing[@]})); then
    echo "Missing tools: ${missing[*]}"
    if [[ "$platform" == Darwin ]]; then
        echo 'Run: brew install cmake pkg-config'
    else
        echo 'On Debian/Ubuntu, run:'
        echo '  sudo apt-get update'
        echo '  sudo apt-get install build-essential cmake curl git pkg-config libssl-dev python3-dev watchman'
        echo 'On other distributions, install equivalent packages.'
    fi
    echo 'Then rerun make.'
    exit 1
fi

if [[ "$service" == sentry ]]; then
    export SENTRY_EXTERNAL_CONTRIBUTOR=${SENTRY_EXTERNAL_CONTRIBUTOR:-1}
    if ! command -v uv >/dev/null; then
        echo 'Installing uv...'
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    if ! command -v devenv >/dev/null; then
        echo 'Installing Sentry devenv...'
        installer=$(mktemp -d)
        trap 'rm -rf "$installer"' EXIT
        curl -fsSLo "$installer/install-devenv.sh" https://raw.githubusercontent.com/getsentry/devenv/main/install-devenv.sh
        # use the public Git source and avoid an interactive login shell
        CI=1 bash "$installer/install-devenv.sh" </dev/null
    fi
    if [[ ! -f "$HOME/.config/sentry-devenv/config.ini" ]]; then
        devenv bootstrap
    fi
    if [[ "$platform" == Darwin ]]; then
        if [[ ! -d '/Applications/Google Chrome.app' ]]; then
            brew install --cask google-chrome
        fi
        if ! docker info >/dev/null 2>&1; then
            devenv colima start
        fi
    fi
    if ! docker info >/dev/null 2>&1; then
        echo 'Docker must be running and accessible as your regular user.'
        echo 'Install/start Docker: https://docs.docker.com/engine/install/'
        echo 'Then rerun make sentry.'
        exit 1
    fi
elif [[ "$service" == relay ]]; then
    if ! command -v rustup >/dev/null; then
        echo 'Installing rustup...'
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
    fi
    echo 'Updating stable Rust for Relay...'
    rustup toolchain install stable --profile minimal --no-self-update
else
    echo "Unknown service: $service"
    exit 1
fi

if [[ "$service" == sentry ]]; then
    cd "$checkout"
    devenv sync
fi
