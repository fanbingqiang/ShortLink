# Quick Benchmark - 200 concurrent, 10s warm-up, 30s test
param(
    [int]$ConcurrentUsers = 200,
    [int]$WarmUpSeconds = 10,
    [int]$DurationSeconds = 30
)

$BaseUrl = "http://localhost:8080"

Write-Host "========================================"
Write-Host "Quick Benchmark - Redis ON"
Write-Host "========================================"
Write-Host "Concurrent: $ConcurrentUsers | WarmUp: ${WarmUpSeconds}s | Duration: ${DurationSeconds}s"

# Create test short link
$createResp = Invoke-RestMethod -Uri "$BaseUrl/api/short-link/create" -Method POST -ContentType "application/json" -Body '{"longUrl":"https://test.com"}'
$shortCode = $createResp.data.shortCode
Write-Host "Test code: $shortCode"

$queryUrl = "$BaseUrl/api/short-link/$shortCode"

# Simple benchmark function
function Run-Benchmark {
    param($Seconds, $Title)
    Write-Host ""
    Write-Host "[$Title] Running for ${Seconds}s..."
    
    $start = Get-Date
    $end = $start.AddSeconds($Seconds)
    $count = 0
    $success = 0
    $totalTime = 0
    $minTime = [int]::MaxValue
    $maxTime = 0
    
    $jobs = @()
    $scriptBlock = {
        param($url, $endTime)
        $c = 0; $s = 0; $tt = 0; $mi = 999999; $ma = 0
        while ((Get-Date) -lt $endTime) {
            $st = Get-Date
            try {
                Invoke-RestMethod -Uri $url -TimeoutSec 5 | Out-Null
                $et = Get-Date
                $d = ($et - $st).TotalMilliseconds
                $c++; $s++; $tt += $d
                if ($d -lt $mi) { $mi = $d }
                if ($d -gt $ma) { $ma = $d }
            } catch {
                $c++
            }
        }
        return @{count=$c; success=$s; totalTime=$tt; min=$mi; max=$ma}
    }
    
    for ($i = 0; $i -lt $ConcurrentUsers; $i++) {
        $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $queryUrl, $end
    }
    
    # Progress
    while ((Get-Date) -lt $end) {
        Start-Sleep 5
        $elapsed = [int]((Get-Date) - $start).TotalSeconds
        $remain = $Seconds - $elapsed
        Write-Host "  ${elapsed}s/${Seconds}s remaining..." -ForegroundColor Gray
    }
    
    $results = $jobs | Wait-Job | Receive-Job
    Remove-Job $jobs
    
    foreach ($r in $results) {
        $count += $r.count
        $success += $r.success
        $totalTime += $r.totalTime
        if ($r.min -lt $minTime) { $minTime = $r.min }
        if ($r.max -gt $maxTime) { $maxTime = $r.max }
    }
    
    $avgTime = if ($success -gt 0) { [math]::Round($totalTime / $success, 2) } else { 0 }
    $rps = [math]::Round($count / $Seconds, 2)
    $fail = $count - $success
    
    Write-Host "Results: RPS=$rps | Total=$count | Success=$success | Failed=$fail"
    Write-Host "Response: Avg=${avgTime}ms | Min=$([math]::Round($minTime,2))ms | Max=$([math]::Round($maxTime,2))ms"
}

# Warm up
if ($WarmUpSeconds -gt 0) {
    Run-Benchmark -Seconds $WarmUpSeconds -Title "WARM-UP"
}

# Real test
Run-Benchmark -Seconds $DurationSeconds -Title "BENCHMARK"

Write-Host ""
Write-Host "========================================"
Write-Host "Redis ON Test Complete"
Write-Host "========================================"
