#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build complete Ollama CE distribution with CLI, Desktop UI, and Web UI
.DESCRIPTION
    Creates a comprehensive package that includes:
    - ollama.exe (CLI/server)
    - Ollama-app.exe (Desktop UI with embedded web UI)
    - Web UI static files (for browser access)
    All three options bundled together for Windows
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
Write-ColorOutput "`n$("=" * 70)" "Cyan"
Write-ColorOutput "Building Ollama CE v$version Complete Distribution" "Cyan"
Write-ColorOutput "Includes: CLI + Desktop UI + Web UI" "Cyan"
Write-ColorOutput "$("=" * 70)`n" "Cyan"

# Create output directory
if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Path "$OutputDir\package" | Out-Null

# Step 1: Build Web UI (React SPA)
Write-ColorOutput "Step 1: Building Web UI (React)..." "Yellow"
try {
    Push-Location "app\ui\app"
    
    Write-ColorOutput "  Installing npm dependencies..." "Gray"
    & npm install --silent
    if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
    
    Write-ColorOutput "  Building React SPA..." "Gray"
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm build failed" }
    
    Write-ColorOutput "  ✓ Web UI built successfully" "Green"
    Pop-Location
}
catch {
    Pop-Location
    throw "Web UI build failed: $_"
}

# Step 2: Generate TypeScript types from Go
Write-ColorOutput "`nStep 2: Generating TypeScript types..." "Yellow"
try {
    Write-ColorOutput "  Running go generate..." "Gray"
    & go generate ./...
    if ($LASTEXITCODE -ne 0) { 
        Write-ColorOutput "  ⚠ Generate had warnings (non-fatal)" "Yellow"
    } else {
        Write-ColorOutput "  ✓ Types generated" "Green"
    }
}
catch {
    Write-ColorOutput "  ⚠ Generate step had issues (continuing)" "Yellow"
}

# Step 3: Build CLI/Server binary
Write-ColorOutput "`nStep 3: Building CLI/Server (ollama.exe)..." "Yellow"
try {
    $ldflags = "-s -w -X=github.com/ollama/ollama/version.Version=$version -X=github.com/ollama/ollama/server.mode=release"
    
    Write-ColorOutput "  Compiling ollama.exe..." "Gray"
    & go build -trimpath -ldflags $ldflags -o "$OutputDir\package\ollama.exe" .
    if ($LASTEXITCODE -ne 0) { throw "CLI build failed" }
    
    $size = (Get-Item "$OutputDir\package\ollama.exe").Length / 1MB
    Write-ColorOutput "  ✓ CLI built: $([math]::Round($size, 2)) MB" "Green"
}
catch {
    throw "CLI build failed: $_"
}

# Step 4: Build Desktop UI app
Write-ColorOutput "`nStep 4: Building Desktop UI (Ollama-app.exe)..." "Yellow"
try {
    $appLdflags = "-s -w -H windowsgui -X=github.com/ollama/ollama/app/version.Version=$version"
    
    Write-ColorOutput "  Compiling Desktop app..." "Gray"
    & go build -trimpath -ldflags $appLdflags -o "$OutputDir\package\Ollama-app.exe" .\app\cmd\app\
    if ($LASTEXITCODE -ne 0) { throw "Desktop UI build failed" }
    
    $size = (Get-Item "$OutputDir\package\Ollama-app.exe").Length / 1MB
    Write-ColorOutput "  ✓ Desktop UI built: $([math]::Round($size, 2)) MB" "Green"
    Write-ColorOutput "    (Includes embedded Web UI)" "Gray"
}
catch {
    throw "Desktop UI build failed: $_"
}

# Step 5: Copy Web UI static files for browser access
Write-ColorOutput "`nStep 5: Packaging Web UI for browsers..." "Yellow"
try {
    $webUIDir = "$OutputDir\package\web-ui"
    New-Item -ItemType Directory -Path $webUIDir | Out-Null
    
    Write-ColorOutput "  Copying static files..." "Gray"
    Copy-Item "app\ui\app\dist\*" $webUIDir -Recurse -Force
    
    $fileCount = (Get-ChildItem $webUIDir -Recurse -File).Count
    Write-ColorOutput "  ✓ Web UI packaged: $fileCount files" "Green"
}
catch {
    throw "Web UI packaging failed: $_"
}

# Step 6: Copy documentation
Write-ColorOutput "`nStep 6: Adding documentation..." "Yellow"
Copy-Item "README.md" "$OutputDir\package\" -ErrorAction SilentlyContinue
Copy-Item "LICENSE" "$OutputDir\package\" -ErrorAction SilentlyContinue

# Create comprehensive installation guide
$installGuide = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                  Ollama Community Edition v$version                        
║                Complete Distribution Package                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

This package includes THREE ways to use Ollama CE:

┌──────────────────────────────────────────────────────────────────────────────┐
│ 1️⃣  DESKTOP APP (Recommended for most users)                               │
└──────────────────────────────────────────────────────────────────────────────┘

   Run: Ollama-app.exe
   
   • Beautiful desktop application with system tray integration
   • Automatic server management (starts/stops with app)
   • Built-in chat interface
   • Model management UI
   • No browser required

