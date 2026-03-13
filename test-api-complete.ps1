# Ollama API Test Suite - Complete Validation
# Tests timing, cache performance, and API communication

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          OLLAMA API COMPREHENSIVE TEST SUITE              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$ollamaPath = "C:\Users\admin\source\ollama\ollama.exe"
$baseUrl = "http://localhost:11434"
$testModel = "llama3.1:8b-instruct-q8_0"

# Start server
Write-Host "🚀 Starting Fixed Ollama Server..." -ForegroundColor Green
$env:OLLAMA_MODELS = "C:\Users\admin\.ollama\models"
$serverProc = Start-Process -FilePath $ollamaPath -ArgumentList "serve" -WindowStyle Normal -PassThru
Start-Sleep -Seconds 6

Write-Host "   Server PID: $($serverProc.Id)" -ForegroundColor Gray
Write-Host ""

# Test 1: /api/tags (Cache Performance)
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "TEST 1: /api/tags - Manifest Cache Performance" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

$times = @()
for ($i = 1; $i -le 5; $i++) {
    $result = Measure-Command {
        $response = Invoke-RestMethod -Uri "$baseUrl/api/tags" -Method GET -ErrorAction Stop
    }
    $times += $result.TotalMilliseconds
    Write-Host "  Request $i : $([math]::Round($result.TotalMilliseconds, 2))ms - $($response.models.Count) models" -ForegroundColor Gray
}

$avgTime = ($times | Measure-Object -Average).Average
Write-Host ""
Write-Host "  ✅ Average: $([math]::Round($avgTime, 2))ms" -ForegroundColor Green
Write-Host "  📊 Min: $([math]::Round(($times | Measure-Object -Minimum).Minimum, 2))ms" -ForegroundColor Gray
Write-Host "  📊 Max: $([math]::Round(($times | Measure-Object -Maximum).Maximum, 2))ms" -ForegroundColor Gray

