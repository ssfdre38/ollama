#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Ollama Community Edition Installation Script for Windows
.DESCRIPTION
    Standalone installer for Ollama CE with custom enhancements
.NOTES
    Version: 1.0.0
    Author: OpenClaw Community
#>

param(
    [switch]$NonInteractive,
    [string]$InstallPath = "$env:USERPROFILE\.ollama-ce"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors
$ColorHeader = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "White"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor $ColorHeader
    Write-Host "  $Message" -ForegroundColor $ColorHeader
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor $ColorHeader
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor $ColorInfo
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $ColorSuccess
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $ColorWarning
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $ColorError
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Install-OllamaCE {
    Write-Header "Installing Ollama Community Edition"
    
    Write-Step "Installation path: $InstallPath"
    
    if (Test-Path $InstallPath) {
        Write-Warning "Ollama CE directory already exists: $InstallPath"
        
        if (-not $NonInteractive) {
            $response = Read-Host "Do you want to update it? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Push-Location $InstallPath
                git pull origin community-edition
                Pop-Location
                Write-Success "Ollama CE updated"
            } else {
                Write-Host "Installation cancelled" -ForegroundColor $ColorInfo
                exit 0
            }
        } else {
            Write-Warning "Directory exists. Update with: cd $InstallPath && git pull"
            exit 0
        }
    } else {
        Write-Step "Cloning Ollama CE from GitHub..."
        
        try {
            git clone --depth 1 --branch community-edition https://github.com/ssfdre38/ollama.git $InstallPath
            Write-Success "Ollama CE cloned"
        } catch {
            Write-Error-Message "Failed to clone Ollama CE: $_"
            exit 1
        }
    }
    
    Push-Location $InstallPath
    
    try {
        Write-Step "Building Ollama CE..."
        Write-Warning "This may take several minutes..."
        
        # Check if Go is installed
        if (-not (Test-CommandExists "go")) {
            Write-Error-Message "Go is required to build Ollama CE"
            Write-Host "Please install Go from: https://go.dev/dl/" -ForegroundColor $ColorInfo
            Write-Host "After installing Go, run this script again or build manually:" -ForegroundColor $ColorInfo
            Write-Host "  cd $InstallPath" -ForegroundColor $ColorInfo
            Write-Host "  go generate ./..." -ForegroundColor $ColorInfo
            Write-Host "  go build ." -ForegroundColor $ColorInfo
            Pop-Location
            exit 1
        }
        
        # Generate and build
        Write-Step "Generating dependencies..."
        go generate ./...
        
        Write-Step "Compiling Ollama CE..."
        go build .
        
        Write-Success "Ollama CE built successfully"
        
    } catch {
        Write-Error-Message "Build failed: $_"
        Pop-Location
        exit 1
    } finally {
        Pop-Location
    }
}

function Show-NextSteps {
    Write-Header "Installation Complete!"
    
    Write-Host "Ollama CE has been installed to:" -ForegroundColor $ColorSuccess
    Write-Host "  $InstallPath" -ForegroundColor $ColorInfo
    Write-Host ""
    
    Write-Host "Next steps:" -ForegroundColor $ColorHeader
    Write-Host "  1. Start Ollama CE server:" -ForegroundColor $ColorInfo
    Write-Host "     $InstallPath\ollama.exe serve" -ForegroundColor $ColorInfo
    Write-Host ""
    Write-Host "  2. Pull a model (in a new terminal):" -ForegroundColor $ColorInfo
    Write-Host "     $InstallPath\ollama.exe pull llama3.2" -ForegroundColor $ColorInfo
    Write-Host ""
    Write-Host "  3. Test the model:" -ForegroundColor $ColorInfo
    Write-Host "     $InstallPath\ollama.exe run llama3.2" -ForegroundColor $ColorInfo
    Write-Host ""
    
    Write-Host "Add to PATH (optional):" -ForegroundColor $ColorHeader
    Write-Host "  Add '$InstallPath' to your PATH environment variable" -ForegroundColor $ColorInfo
    Write-Host "  Then you can use 'ollama' from anywhere" -ForegroundColor $ColorInfo
    Write-Host ""
    
    Write-Host "For more information:" -ForegroundColor $ColorHeader
    Write-Host "  https://github.com/ssfdre38/ollama/tree/community-edition" -ForegroundColor $ColorInfo
    Write-Host ""
}

# Main installation flow
try {
    Write-Header "Ollama Community Edition Installer"
    
    Write-Host "This script will install Ollama CE on your system." -ForegroundColor $ColorInfo
    Write-Host ""
    
    # Check Git
    Write-Step "Checking Git..."
    if (-not (Test-CommandExists "git")) {
        Write-Error-Message "Git is required but not installed"
        Write-Host "Please install Git from: https://git-scm.com/download/win" -ForegroundColor $ColorInfo
        exit 1
    }
    Write-Success "Git is installed"
    
    # Check Go
    Write-Step "Checking Go..."
    if (-not (Test-CommandExists "go")) {
        Write-Warning "Go is not installed"
        
        if (-not $NonInteractive) {
            $response = Read-Host "Ollama CE requires Go to build. Open download page? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Start-Process "https://go.dev/dl/"
                Write-Host "Please install Go and run this script again." -ForegroundColor $ColorInfo
                exit 0
            }
        }
        
        Write-Error-Message "Go is required to build Ollama CE"
        Write-Host "Install from: https://go.dev/dl/" -ForegroundColor $ColorInfo
        exit 1
    }
    
    $goVersion = go version
    Write-Success "Go is installed ($goVersion)"
    
    # Install Ollama CE
    Install-OllamaCE
    
    # Show next steps
    Show-NextSteps
    
} catch {
    Write-Error-Message "Installation failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor $ColorError
    exit 1
}
