# Test Ollama Manifest Cache - Concurrent Request Test
# This tests for race conditions that existed in the original code

Write-Host "=== Ollama Manifest Cache Concurrent Test ===" -ForegroundColor Green
Write-Host "This simulates the race conditions that caused registry corruption"
Write-Host ""

$url = "http://localhost:11434/api/tags"
$numRequests = 20
$jobs = @()

Write-Host "Starting $numRequests concurrent requests..." -ForegroundColor Cyan

# Launch multiple concurrent requests
1..$numRequests | ForEach-Object {
    $jobs += Start-Job -ScriptBlock {
        param($url, $num)
        $start = Get-Date
        try {
            $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 30
            $end = Get-Date
            $duration = ($end - $start).TotalMilliseconds
            
            [PSCustomObject]@{
                RequestNum = $num
                Success = $true
                Duration = [math]::Round($duration, 2)
                ModelCount = $response.models.Count
                Error = $null
            }
        } catch {
            $end = Get-Date
            $duration = ($end - $start).TotalMilliseconds
            [PSCustomObject]@{
                RequestNum = $num
                Success = $false
                Duration = [math]::Round($duration, 2)
                ModelCount = 0
                Error = $_.Exception.Message
            }
        }
    } -ArgumentList $url, $_
}

# Wait for all jobs to complete
Write-Host "Waiting for requests to complete..."
$results = $jobs | Wait-Job | Receive-Job

# Cleanup jobs
$jobs | Remove-Job

# Analyze results
Write-Host "`n=== Test Results ===" -ForegroundColor Yellow

$successful = ($results | Where-Object { $_.Success }).Count
$failed = ($results | Where-Object { -not $_.Success }).Count

Write-Host "Successful requests: $successful / $numRequests" -ForegroundColor $(if ($successful -eq $numRequests) { "Green" } else { "Yellow" })
Write-Host "Failed requests: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -gt 0) {
    Write-Host "`nFailed request errors:" -ForegroundColor Red
    $results | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  Request $($_.RequestNum): $($_.Error)"
    }
}

Write-Host "`n=== Performance Stats ===" -ForegroundColor Yellow
$successfulRequests = $results | Where-Object { $_.Success }
if ($successfulRequests) {
    $avgDuration = ($successfulRequests.Duration | Measure-Object -Average).Average
    $minDuration = ($successfulRequests.Duration | Measure-Object -Minimum).Minimum
    $maxDuration = ($successfulRequests.Duration | Measure-Object -Maximum).Maximum
    
    Write-Host "Average response time: $([math]::Round($avgDuration, 2))ms"
    Write-Host "Min response time: $([math]::Round($minDuration, 2))ms"
    Write-Host "Max response time: $([math]::Round($maxDuration, 2))ms"
    
    # Check for model count consistency
    $modelCounts = $successfulRequests | Select-Object -Unique ModelCount
    if ($modelCounts.Count -eq 1) {
        Write-Host "✅ Model count consistent: $($modelCounts[0].ModelCount) models" -ForegroundColor Green
    } else {
        Write-Host "❌ Model count INCONSISTENT - Race condition detected!" -ForegroundColor Red
        Write-Host "   Different counts: $($modelCounts.ModelCount -join ', ')"
    }
}

Write-Host "`n=== Verdict ===" -ForegroundColor Cyan
if ($successful -eq $numRequests -and $modelCounts.Count -eq 1) {
    Write-Host "✅ PASS: All requests succeeded with consistent results!" -ForegroundColor Green
    Write-Host "   No race conditions detected"
    Write-Host "   Cache is working correctly"
} else {
    Write-Host "❌ FAIL: Race conditions or errors detected" -ForegroundColor Red
}