┌──────────────────────────────────────────────────────────────────────────────┐
│ 2️⃣  WEB UI (For browser-based access)                                      │
└──────────────────────────────────────────────────────────────────────────────┘

   Step 1: Start the server
           ollama.exe serve
   
   Step 2: Serve the web UI (choose one):
           
           Option A - Using Python:
           cd web-ui
           python -m http.server 8080
           
           Option B - Using Node.js:
           npx serve web-ui -p 8080
           
           Option C - Copy to a web server (IIS, Apache, nginx)
   
   Step 3: Open browser to http://localhost:8080
   
   • Same interface as desktop app
   • Access from any browser
   • Can be hosted on network for team access

┌──────────────────────────────────────────────────────────────────────────────┐
│ 3️⃣  CLI (For developers and automation)                                    │
└──────────────────────────────────────────────────────────────────────────────┘

   Terminal 1: Start server
               ollama.exe serve
   
   Terminal 2: Use CLI commands
               ollama.exe pull llama3.2
               ollama.exe run llama3.2
               ollama.exe list
   
   • Full command-line control
   • Perfect for scripts and automation
   • REST API access (port 11434)

╔══════════════════════════════════════════════════════════════════════════════╗
║ INSTALLATION                                                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

1. Extract this ZIP to a permanent location:
   Recommended: C:\Program Files\Ollama-CE\

2. Add to PATH (optional but recommended):
   - Open System Properties → Environment Variables
   - Edit PATH variable
   - Add: C:\Program Files\Ollama-CE\

3. Choose your interface and start using Ollama CE!

╔══════════════════════════════════════════════════════════════════════════════╗
║ QUICK START                                                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

Desktop App Users:
  1. Double-click Ollama-app.exe
  2. Click "Pull a model" or type a model name
  3. Start chatting!

CLI Users:
  1. ollama serve (keep running)
  2. ollama run llama3.2
  3. Type your questions!

╔══════════════════════════════════════════════════════════════════════════════╗
║ POPULAR MODELS                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

  ollama pull llama3.2          # Meta's latest model (3B)
  ollama pull qwen2.5-coder     # Best for coding (7B)
  ollama pull mistral           # Fast and efficient (7B)
  ollama pull deepseek-r1       # Reasoning model (7B)

╔══════════════════════════════════════════════════════════════════════════════╗
║ WHAT'S FIXED IN COMMUNITY EDITION                                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

✓ 18 server bugs fixed (auth, caching, concurrency, manifests)
✓ 35+ Desktop UI bugs fixed
✓ OpenClaw integration optimized (tool calling, streaming)
✓ Better error handling and stability

╔══════════════════════════════════════════════════════════════════════════════╗
║ LINKS                                                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

  Website:     https://openclawce.com/ollama-ce
  GitHub:      https://github.com/ssfdre38/ollama/tree/community-edition
  Bug Reports: https://github.com/ssfdre38/ollama/issues
  
  Built on Ollama: https://ollama.com/

╔══════════════════════════════════════════════════════════════════════════════╗
║ SUPPORT                                                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

Need help? Open an issue on GitHub or check the documentation at openclawce.com

Enjoy using Ollama Community Edition! 🦙✨

"@

Set-Content -Path "$OutputDir\package\INSTALL.txt" -Value $installGuide
Write-ColorOutput "  ✓ Installation guide created" "Green"

# Step 7: Create ZIP archive
Write-ColorOutput "`nStep 7: Creating distribution archive..." "Yellow"
$zipName = "ollama-ce-$version-windows-amd64-complete.zip"
$zipPath = Join-Path $OutputDir $zipName

Write-ColorOutput "  Compressing package..." "Gray"
Compress-Archive -Path "$OutputDir\package\*" -DestinationPath $zipPath -Force

$zipSize = (Get-Item $zipPath).Length / 1MB
Write-ColorOutput "  ✓ Archive created: $([math]::Round($zipSize, 2)) MB" "Green"

# Summary
Write-ColorOutput "`n$("=" * 70)" "Cyan"
Write-ColorOutput "Build Complete!" "Green"
Write-ColorOutput "$("=" * 70)" "Cyan"

Write-ColorOutput "`nPackage Contents:" "White"
Write-ColorOutput "  • ollama.exe           - CLI and server" "Gray"
Write-ColorOutput "  • Ollama-app.exe       - Desktop application" "Gray"
Write-ColorOutput "  • web-ui/              - Web interface files" "Gray"
Write-ColorOutput "  • INSTALL.txt          - User guide" "Gray"
Write-ColorOutput "  • README.md, LICENSE   - Documentation" "Gray"

Write-ColorOutput "`nOutput:" "White"
Write-ColorOutput "  📦 $zipPath" "Cyan"
Write-ColorOutput "  📊 $([math]::Round($zipSize, 2)) MB" "Cyan"

Write-ColorOutput "`n✨ Ready for distribution!`n" "Green"
