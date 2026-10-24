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

$scriptBlock = {
    param($url, $timeout)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -MaximumRedirection 0 -TimeoutSec $timeout -ErrorAction SilentlyContinue
        $sw.Stop()
        if ($response.StatusCode -eq 302) {
            return @{ Success = $true; Time = $sw.ElapsedMilliseconds }
        } else {
            return @{ Success = $false; Time = $sw.ElapsedMilliseconds }
        }
    }
    catch {
        $sw.Stop()
        return @{ Success = $false; Time = $sw.ElapsedMilliseconds }
    }
}

foreach ($threads in $threadLevels) {
    Write-Host "Testing with $threads threads..."
    
    $success = 0
    $failed = 0
    $responseTimes = [System.Collections.Concurrent.ConcurrentBag[long]]::new()
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Duration)
    
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $threads)
    $runspacePool.Open()
    $jobs = [System.Collections.ArrayList]::new()
    
    while ((Get-Date) -lt $endTime) {
        $code = $shortCodes[(Get-Random -Maximum $codeCount)]
        $url = "$BaseUrl/$code"
        
        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $runspacePool
        [void]$powershell.AddScript({
            param($url)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $response = Invoke-WebRequest -Uri $url -Method GET -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction SilentlyContinue
                $sw.Stop()
                if ($response.StatusCode -eq 302) {
                    return @{ Success = $true; Time = $sw.ElapsedMilliseconds }
                }
                return @{ Success = $false; Time = $sw.ElapsedMilliseconds }
            }
            catch {
                $sw.Stop()
                return @{ Success = $false; Time = $sw.ElapsedMilliseconds }
            }
        }).AddArgument($url)
        
        [void]$jobs.Add(@{ PS = $powershell; Result = $powershell.BeginInvoke() })
        
        $completed = $jobs | Where-Object { $_.Result.IsCompleted }
        foreach ($job in $completed) {
            $result = $job.PS.EndInvoke($job.Result)
            if ($result.Success) {
                $success++
                $responseTimes.Add($result.Time)
            } else {
                $failed++
            }
            $job.PS.Dispose()
            [void]$jobs.Remove($job)
        }
        
        Start-Sleep -Milliseconds 1
    }
    
    while ($jobs.Count -gt 0) {
        $completed = $jobs | Where-Object { $_.Result.IsCompleted }
        foreach ($job in $completed) {
            $result = $job.PS.EndInvoke($job.Result)
            if ($result.Success) {
                $success++
                $responseTimes.Add($result.Time)
            } else {
                $failed++
            }
            $job.PS.Dispose()
            [void]$jobs.Remove($job)
        }
        Start-Sleep -Milliseconds 10
    }
    
    $runspacePool.Close()
    
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $total = $success + $failed
    $rps = [math]::Round($total / $elapsed, 2)
    $successRate = [math]::Round($success / $total * 100, 2)
    
    $avgTime = 0
    $p50 = 0
    $p90 = 0
    $p99 = 0
    
    $timeArray = $responseTimes.ToArray()
    if ($timeArray.Count -gt 0) {
        $sorted = $timeArray | Sort-Object
        $avgTime = [math]::Round(($timeArray | Measure-Object -Average).Average, 2)
        $p50 = $sorted[[int]($sorted.Count * 0.5)]
        $p90 = $sorted[[int]($sorted.Count * 0.9)]
        $p99 = $sorted[[int]($sorted.Count * 0.99)]
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

Write-Host "========================================"
Write-Host "BENCHMARK SUMMARY"
Write-Host "========================================"
Write-Host ""
Write-Host "Threads | Total | Success | Failed | Rate% | RPS | Avg(ms) | P50 | P90 | P99"
Write-Host "--------|-------|---------|--------|-------|-----|---------|-----|-----|-----"
foreach ($r in $results) {
    Write-Host "$($r.Threads) | $($r.Total) | $($r.Success) | $($r.Failed) | $($r.SuccessRate) | $($r.RPS) | $($r.AvgTime) | $($r.P50) | $($r.P90) | $($r.P99)"
}

$maxRps = $results | Sort-Object RPS -Descending | Select-Object -First 1
Write-Host ""
Write-Host "Peak Performance: $($maxRps.RPS) RPS at $($maxRps.Threads) threads"

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Benchmark Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: center; border: 1px solid #ddd; }
        th { background: #007bff; color: white; }
        .highlight { background: #d4edda; font-weight: bold; }
        .fail { color: #dc3545; }
        .success { color: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Benchmark Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</h1>
        
        <h2>Test Configuration</h2>
        <p>Target: $BaseUrl</p>
        <p>Duration per test: ${Duration}s</p>
        
        <h2>Results</h2>
        <table>
            <tr>
                <th>Threads</th>
                <th>Total</th>
                <th>Success</th>
                <th>Failed</th>
                <th>Rate%</th>
                <th>RPS</th>
                <th>Avg(ms)</th>
                <th>P50</th>
                <th>P90</th>
                <th>P99</th>
            </tr>
"@

foreach ($r in $results) {
    $highlight = if ($r.RPS -eq $maxRps.RPS) { 'highlight' } else { '' }
    $html += @"
            <tr class="$highlight">
                <td>$($r.Threads)</td>
                <td>$($r.Total)</td>
                <td class="success">$($r.Success)</td>
                <td class="fail">$($r.Failed)</td>
                <td>$($r.SuccessRate)</td>
                <td><strong>$($r.RPS)</strong></td>
                <td>$($r.AvgTime)</td>
                <td>$($r.P50)</td>
                <td>$($r.P90)</td>
                <td>$($r.P99)</td>
            </tr>
"@
}

$html += @"
        </table>
        
        <h2>Conclusion</h2>
        <p>Peak Performance: <strong>$($maxRps.RPS) RPS</strong> at <strong>$($maxRps.Threads) threads</strong></p>
    </div>
</body>
</html>
"@

$html | Out-File "benchmark-report.html" -Encoding UTF8
Write-Host ""
Write-Host "Report saved to: benchmark-report.html"
