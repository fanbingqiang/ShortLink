# 批量插入测试数据到数据库
param(
    [int]$Count = 1000,
    [string]$BaseUrl = "http://localhost:8080"
)

Write-Host "========================================"
Write-Host "Inserting $Count test records"
Write-Host "========================================"

$success = 0
$fail = 0
$start = Get-Date

for ($i = 1; $i -le $Count; $i++) {
    $body = "{`"longUrl`":`"https://www.test$i.com/page/$i`"}"
    try {
        $null = Invoke-RestMethod -Uri "$BaseUrl/api/short-link/create" -Method POST -ContentType "application/json" -Body $body -TimeoutSec 5
        $success++
    } catch {
        $fail++
    }
    
    if ($i % 100 -eq 0) {
        Write-Host "Progress: $i / $Count (Success: $success, Failed: $fail)"
    }
}

$elapsed = [math]::Round(((Get-Date) - $start).TotalSeconds, 2)
Write-Host ""
Write-Host "========================================"
Write-Host "Complete!"
Write-Host "Total: $Count | Success: $success | Failed: $fail"
Write-Host "Time: ${elapsed}s | RPS: $([math]::Round($Count / $elapsed, 2))"
Write-Host "========================================"
