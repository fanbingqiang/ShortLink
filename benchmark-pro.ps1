# Professional Benchmark Script for Short Link Service
param(
    [int]$ConcurrentUsers = 200,
    [int]$WarmUpSeconds = 10,
    [int]$DurationSeconds = 60,
    [string]$BaseUrl = "http://localhost:8080",
    [switch]$SkipCreate
)

$script:TotalRequests = 0
$script:SuccessRequests = 0
$script:FailedRequests = 0
$script:ResponseTimes = [System.Collections.ArrayList]::new()
$script:Running = $true
$script:Lock = New-Object System.Object

function Write-Stats {
    param($Title, $StartTime)
    $elapsed = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 1)
    $total = $script:TotalRequests
    $success = $script:SuccessRequests
    $failed = $script:FailedRequests
    $rps = if ($elapsed -gt 0) { [math]::Round($total / $elapsed, 2) } else { 0 }
    
    $avgTime = 0
    $minTime = 0
    $maxTime = 0
    if ($script:ResponseTimes.Count -gt 0) {
        $avgTime = [math]::Round(($script:ResponseTimes | Measure-Object -Average).Average, 2)
        $minTime = [math]::Round(($script:ResponseTimes | Measure-Object -Minimum).Minimum, 2)
        $maxTime = [math]::Round(($script:ResponseTimes | Measure-Object -Maximum).Maximum, 2)
    }
    
    Write-Host ""
    Write-Host "========== $Title ==========" -ForegroundColor Cyan
    Write-Host "Elapsed Time: ${elapsed}s"
    Write-Host "Total Requests: $total"
    Write-Host "Success: $success | Failed: $failed"
    Write-Host "RPS (Requests/Second): $rps"
    Write-Host "Avg Response Time: ${avgTime}ms | Min: ${minTime}ms | Max: ${maxTime}ms"
    Write-Host "========================================"
}

function Invoke-BenchmarkRequest {
    param($Url, $Method = 'GET', $Body = $null)
    
    $start = Get-Date
    try {
        if ($Method -eq 'POST') {
            $null = Invoke-RestMethod -Uri $Url -Method POST -ContentType "application/json" -Body $Body -TimeoutSec 10
        } else {
            $null = Invoke-RestMethod -Uri $Url -Method GET -TimeoutSec 10
        }
        $end = Get-Date
        $duration = ($end - $start).TotalMilliseconds
        
        [void]$script:ResponseTimes.Add($duration)
        $script:TotalRequests++
        $script:SuccessRequests++
    } catch {
        $script:TotalRequests++
        $script:FailedRequests++
    }
}

function Start-BenchmarkRun {
    param($Duration, $Description)
    
    Write-Host ""
    Write-Host "Starting $Description..." -ForegroundColor Green
    
    $script:TotalRequests = 0
    $script:SuccessRequests = 0
    $script:FailedRequests = 0
    $script:ResponseTimes.Clear()
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Duration)
    
    # Create a test short link first
    $testUrl = "$BaseUrl/api/short-link/create"
    $testBody = '{"longUrl":"https://www.example.com/test"}'
    try {
        $response = Invoke-RestMethod -Uri $testUrl -Method POST -ContentType "application/json" -Body $testBody -TimeoutSec 10
        $shortCode = $response.data.shortCode
        Write-Host "Test short code created: $shortCode"
    } catch {
        Write-Host "Failed to create test short code, using default: abc123" -ForegroundColor Yellow
        $shortCode = "abc123"
    }
    
    $queryUrl = "$BaseUrl/api/short-link/$shortCode"
    
    # Start worker jobs
    $jobs = @()
    for ($i = 0; $i -lt $ConcurrentUsers; $i++) {
        $job = Start-Job -ScriptBlock {
            param($BaseUrl, $ShortCode, $EndTimeStr, $LockObj)
            $endTime = [DateTime]::Parse($EndTimeStr)
            $queryUrl = "$BaseUrl/api/short-link/$ShortCode"
            
            while ((Get-Date) -lt $endTime) {
                $start = Get-Date
                try {
                    $null = Invoke-RestMethod -Uri $queryUrl -Method GET -TimeoutSec 10
                    $end = Get-Date
                    $duration = ($end - $start).TotalMilliseconds
                    
                    # Update stats
                    [void]($LockObj)
                    try {
                        $script:TotalRequests++
                        $script:SuccessRequests++
                        [void]$script:ResponseTimes.Add($duration)
                    } finally {
                        [System.Threading.Monitor]::Exit($LockObj)
                    }
                } catch {
                    [void]($LockObj)
                    try {
                        $script:TotalRequests++
                        $script:FailedRequests++
                    } finally {
                        [System.Threading.Monitor]::Exit($LockObj)
                    }
                }
            }
        } -ArgumentList $BaseUrl, $shortCode, $endTime.ToString(), $script:Lock
        
        $jobs += $job
    }
    
    # Progress display
    while ((Get-Date) -lt $endTime) {
        Start-Sleep -Seconds 5
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
        $remaining = [math]::Round(($endTime - (Get-Date)).TotalSeconds, 0)
        Write-Host "Progress: ${elapsed}s elapsed, ${remaining}s remaining, Requests: $($script:TotalRequests)" -ForegroundColor Gray
    }
    
    # Wait for all jobs
    $jobs | Wait-Job | Out-Null
    $jobs | Remove-Job
    
    Write-Stats -Title "$Description RESULTS" -StartTime $startTime
}

# Main
Write-Host "========================================"
Write-Host "Short Link Service Professional Benchmark"
Write-Host "========================================"
Write-Host "Concurrent Users: $ConcurrentUsers"
Write-Host "Warm Up: ${WarmUpSeconds}s"
Write-Host "Duration: ${DurationSeconds}s"
Write-Host "Target URL: $BaseUrl"
Write-Host "========================================"

# Check Redis status
try {
    $redisPing = D:\Redis\redis-cli.exe ping 2>$null
    if ($redisPing -eq "PONG") {
        Write-Host "Redis Status: RUNNING" -ForegroundColor Green
    } else {
        Write-Host "Redis Status: NOT RUNNING" -ForegroundColor Red
    }
} catch {
    Write-Host "Redis Status: NOT RUNNING" -ForegroundColor Red
}

# Warm up phase
if ($WarmUpSeconds -gt 0) {
    Start-BenchmarkRun -Duration $WarmUpSeconds -Description "WARM UP"
}

# Real benchmark
Start-BenchmarkRun -Duration $DurationSeconds -Description "BENCHMARK"

Write-Host ""
Write-Host "========================================"
Write-Host "Benchmark Complete"
Write-Host "========================================"