if ($avgTime -lt 100) {
    Write-Host "  🎉 EXCELLENT: Cache is working optimally!" -ForegroundColor Green
} elseif ($avgTime -lt 500) {
    Write-Host "  ✅ GOOD: Performance within acceptable range" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ SLOW: May need optimization" -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

# Test 2: /api/show (Model Info)
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "TEST 2: /api/show - Model Information" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

$showRequest = @{
    name = $testModel
} | ConvertTo-Json

try {
    $showResult = Measure-Command {
        $showResponse = Invoke-RestMethod -Uri "$baseUrl/api/show" -Method POST -Body $showRequest -ContentType "application/json" -ErrorAction Stop
    }
    Write-Host "  ✅ Model info retrieved in $([math]::Round($showResult.TotalMilliseconds, 2))ms" -ForegroundColor Green
    Write-Host "  📦 Model: $($showResponse.model)" -ForegroundColor Gray
    Write-Host "  📏 Size: $([math]::Round($showResponse.details.parameter_size / 1GB, 2))GB" -ForegroundColor Gray
    Write-Host "  🏗️ Format: $($showResponse.details.format)" -ForegroundColor Gray
    Write-Host "  📚 Family: $($showResponse.details.family)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# Test 3: /api/chat - Simple (No Tools)
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "TEST 3: /api/chat - Simple Chat (No Tools)" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

$simpleChatRequest = @{
    model = $testModel
    messages = @(
        @{
            role = "user"
            content = "Reply with just the word HELLO in all caps"
        }
    )
    stream = $false
    options = @{
        temperature = 0
        num_predict = 10
    }
} | ConvertTo-Json -Depth 10

try {
    $chatResult = Measure-Command {
        $chatResponse = Invoke-RestMethod -Uri "$baseUrl/api/chat" -Method POST -Body $simpleChatRequest -ContentType "application/json" -TimeoutSec 30 -ErrorAction Stop
    }
    $responseText = $chatResponse.message.content.Trim()
    Write-Host "  ✅ Chat completed in $([math]::Round($chatResult.TotalMilliseconds, 2))ms" -ForegroundColor Green
    Write-Host "  💬 Response: '$responseText'" -ForegroundColor Gray
    Write-Host "  🔢 Tokens: $($chatResponse.eval_count) eval, $($chatResponse.prompt_eval_count) prompt" -ForegroundColor Gray
    
    if ($responseText -like "*HELLO*") {
        Write-Host "  ✅ Model responding correctly!" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Unexpected response" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "  📋 Error details: $errorBody" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 2

# Test 4: /api/chat - With Tools
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "TEST 4: /api/chat - With Tool Definitions" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

$toolChatRequest = @{
    model = $testModel
    messages = @(
        @{
            role = "user"
            content = "List available tools"
        }
    )
    tools = @(
        @{
            type = "function"
            function = @{
                name = "get_weather"
                description = "Get the weather for a location"
                parameters = @{
                    type = "object"
                    properties = @{
                        location = @{
                            type = "string"
                            description = "The city and state"
                        }
                        unit = @{
                            type = "string"
                            enum = @("celsius", "fahrenheit")
                        }
                    }
                    required = @("location")
                }
            }
        },
        @{
            type = "function"
            function = @{
                name = "calculate"
                description = "Perform a calculation"
                parameters = @{
                    type = "object"
                    properties = @{
                        expression = @{
                            type = "string"
                            description = "Mathematical expression"
                        }
                    }
                    required = @("expression")
                }
            }
        }
    )
    stream = $false
    options = @{
        temperature = 0
        num_predict = 100
    }
} | ConvertTo-Json -Depth 10

Write-Host "  📋 Sending request with 2 tool definitions..." -ForegroundColor Gray

try {
    $toolResult = Measure-Command {
        $toolResponse = Invoke-RestMethod -Uri "$baseUrl/api/chat" -Method POST -Body $toolChatRequest -ContentType "application/json" -TimeoutSec 30 -ErrorAction Stop
    }
    Write-Host "  ✅ Tool chat completed in $([math]::Round($toolResult.TotalMilliseconds, 2))ms" -ForegroundColor Green
    Write-Host "  💬 Response: $($toolResponse.message.content.Substring(0, [Math]::Min(80, $toolResponse.message.content.Length)))..." -ForegroundColor Gray
    
    if ($toolResponse.message.tool_calls) {
        Write-Host "  🔧 Tool calls: $($toolResponse.message.tool_calls.Count)" -ForegroundColor Cyan
    }
    
    Write-Host "  ✅ Tool format accepted - NO 400 ERROR!" -ForegroundColor Green
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "  ❌ FAILED: HTTP $statusCode - $($_.Exception.Message)" -ForegroundColor Red
    
    if ($statusCode -eq 400) {
        Write-Host "  ⚠️ 400 BAD REQUEST - Payload format issue" -ForegroundColor Yellow
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "  📋 Error body: $errorBody" -ForegroundColor Red
        }
    }
}

Start-Sleep -Seconds 2

# Test 5: Concurrent Requests (Race Condition Test)
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "TEST 5: Concurrent /api/tags - Race Condition Check" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

Write-Host "  🔄 Launching 10 concurrent requests..." -ForegroundColor Gray

$jobs = @()
1..10 | ForEach-Object {
    $jobs += Start-Job -ScriptBlock {
        param($url, $num)
        $start = Get-Date
        try {
            $response = Invoke-RestMethod -Uri "$url/api/tags" -Method GET -TimeoutSec 10
            $end = Get-Date
            [PSCustomObject]@{
                Num = $num
                Success = $true
                Time = [math]::Round(($end - $start).TotalMilliseconds, 2)
                Count = $response.models.Count
            }
        } catch {
            [PSCustomObject]@{
                Num = $num
                Success = $false
                Time = 0
                Count = 0
            }
        }
    } -ArgumentList $baseUrl, $_
}

$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job

$successful = ($results | Where-Object { $_.Success }).Count
$failed = ($results | Where-Object { -not $_.Success }).Count
$uniqueCounts = ($results | Where-Object { $_.Success } | Select-Object -Unique Count).Count

Write-Host ""
Write-Host "  📊 Results:" -ForegroundColor Gray
Write-Host "     Success: $successful/10" -ForegroundColor $(if ($successful -eq 10) {"Green"} else {"Yellow"})
Write-Host "     Failed: $failed" -ForegroundColor $(if ($failed -eq 0) {"Green"} else {"Red"})
Write-Host "     Unique counts: $uniqueCounts" -ForegroundColor $(if ($uniqueCounts -eq 1) {"Green"} else {"Red"})

if ($successful -eq 10 -and $uniqueCounts -eq 1) {
    Write-Host ""
    Write-Host "  ✅ NO RACE CONDITIONS - All requests consistent!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  ⚠️ Race conditions detected!" -ForegroundColor Red
}

# Test 6: Streaming Response
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "TEST 6: /api/chat - Streaming Response" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

$streamRequest = @{
    model = $testModel
    messages = @(@{role="user"; content="Count from 1 to 3"})
    stream = $true
    options = @{temperature = 0; num_predict = 20}
} | ConvertTo-Json

Write-Host "  🌊 Testing streaming (first 5 chunks)..." -ForegroundColor Gray

try {
    $streamResult = Measure-Command {
        $webRequest = [System.Net.HttpWebRequest]::Create("$baseUrl/api/chat")
        $webRequest.Method = "POST"
        $webRequest.ContentType = "application/json"
        
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($streamRequest)
        $webRequest.ContentLength = $bytes.Length
        $requestStream = $webRequest.GetRequestStream()
        $requestStream.Write($bytes, 0, $bytes.Length)
        $requestStream.Close()
        
        $response = $webRequest.GetResponse()
        $responseStream = $response.GetResponseStream()
        $reader = [System.IO.StreamReader]::new($responseStream)
        
        $chunkCount = 0
        while (-not $reader.EndOfStream -and $chunkCount -lt 5) {
            $line = $reader.ReadLine()
            if ($line) {
                $chunkCount++
                Write-Host "     Chunk $chunkCount : $($line.Substring(0, [Math]::Min(60, $line.Length)))..." -ForegroundColor DarkGray
            }
        }
        
        $reader.Close()
        $response.Close()
    }
    
    Write-Host "  ✅ Streaming works! Received $chunkCount chunks in $([math]::Round($streamResult.TotalMilliseconds, 2))ms" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Streaming failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    TEST SUMMARY                             " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "📍 Server: $ollamaPath" -ForegroundColor Gray
Write-Host "🔗 Base URL: $baseUrl" -ForegroundColor Gray
Write-Host "🤖 Test Model: $testModel" -ForegroundColor Gray
Write-Host ""
Write-Host "All tests completed! Press any key to stop the server..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Cleanup
Write-Host ""
Write-Host "🛑 Stopping Ollama server..." -ForegroundColor Yellow
cmd /c "taskkill /F /PID $($serverProc.Id)" 2>&1 | Out-Null
Write-Host "✅ Done!" -ForegroundColor Green
