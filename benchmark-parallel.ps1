param(
    [string]$BaseUrl = "http://192.168.157.161:8080",
    [int]$Duration = 60
)

$shortCodes = Get-Content "jmeter_short_codes.txt"
$codeCount = $shortCodes.Count
$threadLevels = @(20, 50, 100, 150, 200)
$results = @()

Write-Host "========================================"
Write-Host "ShortLink Redirect API Benchmark"
Write-Host "========================================"
Write-Host "Target: $BaseUrl"
Write-Host "Duration per test: ${Duration}s"
Write-Host "Thread levels: $($threadLevels -join ', ')"
Write-Host "========================================"
Write-Host ""

$runspacePool = [runspaceFactory]::CreateRunspacePool(100)

$lockObj = New-Object

foreach ($threads in $threadLevels) {
    Write-Host "Testing $threads threads..."
    
    $success = 0
    $failed = 0
    $responseTimes = [System.Collections.Concurrent.ConcurrentQueue]::new()
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Duration)
    
    while ((Get-Date) -lt $endTime) {
        $code = $shortCodes[(Get-Random -Maximum $codeCount)]
        $url = "$BaseUrl/$code"
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $response = Invoke-WebRequest -Uri $url -Method GET -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction SilentlyContinue
            $sw.Stop()
            if ($response.StatusCode -eq 302) {
                $success++
                $responseTimes.Enqueue($sw.ElapsedMilliseconds)
            }
            else {
                $failed++
            }
        }
        catch {
            $sw.Stop()
            $failed++
        }
    }
    
    $runspacePool.Dispose()
    
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $total = $success + $failed
    $rps = [math]::Round($total / $elapsed, 2)
    $successRate = [math]::Round($success / $total * 100, 2)
    
    $avgTime = 0
    $p50 = 0
    $p90 = 0
    $p99 = 0
    
    if ($responseTimes.Count -gt 0) {
        $sorted = $responseTimes.ToArray() | Sort-Object
        $avgTime = [math]::Round(($responseTimes.ToArray() | Measure-Object -Average).Average, 2)
        $p50 = $ sorted[[int]($sorted.Count * 0.5)]
        $p90 = $ sorted[[int]($sorted.Count * 0.9)]
        $p99 = $ sorted[[int]($sorted.Count * 0.99)]
    }
    
    $results += [PSCustomObject]@{
        Threads = $threads
        Total = $total
        Success = $success
        Failed = $failed
        SuccessRate = $successRate
        RPS = $rps
        AvgTime = $avgTime
        P50 = $p50
        P90 = $p90
        P99 = $p99
    }
    
    Write-Host "  Total: $total | Success: $success | Failed: $failed | RPS: $rps | Avg: ${avgTime}ms"
    Write-Host ""
}

$elapsed = ((Get-Date) - $startTime).TotalSeconds
$totalTime = $elapsed.TotalSeconds
Write-Host ""
Write-Host "========================================"
Write-Host "BENCHMARK SUMMARY"
Write-Host "========================================"
Write-Host ""
Write-Host "Threads | Total | Success | Failed | Rate% | RPS | Avg(ms) | P50 | P90 | P99"
Write-Host "--------|-------|---------|--------|-------|-----|---------|-----|-----|-----"
foreach ($r in $results) {
    Write-Host "$($r.Threads) | $($r.Total) | $($r.Success) | $($r.Failed) | $($r.SuccessRate) | $($r.RPS) | $($r.AvgTime) | $($r.P50) | $($r.P90) | $($r.P99)"
}

$elapsed = ((Get-Date) - $startTime).TotalSeconds
Write-Host "Peak Performance: $($results | Sort-Object RPS -Descending | Select-Object -First 1).RPS RPS at $($results | Sort-Object RPS -Descending | Select-Object -First 1).Threads threads"
Write-Host ""
Write-Host "Report saved to: benchmark-report.html"
