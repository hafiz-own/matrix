#!/usr/bin/env bash
# __     __         _ 
# \ \   / /_ _ ____(_)
#  \ \ / / _` |_  / | 
#   \ V / (_| |/ /| | 
#    \_/ \__,_/___|_| 
#                     

# DESC: Compiles and installs llama.cpp globally with Vulkan hardware acceleration

set -Eeuo pipefail
trap 'echo -e "\e[31m[!] Error: Script failed on line $LINENO\e[0m" >&2' ERR

info()    { echo -e "\e[34m[*]\e[0m $1"; }
warn()    { echo -e "\e[33m[!]\e[0m $1"; }
die()     { echo -e "\e[31m[✘]\e[0m $1" >&2; exit 1; }
success() { echo -e "\e[32m[✔]\e[0m $1"; }

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Compiles llama.cpp from source with Vulkan (GGML_VULKAN) enabled for 
maximum iGPU/dGPU offloading, and installs it to /opt/llama.cpp.

Options:
  -h, --help    Show this help message and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

set +e
sleep 1
clear
figlet -f smslant "Llama.cpp Setup"

if ! gum confirm "Compile and install llama.cpp (Vulkan Backend)?"; then
    echo ":: Installation canceled."
    exit 0
fi
set -e

info "Installing build dependencies..."
paru -S --needed --noconfirm base-devel cmake git ninja \
    vulkan-headers vulkan-icd-loader vulkan-tools shaderc \
    spirv-headers spirv-tools vulkan-intel nvidia-utils

info "Verifying Vulkan device visibility..."
if vulkaninfo --summary 2>/dev/null | grep -qi "deviceName"; then
    vulkaninfo --summary | grep -i "deviceName"
else
    warn "Could not confirm devices via vulkaninfo, continuing anyway..."
fi

info "Preparing temporary build workspace..."
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

info "Cloning llama.cpp source code..."
git clone https://github.com/ggml-org/llama.cpp .

info "Configuring CMake build (Vulkan backend, Release)..."
cmake -B build -G Ninja -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release

info "Compiling utilizing all $(nproc) threads..."
cmake --build build --config Release -j"$(nproc)"

info "Installing via CMake to /opt/llama.cpp..."
sudo rm -rf /opt/llama.cpp
sudo cmake --install build --prefix /opt/llama.cpp

info "Configuring dynamic linker for llama.cpp libraries..."
echo "/opt/llama.cpp/lib" | sudo tee /etc/ld.so.conf.d/llamacpp.conf > /dev/null
echo "/opt/llama.cpp/lib64" | sudo tee -a /etc/ld.so.conf.d/llamacpp.conf > /dev/null
sudo ldconfig

info "Creating global symlinks in /usr/local/bin..."
sudo mkdir -p /usr/local/bin
for bin in /opt/llama.cpp/bin/llama-*; do
    if [[ -x "$bin" && -f "$bin" ]]; then
        sudo ln -sf "$bin" "/usr/local/bin/$(basename "$bin")"
    fi
done

info "Cleaning up build workspace..."
cd "$HOME"
rm -rf "$TMP_DIR"

success "llama.cpp installed successfully!"
echo -e "\n\e[32m[✔]\e[0m You can now run \e[1mllama-cli --list-devices\e[0m anywhere!"
gum spin --spinner dot --title "Done!" -- sleep 2
