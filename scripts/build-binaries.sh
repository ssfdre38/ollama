#!/usr/bin/env bash
#
# Build Ollama CE binaries for multiple platforms
#

set -e

OUTPUT_DIR="dist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

get_version() {
    local version_file="version/version.go"
    if [[ -f "$version_file" ]]; then
        version=$(grep 'Version string =' "$version_file" | sed 's/.*"\(.*\)".*/\1/')
        echo "$version"
    else
        echo "Error: Could not find $version_file" >&2
        exit 1
    fi
}

# Get version
VERSION=$(get_version)
print_color "$CYAN" "Building Ollama CE v$VERSION binaries..."

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Build targets: OS ARCH EXTENSION NAME
targets=(
    "windows amd64 .exe Windows x64"
    "linux amd64 '' Linux x64"
    "darwin amd64 '' macOS x64"
    "darwin arm64 '' macOS ARM64"
)

for target in "${targets[@]}"; do
    read -r os arch ext name <<< "$target"
    
    output_name="ollama-${VERSION}-${os}-${arch}${ext}"
    output_path="$OUTPUT_DIR/$output_name"
    
    print_color "$YELLOW" "\nBuilding $name..."
    
    export GOOS=$os
    export GOARCH=$arch
    export CGO_ENABLED=0  # Static binary
    
    # Run go generate first
    print_color "$GRAY" "  Running go generate..."
    go generate ./... > /dev/null 2>&1 || true
    
    # Build the binary
    print_color "$GRAY" "  Compiling binary..."
    if go build -ldflags "-s -w" -o "$output_path" .; then
        size=$(du -h "$output_path" | cut -f1)
        print_color "$GREEN" "  ✓ Built: $output_name ($size)"
        
        # Create ZIP archive
        zip_name="ollama-ce-${VERSION}-${os}-${arch}.zip"
        zip_path="$OUTPUT_DIR/$zip_name"
        
        # Create temporary directory for archive contents
        temp_dir="$OUTPUT_DIR/temp_${os}_${arch}"
        mkdir -p "$temp_dir"
        
        # Copy binary
        cp "$output_path" "$temp_dir/"
        
        # Copy additional files
        [[ -f "README.md" ]] && cp "README.md" "$temp_dir/"
        [[ -f "LICENSE" ]] && cp "LICENSE" "$temp_dir/"
        
        # Create installation README
        cat > "$temp_dir/INSTALL.txt" << EOF
Ollama Community Edition v$VERSION
===================================

Installation:
1. Extract this archive
2. Move the ollama executable to your PATH:
   - Windows: C:\Program Files\Ollama-CE\\
   - Linux/macOS: /usr/local/bin/ or ~/.local/bin/

3. Run 'ollama serve' to start the server
4. In another terminal, use 'ollama run <model>' to download and run models

Examples:
  ollama run llama3.2
  ollama run qwen2.5-coder
  ollama run mistral

For more information, visit:
  https://github.com/ssfdre38/ollama/tree/community-edition

EOF
        
        # Create ZIP
        print_color "$GRAY" "  Creating archive..."
        (cd "$temp_dir" && zip -q -r "../$zip_name" .)
        
        # Clean up temp directory and raw binary
        rm -rf "$temp_dir"
        rm -f "$output_path"
        
        zip_size=$(du -h "$zip_path" | cut -f1)
        print_color "$GREEN" "  ✓ Archived: $zip_name ($zip_size)"
    else
        print_color "$RED" "  ✗ Build failed for $name"
    fi
done

# Summary
print_color "$CYAN" "\n$(printf '=%.0s' {1..60})"
print_color "$CYAN" "Build Summary"
print_color "$CYAN" "$(printf '=%.0s' {1..60})"

for zip_file in "$OUTPUT_DIR"/*.zip; do
    if [[ -f "$zip_file" ]]; then
        size=$(du -h "$zip_file" | cut -f1)
        print_color "$NC" "  $(basename "$zip_file") - $size"
    fi
done

print_color "$GREEN" "\n✓ All binaries built successfully!"
print_color "$GRAY" "Output directory: $OUTPUT_DIR"
