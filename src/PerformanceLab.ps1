#requires -Version 5.1
<#
.SYNOPSIS
PresentMon CSV analysis, bounded comparison and opt-in external capture.
.DESCRIPTION
No tweaks. PresentMon is never downloaded or executed without explicit SHA-256.
#>
[CmdletBinding()]
param(
    [ValidateSet('Analyze','Compare','Capture')][string]$Action='Analyze',
    [string]$InputCsv='', [string]$CandidateCsv='', [string]$ProcessName='',
    [string]$ExpectedSha256='', [ValidateRange(10,180)][int]$DurationSeconds=30,
    [switch]$Save, [switch]$Json
)
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([IO.Path]::GetPathRoot($root) -ine 'D:\') { throw 'D: workspace required.' }
 . (Join-Path $PSScriptRoot 'Workspace.ps1')
$work=Join-Path $root '.workspace'; $tmp=Join-Path $work 'tmp'
$bench=Join-Path $work 'benchmarks'
[void](Assert-JanitorWorkspacePath -Path $root -AllowedRoot 'D:\')
foreach ($path in @($work,$tmp,$bench)) {
    [void](Assert-JanitorWorkspacePath -Path $path -AllowedRoot $root)
}
[void](New-Item -ItemType Directory -Path $tmp -Force -ErrorAction Stop)
$env:TEMP=$tmp; $env:TMP=$tmp; $env:TMPDIR=$tmp
$traceId=[guid]::NewGuid().ToString('N')
$report=[ordered]@{schemaVersion=1; action=$Action; traceId=$traceId
    timestampUtc=[datetime]::UtcNow.ToString('o'); status='OK'; result=$null
    savedTo=$null; errors=@()}
function Assert-WorkspaceCsv {
    param([string]$Path)
    if (-not $Path) { throw 'PresentMon CSV path is required.' }
    $full=[IO.Path]::GetFullPath($Path)
    $prefix=[IO.Path]::GetFullPath($bench).TrimEnd('\') + '\'
    if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetExtension($full) -ine '.csv') {
        throw 'Only CSV files inside .workspace\benchmarks are accepted.'
    }
    [void](Assert-JanitorWorkspacePath -Path $full -AllowedRoot $root)
    $item=Get-Item -LiteralPath $full -ErrorAction Stop
    if ($item.PSIsContainer -or $item.Length -gt 32MB) {
        throw 'CSV must be a regular file not exceeding 32 MiB.'
    }
    return $full
}
function Get-FrameMetrics {
    param([string]$CsvPath, [string]$FilterProcess)
    $path=Assert-WorkspaceCsv $CsvPath
    $rows=@(Import-Csv -LiteralPath $path -Encoding UTF8 -ErrorAction Stop)
    if ($rows.Count -eq 0) { throw 'PresentMon CSV contains no frames.' }
    foreach ($column in @('Application','SwapChainAddress','MsBetweenPresents')) {
        if ($rows[0].PSObject.Properties.Name -notcontains $column) {
            throw "Missing PresentMon column: $column. Use PresentMon 2.x default CSV metrics."
        }
    }
    if ($FilterProcess) {
        $rows=@($rows | Where-Object { $_.Application -ieq $FilterProcess })
        if ($rows.Count -eq 0) { throw 'Requested process is absent from the CSV.' }
    } else {
        $apps=@($rows | Group-Object Application)
        if ($apps.Count -ne 1) { throw 'Multiple applications found; specify -ProcessName.' }
    }
    $application=[string]$rows[0].Application
    $group=$rows | Group-Object SwapChainAddress | Sort-Object Count -Descending |
        Select-Object -First 1
    $selected=@($group.Group)
    $samples=New-Object 'System.Collections.Generic.List[double]'
    $invariant=[Globalization.CultureInfo]::InvariantCulture
    foreach ($row in $selected) {
        $ms=[double]0
        if ([double]::TryParse([string]$row.MsBetweenPresents,
            [Globalization.NumberStyles]::Float,$invariant,[ref]$ms) -and
            -not [double]::IsNaN($ms) -and -not [double]::IsInfinity($ms) -and
            $ms -gt 0 -and $ms -lt 60000) { $samples.Add($ms) }
    }
    if ($samples.Count -lt 120) { throw "Insufficient valid frames: $($samples.Count); minimum 120." }
    $ordered=[double[]]$samples.ToArray()
    [array]::Sort($ordered)
    $sum=0.0
    foreach ($x in $ordered) { $sum+=$x }
    $mean=$sum/$ordered.Length
    $p95=$ordered[[int][math]::Ceiling($ordered.Length*0.95)-1]
    $p99=$ordered[[int][math]::Ceiling($ordered.Length*0.99)-1]
    $onePercent=[math]::Max(1,[int][math]::Ceiling($ordered.Length*0.01))
    $slowSum=0.0
    for ($i=$ordered.Length-$onePercent; $i -lt $ordered.Length; $i++) {
        $slowSum+=$ordered[$i]
    }
    $oneLow=1000/($slowSum/$onePercent)
    return [ordered]@{application=$application; swapChain=$group.Name
        validFrames=$ordered.Length; selectedSwapChainRows=$selected.Count
        discardedRows=$selected.Count-$ordered.Length
        meanFrameMs=[math]::Round($mean,3)
        estimatedFps=[math]::Round(1000/$mean,2)
        p95FrameMs=[math]::Round($p95,3)
        p99FrameMs=[math]::Round($p99,3)
        onePercentLowFps=[math]::Round($oneLow,2)
        metric='MsBetweenPresents'
        note='Present cadence estimate, not measured display FPS or input latency.'}
}
function Invoke-VerifiedCapture {
    if ($ProcessName -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,95}\.exe$') {
        throw 'Capture requires a simple executable name via -ProcessName.'
    }
    if ($ExpectedSha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'Capture requires a trusted 64-digit -ExpectedSha256.'
    }
    $binary=Join-Path $work 'tools\PresentMon.exe'
    [void](Assert-JanitorWorkspacePath -Path $binary -AllowedRoot $root)
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
        throw 'Install a reviewed PresentMon CLI binary to .workspace\tools\PresentMon.exe.'
    }
    $actual=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
    if ($actual -ine $ExpectedSha256) { throw 'PresentMon SHA-256 mismatch: execution refused.' }
    $target=[IO.Path]::GetFileNameWithoutExtension($ProcessName)
    if (@(Get-Process -Name $target -ErrorAction SilentlyContinue).Count -eq 0) {
        throw 'The requested target process is not currently running.'
    }
    $captureDir=Join-Path $bench 'captures'
    [void](Assert-JanitorWorkspacePath -Path $captureDir -AllowedRoot $root)
    [void](New-Item -ItemType Directory -Path $captureDir -Force -ErrorAction Stop)
    $file=Join-Path $captureDir ("capture-$traceId.csv")
    $args=@('--process_name',$ProcessName,'--timed',[string]$DurationSeconds,
        '--terminate_after_timed','--no_console_stats','--output_file',$file)
    $proc=Start-Process -FilePath $binary -ArgumentList $args -WorkingDirectory $work -PassThru -NoNewWindow -ErrorAction Stop
    if (-not $proc.WaitForExit(($DurationSeconds+30)*1000)) {
        try { $proc.Kill() } catch {}
        throw 'PresentMon timed out; capture was terminated.'
    }
    if ($proc.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "PresentMon failed (exit code $($proc.ExitCode)); check ETW access."
    }
    return $file
}
function Save-Report {
    $dest=Join-Path $bench 'reports'
    [void](Assert-JanitorWorkspacePath -Path $dest -AllowedRoot $root)
    [void](New-Item -ItemType Directory -Path $dest -Force -ErrorAction Stop)
    $file=Join-Path $dest ("performance-$traceId.json")
    $report.savedTo=$file
    $tmpFile=Join-Path $tmp "$traceId-performance.tmp"
    [IO.File]::WriteAllText($tmpFile,($report | ConvertTo-Json -Depth 14),
        [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmpFile -Destination $file -ErrorAction Stop
}
function Emit-PerformanceReport {
    param([int]$Code)
    if ($Json) {
        [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
        $report | ConvertTo-Json -Depth 14 -Compress
    } else {
        Write-Output "win11janitor performance-lab action=$Action status=$($report.status)"
        if ($report.savedTo) { Write-Output "Report: $($report.savedTo)" }
        foreach ($err in $report.errors) { Write-Output "ERROR: $err" }
    }
    exit $Code
}
try {
    if ($Action -eq 'Capture') {
        $InputCsv=Invoke-VerifiedCapture
        $report.result=[ordered]@{capture=$InputCsv
            metrics=(Get-FrameMetrics $InputCsv $ProcessName)}
    } elseif ($Action -eq 'Analyze') {
        $report.result=Get-FrameMetrics $InputCsv $ProcessName
    } else {
        $base=Get-FrameMetrics $InputCsv $ProcessName
        $candidate=Get-FrameMetrics $CandidateCsv $ProcessName
        if ($base.application -ine $candidate.application) {
            throw 'Cannot compare different applications.'
        }
        $report.result=[ordered]@{baseline=$base; candidate=$candidate
            fpsChangePercent=[math]::Round(($candidate.estimatedFps/$base.estimatedFps-1)*100,2)
            p99FrameMsChangePercent=[math]::Round(($candidate.p99FrameMs/$base.p99FrameMs-1)*100,2)
            verifiedSameScenario=$false
            note='Scene, graphics settings, temperature, driver and run-to-run variance are not verified by CSV alone.'}
    }
    if ($Save -or $Action -eq 'Capture') { Save-Report }
    Emit-PerformanceReport 0
} catch {
    $report.status='ERROR'; $report.errors+= $_.Exception.Message
    Emit-PerformanceReport 1
}
