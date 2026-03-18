#!/usr/bin/env bash
set -euo pipefail

# Ollama Community Edition Installation Script for Linux/macOS
# Version: 1.0.0
# Author: OpenClaw Community

# Configuration
INSTALL_PATH="${OLLAMA_INSTALL_PATH:-$HOME/.ollama-ce}"
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

# Colors
COLOR_RESET='\033[0m'
COLOR_HEADER='\033[1;36m'
COLOR_SUCCESS='\033[1;32m'
COLOR_WARNING='\033[1;33m'
COLOR_ERROR='\033[1;31m'
COLOR_INFO='\033[0;37m'

# Helper functions
print_header() {
    echo ""
    echo -e "${COLOR_HEADER}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_HEADER}  $1${COLOR_RESET}"
    echo -e "${COLOR_HEADER}══════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

print_step() {
    echo -e "${COLOR_INFO}▶ $1${COLOR_RESET}"
}

print_success() {
    echo -e "${COLOR_SUCCESS}✓ $1${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_WARNING}⚠ $1${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_ERROR}✗ $1${COLOR_RESET}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$NON_INTERACTIVE" = "true" ]; then
        [ "$default" = "y" ] && return 0 || return 1
    fi
    
    local answer
    if [ "$default" = "y" ]; then
        read -r -p "$prompt (Y/n): " answer
        answer=${answer:-y}
    else
        read -r -p "$prompt (y/N): " answer
        answer=${answer:-n}
    fi
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

install_ollama_ce() {
    print_header "Installing Ollama Community Edition"
    
    print_step "Installation path: $INSTALL_PATH"
    
    if [ -d "$INSTALL_PATH" ]; then
        print_warning "Ollama CE directory already exists: $INSTALL_PATH"
        
        if ask_yes_no "Do you want to update it?"; then
            cd "$INSTALL_PATH" || exit 1
            git pull origin community-edition
            cd - >/dev/null || exit 1
            print_success "Ollama CE updated"
        else
            print_info "Installation cancelled"
            exit 0
        fi
    else
        print_step "Cloning Ollama CE from GitHub..."
        
        if git clone --depth 1 --branch community-edition https://github.com/ssfdre38/ollama.git "$INSTALL_PATH"; then
            print_success "Ollama CE cloned"
        else
            print_error "Failed to clone Ollama CE"
            exit 1
        fi
    fi
    
    cd "$INSTALL_PATH" || exit 1
    
    print_step "Building Ollama CE..."
    print_warning "This may take several minutes..."
    
    # Check if Go is installed
    if ! command_exists go; then
        print_error "Go is required to build Ollama CE"
        echo -e "${COLOR_INFO}Please install Go from: https://go.dev/dl/${COLOR_RESET}"
        echo -e "${COLOR_INFO}After installing Go, run this script again or build manually:${COLOR_RESET}"
        echo -e "${COLOR_INFO}  cd $INSTALL_PATH${COLOR_RESET}"
        echo -e "${COLOR_INFO}  go generate ./.${COLOR_RESET}"
        echo -e "${COLOR_INFO}  go build .${COLOR_RESET}"
        cd - >/dev/null || exit 1
        exit 1
    fi
    
    # Generate and build
    print_step "Generating dependencies..."
    if ! go generate ./...; then
        print_error "Generate failed"
        cd - >/dev/null || exit 1
        exit 1
    fi
    
    print_step "Compiling Ollama CE..."
    if ! go build .; then
        print_error "Build failed"
        cd - >/dev/null || exit 1
        exit 1
    fi
    
    print_success "Ollama CE built successfully"
    
    cd - >/dev/null || exit 1
}

show_next_steps() {
    print_header "Installation Complete!"
    
    echo -e "${COLOR_SUCCESS}Ollama CE has been installed to:${COLOR_RESET}"
    echo -e "${COLOR_INFO}  $INSTALL_PATH${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_HEADER}Next steps:${COLOR_RESET}"
    echo -e "${COLOR_INFO}  1. Start Ollama CE server:${COLOR_RESET}"
    echo -e "${COLOR_INFO}     $INSTALL_PATH/ollama serve${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_INFO}  2. Pull a model (in a new terminal):${COLOR_RESET}"
    echo -e "${COLOR_INFO}     $INSTALL_PATH/ollama pull llama3.2${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_INFO}  3. Test the model:${COLOR_RESET}"
    echo -e "${COLOR_INFO}     $INSTALL_PATH/ollama run llama3.2${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_HEADER}Add to PATH (optional):${COLOR_RESET}"
    echo -e "${COLOR_INFO}  Add to your ~/.bashrc or ~/.zshrc:${COLOR_RESET}"
    echo -e "${COLOR_INFO}    export PATH=\"$INSTALL_PATH:\$PATH\"${COLOR_RESET}"
    echo -e "${COLOR_INFO}  Then you can use 'ollama' from anywhere${COLOR_RESET}"
    echo ""
    
    echo -e "${COLOR_HEADER}For more information:${COLOR_RESET}"
    echo -e "${COLOR_INFO}  https://github.com/ssfdre38/ollama/tree/community-edition${COLOR_RESET}"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --help)
            echo "Ollama Community Edition Installer"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --non-interactive      Run in non-interactive mode"
            echo "  --install-path PATH    Custom installation path (default: ~/.ollama-ce)"
            echo "  --help                 Show this help message"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main installation flow
main() {
    print_header "Ollama Community Edition Installer"
    
    echo -e "${COLOR_INFO}This script will install Ollama CE on your system.${COLOR_RESET}"
    echo ""
    
    # Check Git
    print_step "Checking Git..."
    if ! command_exists git; then
        print_error "Git is required but not installed"
        echo -e "${COLOR_INFO}Please install Git from: https://git-scm.com/downloads${COLOR_RESET}"
        exit 1
    fi
    print_success "Git is installed"
    
    # Check Go
    print_step "Checking Go..."
    if ! command_exists go; then
        print_warning "Go is not installed"
        
        echo -e "${COLOR_INFO}Ollama CE requires Go to build.${COLOR_RESET}"
        
        if [ "$(uname)" = "Darwin" ]; then
            echo -e "${COLOR_INFO}Install with: brew install go${COLOR_RESET}"
        else
            echo -e "${COLOR_INFO}Install from: https://go.dev/dl/${COLOR_RESET}"
        fi
        
        if ask_yes_no "Have you installed Go?"; then
            if ! command_exists go; then
                print_error "Go still not found in PATH"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    local go_version
    go_version=$(go version)
    print_success "Go is installed ($go_version)"
    
    # Install Ollama CE
    install_ollama_ce
    
    # Show next steps
    show_next_steps
}

# Run main function
main
