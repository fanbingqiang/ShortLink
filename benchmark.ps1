# Short Link Service Benchmark Script
param(
    [int]$ConcurrentUsers = 50,
    [int]$TotalRequests = 200,
    [string]$BaseUrl = "http://localhost:8080"
)

Write-Host "========================================"
Write-Host "Short Link Service Benchmark"
Write-Host "========================================"
Write-Host "Concurrent Users: $ConcurrentUsers"
Write-Host "Total Requests: $TotalRequests"
Write-Host "Target URL: $BaseUrl"
Write-Host "========================================"

# Test 1: Create short link
Write-Host ""
Write-Host "[Test 1] Create Short Link Benchmark..."

$CreateResults = 1..$TotalRequests | ForEach-Object -Parallel {
    $url = "$using:BaseUrl/api/short-link/create"
    $body = '{"longUrl":"https://www.example.com/' + $_ + '"}'
    $start = Get-Date
    try {
        $response = Invoke-RestMethod -Uri $url -Method POST -ContentType "application/json" -Body $body -TimeoutSec 10
        $end = Get-Date
        $duration = ($end - $start).TotalMilliseconds
        [PSCustomObject]@{
            Success = $true
            ResponseTime = $duration
            ShortCode = $response.data.shortCode
        }
    } catch {
        [PSCustomObject]@{
            Success = $false
            ResponseTime = 0
            Error = $_.Exception.Message
        }
    }
} -ThrottleLimit $ConcurrentUsers

$SuccessCreate = ($CreateResults | Where-Object { $_.Success }).Count
$FailCreate = ($CreateResults | Where-Object { -not $_.Success }).Count
$AvgCreateTime = ($CreateResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Average).Average
$MinCreateTime = ($CreateResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Minimum).Minimum
$MaxCreateTime = ($CreateResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Maximum).Maximum

Write-Host "Create Short Link Results:"
Write-Host "  Success: $SuccessCreate / $TotalRequests"
Write-Host "  Failed: $FailCreate"
if ($AvgCreateTime) {
    Write-Host "  Avg Response Time: $([math]::Round($AvgCreateTime, 2)) ms"
    Write-Host "  Min Response Time: $([math]::Round($MinCreateTime, 2)) ms"
    Write-Host "  Max Response Time: $([math]::Round($MaxCreateTime, 2)) ms"
}

# Get short code for query test
$ShortCode = ($CreateResults | Where-Object { $_.Success } | Select-Object -First 1).ShortCode

if ($ShortCode) {
    # Test 2: Query short link (with cache)
    Write-Host ""
    Write-Host "[Test 2] Query Short Link Benchmark (Redis Cache)..."
    
    $QueryResults = 1..$TotalRequests | ForEach-Object -Parallel {
        $url = "$using:BaseUrl/api/short-link/$using:ShortCode"
        $start = Get-Date
        try {
            $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 10
            $end = Get-Date
            $duration = ($end - $start).TotalMilliseconds
            [PSCustomObject]@{
                Success = $true
                ResponseTime = $duration
            }
        } catch {
            [PSCustomObject]@{
                Success = $false
                ResponseTime = 0
                Error = $_.Exception.Message
            }
        }
    } -ThrottleLimit $ConcurrentUsers
    
    $SuccessQuery = ($QueryResults | Where-Object { $_.Success }).Count
    $FailQuery = ($QueryResults | Where-Object { -not $_.Success }).Count
    $AvgQueryTime = ($QueryResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Average).Average
    $MinQueryTime = ($QueryResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Minimum).Minimum
    $MaxQueryTime = ($QueryResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Maximum).Maximum
    
    Write-Host "Query Short Link Results:"
    Write-Host "  Success: $SuccessQuery / $TotalRequests"
    Write-Host "  Failed: $FailQuery"
    if ($AvgQueryTime) {
        Write-Host "  Avg Response Time: $([math]::Round($AvgQueryTime, 2)) ms"
        Write-Host "  Min Response Time: $([math]::Round($MinQueryTime, 2)) ms"
        Write-Host "  Max Response Time: $([math]::Round($MaxQueryTime, 2)) ms"
    }
    
    # Test 3: Redirect benchmark
    Write-Host ""
    Write-Host "[Test 3] Redirect Benchmark (Redis Cache)..."
    
    $RedirectResults = 1..$TotalRequests | ForEach-Object -Parallel {
        $url = "$using:BaseUrl/$using:ShortCode"
        $start = Get-Date
        try {
            $response = Invoke-WebRequest -Uri $url -Method GET -MaximumRedirection 0 -TimeoutSec 10
            $end = Get-Date
            $duration = ($end - $start).TotalMilliseconds
            [PSCustomObject]@{
                Success = ($response.StatusCode -eq 302)
                ResponseTime = $duration
            }
        } catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 302) {
                $end = Get-Date
                $duration = ($end - $start).TotalMilliseconds
                [PSCustomObject]@{
                    Success = $true
                    ResponseTime = $duration
                }
            } else {
                [PSCustomObject]@{
                    Success = $false
                    ResponseTime = 0
                    Error = $_.Exception.Message
                }
            }
        }
    } -ThrottleLimit $ConcurrentUsers
    
    $SuccessRedirect = ($RedirectResults | Where-Object { $_.Success }).Count
    $FailRedirect = ($RedirectResults | Where-Object { -not $_.Success }).Count
    $AvgRedirectTime = ($RedirectResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Average).Average
    $MinRedirectTime = ($RedirectResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Minimum).Minimum
    $MaxRedirectTime = ($RedirectResults | Where-Object { $_.Success } | Measure-Object -Property ResponseTime -Maximum).Maximum
    
    Write-Host "Redirect Results:"
    Write-Host "  Success: $SuccessRedirect / $TotalRequests"
    Write-Host "  Failed: $FailRedirect"
    if ($AvgRedirectTime) {
        Write-Host "  Avg Response Time: $([math]::Round($AvgRedirectTime, 2)) ms"
        Write-Host "  Min Response Time: $([math]::Round($MinRedirectTime, 2)) ms"
        Write-Host "  Max Response Time: $([math]::Round($MaxRedirectTime, 2)) ms"
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "Benchmark Complete"
Write-Host "========================================"
