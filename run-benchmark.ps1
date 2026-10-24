param(
    [int]$Threads = 200,
    [int]$Duration = 60,
    [string]$BaseUrl = "http://192.168.157.161:8080"
)

$shortCodes = Get-Content "jmeter_short_codes.txt"
$results = @()
$success = 0
$failed = 0
$startTime = Get-Date
$endTime = $startTime.AddSeconds($Duration)

Write-Host "========================================"
Write-Host "ShortLink Redirect API Benchmark"
Write-Host "========================================"
Write-Host "Threads: $Threads"
Write-Host "Duration: ${Duration}s"
Write-Host "Target: $BaseUrl"
Write-Host "========================================"
Write-Host ""

$codeCount = $shortCodes.Count
$jobs = @()

while ((Get-Date) -lt $endTime) {
    $batch = 1..$Threads | ForEach-Object {
        $code = $shortCodes[(Get-Random -Maximum $codeCount)]
        $url = "$BaseUrl/$code"
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $response = Invoke-WebRequest -Uri $url -Method GET -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction SilentlyContinue
            $sw.Stop()
            $statusCode = $response.StatusCode
            $success++
            return @{ Time = $sw.ElapsedMilliseconds; Status = $statusCode; Success = $true }
        }
        catch {
            $sw.Stop()
            $failed++
            return @{ Time = $sw.ElapsedMilliseconds; Status = 0; Success = $false }
        }
    }
    
    $results += $batch
    Write-Host "." -NoNewline
}

$elapsed = ((Get-Date) - $startTime).TotalSeconds
$total = $success + $failed
$rps = [math]::Round($total / $elapsed, 2)

$times = $results | Where-Object { $_.Success } | Select-Object -ExpandProperty Time
$sorted = $times | Sort-Object
$count = $sorted.Count

if ($count -gt 0) {
    $avg = [math]::Round(($times | Measure-Object -Average).Average, 2)
    $min = $sorted[0]
    $max = $sorted[-1]
    $p50 = $sorted[[int]($count * 0.5)]
    $p90 = $sorted[[int]($count * 0.9)]
    $p95 = $sorted[[int]($count * 0.95)]
    $p99 = $sorted[[int]($count * 0.99)]
}

Write-Host ""
Write-Host ""
Write-Host "========================================"
Write-Host "BENCHMARK REPORT"
Write-Host "========================================"
Write-Host ""
Write-Host "Summary"
Write-Host "-------"
Write-Host "Total Requests: $total"
Write-Host "Success: $success"
Write-Host "Failed: $failed"
Write-Host "Success Rate: $([math]::Round($success / $total * 100, 2))%"
Write-Host "Duration: $([math]::Round($elapsed, 2))s"
Write-Host "RPS: $rps"
Write-Host ""
Write-Host "Response Time (ms)"
Write-Host "------------------"
Write-Host "Average: $avg"
Write-Host "Min: $min"
Write-Host "Max: $max"
Write-Host "P50: $p50"
Write-Host "P90: $p90"
Write-Host "P95: $p95"
Write-Host "P99: $p99"
Write-Host ""

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>JMeter Benchmark Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #007bff; color: white; }
        tr:hover { background: #f5f5f5; }
        .success { color: #28a745; font-weight: bold; }
        .metric { font-size: 24px; font-weight: bold; color: #007bff; }
        .metric-label { color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>JMeter Benchmark Report</h1>
        
        <h2>Test Configuration</h2>
        <table>
            <tr><th>Parameter</th><th>Value</th></tr>
            <tr><td>Target Server</td><td>$BaseUrl</td></tr>
            <tr><td>Threads</td><td>$Threads</td></tr>
            <tr><td>Duration</td><td>${Duration}s</td></tr>
            <tr><td>Test Date</td><td>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td></tr>
        </table>
        
        <h2>Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Requests</td><td>$total</td></tr>
            <tr><td>Success</td><td class="success">$success</td></tr>
            <tr><td>Failed</td><td>$failed</td></tr>
            <tr><td>Success Rate</td><td>$([math]::Round($success / $total * 100, 2))%</td></tr>
            <tr><td>Duration</td><td>$([math]::Round($elapsed, 2))s</td></tr>
            <tr><td>RPS</td><td class="metric">$rps</td></tr>
        </table>
        
        <h2>Response Time (ms)</h2>
        <table>
            <tr><th>Percentile</th><th>Response Time</th></tr>
            <tr><td>Average</td><td>$avg</td></tr>
            <tr><td>Min</td><td>$min</td></tr>
            <tr><td>Max</td><td>$max</td></tr>
            <tr><td>P50</td><td>$p50</td></tr>
            <tr><td>P90</td><td>$p90</td></tr>
            <tr><td>P95</td><td>$p95</td></tr>
            <tr><td>P99</td><td>$p99</td></tr>
        </table>
        
        <h2>Conclusion</h2>
        <p>Test completed with $([math]::Round($success / $total * 100, 2))% success rate.</p>
        <p>Average response time: ${avg}ms, P99: ${p99}ms</p>
        <p>Throughput: $rps requests per second</p>
    </div>
</body>
</html>
"@

$html | Out-File "benchmark-report.html" -Encoding UTF8
Write-Host "Report saved to: benchmark-report.html"
