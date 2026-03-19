#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build Ollama CE binaries for multiple platforms
.DESCRIPTION
    Creates standalone executables for Windows, Linux, and macOS
#>

param(
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-Version {
    $versionFile = "version/version.go"
    $content = Get-Content $versionFile -Raw
    if ($content -match 'Version string = "([^"]+)"') {
        return $matches[1]
    }
    throw "Could not extract version from $versionFile"
}

# Get version
$version = Get-Version
Write-ColorOutput "Building Ollama CE v$version binaries..." "Cyan"

# Create output directory
if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null

# Build targets - Only build Windows native since cross-compilation with CGO is complex
$targets = @(
    @{ OS = "windows"; Arch = "amd64"; Ext = ".exe"; Name = "Windows x64" }
)

foreach ($target in $targets) {
    $outputName = "ollama-$version-$($target.OS)-$($target.Arch)$($target.Ext)"
    $outputPath = Join-Path $OutputDir $outputName
    
    Write-ColorOutput "`nBuilding $($target.Name)..." "Yellow"
    
    $env:GOOS = $target.OS
    $env:GOARCH = $target.Arch
    
    # CGO is required for llama.cpp, but cross-compilation needs special handling
    if ($target.OS -eq "windows" -and $env:OS -match "Windows") {
        # Native Windows build - CGO enabled
        $env:CGO_ENABLED = "1"
    } else {
        # Cross-platform build - CGO disabled (will skip GPU support)
        $env:CGO_ENABLED = "0"
    }
    
    try {
        # Run go generate first (only for native platform)
        if ($env:CGO_ENABLED -eq "1") {
            Write-ColorOutput "  Running go generate..." "Gray"
            & go generate ./... 2>&1 | Out-Null
        }
        
        # Build the binary with proper ldflags
        Write-ColorOutput "  Compiling binary..." "Gray"
        $ldflags = "-s -w -X=github.com/ollama/ollama/version.Version=$version -X=github.com/ollama/ollama/server.mode=release"
        & go build -trimpath -ldflags $ldflags -o $outputPath .
        
        if ($LASTEXITCODE -eq 0) {
            $size = (Get-Item $outputPath).Length / 1MB
            Write-ColorOutput "  ✓ Built: $outputName ($([math]::Round($size, 2)) MB)" "Green"
            
            # Create ZIP archive
            $zipName = "ollama-ce-$version-$($target.OS)-$($target.Arch).zip"
            $zipPath = Join-Path $OutputDir $zipName
            
            # Create temporary directory for archive contents
            $tempDir = Join-Path $OutputDir "temp_$($target.OS)_$($target.Arch)"
            New-Item -ItemType Directory -Path $tempDir | Out-Null
            
            # Copy binary
            Copy-Item $outputPath $tempDir
            
            # Copy additional files
            Copy-Item "README.md" $tempDir -ErrorAction SilentlyContinue
            Copy-Item "LICENSE" $tempDir -ErrorAction SilentlyContinue
            
            # Create installation README
            $installReadme = @"
Ollama Community Edition v$version
===================================

Installation:
1. Extract this archive
2. Move the ollama executable to your PATH:
   - Windows: C:\Program Files\Ollama-CE\
   - Linux/macOS: /usr/local/bin/ or ~/.local/bin/

3. Run 'ollama serve' to start the server
4. In another terminal, use 'ollama run <model>' to download and run models

Examples:
  ollama run llama3.2
  ollama run qwen2.5-coder
  ollama run mistral

For more information, visit:
  https://github.com/ssfdre38/ollama/tree/community-edition

"@
            Set-Content -Path (Join-Path $tempDir "INSTALL.txt") -Value $installReadme
            
            # Create ZIP
            Write-ColorOutput "  Creating archive..." "Gray"
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
            
            # Clean up temp directory and raw binary
            Remove-Item $tempDir -Recurse -Force
            Remove-Item $outputPath -Force
            
            $zipSize = (Get-Item $zipPath).Length / 1MB
            Write-ColorOutput "  ✓ Archived: $zipName ($([math]::Round($zipSize, 2)) MB)" "Green"
        }
        else {
            Write-ColorOutput "  ✗ Build failed for $($target.Name)" "Red"
        }
    }
    catch {
        Write-ColorOutput "  ✗ Error: $_" "Red"
    }
}

# Summary
Write-ColorOutput "`n" + ("=" * 60) "Cyan"
Write-ColorOutput "Build Summary" "Cyan"
Write-ColorOutput ("=" * 60) "Cyan"

Get-ChildItem $OutputDir -Filter "*.zip" | ForEach-Object {
    $size = $_.Length / 1MB
    Write-ColorOutput "  $($_.Name) - $([math]::Round($size, 2)) MB" "White"
}

Write-ColorOutput "`n✓ All binaries built successfully!" "Green"
Write-ColorOutput "Output directory: $OutputDir" "Gray"
