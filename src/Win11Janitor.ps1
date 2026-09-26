#requires -Version 5.1
<#
.SYNOPSIS
Windows 11 Janitor: reversible, edition-aware privacy changes.
.DESCRIPTION
Audit and Plan never modify operating system settings; Apply requires elevation.
Backups, logs and temporary data stay inside this repository on D:.
#>
[CmdletBinding()]
param(
    [ValidateSet('Audit', 'Plan', 'Apply', 'Restore')]
    [string]$Action = 'Audit',
    [ValidateSet('Safe', 'Advanced')]
    [string]$Profile = 'Safe',
    [string]$Module = 'All',
    [string]$Snapshot = '',
    [switch]$WhatIf,
    [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [IO.Path]::GetFullPath((Join-Path $scriptDir '..'))
if (-not ([IO.Path]::GetPathRoot($repoRoot) -ieq 'D:\')) {
    throw 'Project workspace must be on D:; refusing any fallback to C:.'
}
$workDir = Join-Path $repoRoot '.workspace'
$tmpDir = Join-Path $workDir 'tmp'
$backupDir = Join-Path $workDir 'backups'
$logDir = Join-Path $workDir 'logs'
[void](New-Item -ItemType Directory -Path $tmpDir -Force -ErrorAction Stop)
$env:TEMP = $tmpDir
$env:TMP = $tmpDir
$env:TMPDIR = $tmpDir
. (Join-Path $scriptDir 'Modules.ps1')
. (Join-Path $scriptDir 'State.ps1')
. (Join-Path $scriptDir 'TargetDescription.ps1')
$traceId = [guid]::NewGuid().ToString('N')
$report = [ordered]@{
    action=$Action; profile=$Profile; module=$Module; traceId=$traceId
    status='OK'; snapshot=$null; results=@()
}
function Emit-Report {
    param([int]$Code)
    if ($Json) {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $report | ConvertTo-Json -Depth 15 -Compress
    } else {
        Write-Output "win11janitor action=$Action status=$($report.status) traceId=$traceId"
        if ($null -ne $report.snapshot) { Write-Output "Rollback snapshot: $($report.snapshot)" }
        foreach ($row in $report.results) {
            Write-Output ("{0} {1}: {2} {3}" -f $row.id,$row.status,$row.description,$row.detail)
        }
    }
    exit $Code
}
function Write-Journal {
    param([string]$Severity, [string]$Event, [string]$ModuleId, [string]$Result, [string]$Detail)
    $line = [ordered]@{
        timestampUtc=[datetime]::UtcNow.ToString('o')
        severity=$Severity; traceId=$traceId; event=$Event
        module=$ModuleId; result=$Result; detail=$Detail
    } | ConvertTo-Json -Compress
    Add-Content -LiteralPath (Join-Path $logDir "janitor-$traceId.jsonl") -Value $line -Encoding UTF8 -ErrorAction Stop
}
function Write-Journal-Safely {
    param([string]$Severity, [string]$Event, [string]$ModuleId,
          [string]$Result, [string]$Detail)
    try { Write-Journal $Severity $Event $ModuleId $Result $Detail }
    catch {
        $report.results += [ordered]@{
            id='LOG'; status='FAILED'; description='Journal unavailable'
            detail=$_.Exception.Message
        }
    }
}
function Is-Elevated {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Find-Operation {
    param([object]$Entry)
    if (-not $script:Catalog.Contains([string]$Entry.module)) {
        throw "Snapshot references unknown module: $($Entry.module)"
    }
    $candidate = $script:Catalog[[string]$Entry.module]
    foreach ($op in $candidate.operations) {
        if ($op.Kind -eq $Entry.kind -and $op.Path -ceq $Entry.path -and
            $op.Name -ceq $Entry.name) { return $op }
    }
    throw "Snapshot contains an unexpected target for module $($Entry.module)"
}
function Load-Snapshot {
    param([string]$File)
    if ([string]::IsNullOrWhiteSpace($File)) { throw '-Snapshot is required for Restore.' }
    $full = [IO.Path]::GetFullPath($File)
    $prefix = [IO.Path]::GetFullPath($backupDir).TrimEnd('\') + '\'
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Restore accepts only D:\win11janitor\.workspace\backups\*.json.'
    }
    if ([IO.Path]::GetExtension($full) -ine '.json' -or
        -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw 'Snapshot does not exist or is not a JSON snapshot.'
    }
    $data = Get-Content -LiteralPath $full -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($data.schemaVersion -ne 1 -or $data.root -ine $repoRoot -or
        @($data.entries).Count -eq 0) {
        throw 'Snapshot schema, workspace or entry count is invalid.'
    }
    foreach ($entry in $data.entries) {
        $op = Find-Operation $entry
        if ($op.Kind -eq 'Registry' -and $entry.present -and
            $entry.previousKind -notin @('DWord', 'String', 'ExpandString')) {
            throw 'Unsupported registry value type in snapshot.'
        }
        if ($op.Kind -eq 'Service' -and $entry.present -and
            [int]$entry.previousStart -notin @(2,3,4)) {
            throw 'Unsupported service start type in snapshot.'
        }
    }
    return $data
}
try {
    if ($Action -eq 'Restore') {
        $data = Load-Snapshot $Snapshot
        if ($WhatIf) {
            foreach ($entry in $data.entries) {
                $report.results += [ordered]@{
                    id=$entry.module; status='WOULD_RESTORE'
                    description=$entry.kind; detail=$entry.name
                }
            }
            Emit-Report 0
        }
        if (-not (Is-Elevated)) { throw 'Administrator rights required for Restore.' }
        [void](New-Item -ItemType Directory -Path $logDir -Force)
        $lock = [IO.File]::Open((Join-Path $workDir 'janitor.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        $restoreFailed = $false
        try {
            $entries = @($data.entries)
            [array]::Reverse($entries)
            foreach ($entry in $entries) {
                try {
                    Restore-Target $entry
                    $op = Find-Operation $entry
                    if (-not (Confirm-Restored $op $entry)) {
                        throw "Verification failed for $($entry.name)"
                    }
                    $report.results += [ordered]@{
                        id=$entry.module; status='RESTORED'
                        description=$entry.kind; detail=$entry.name
                    }
                    Write-Journal 'Info' 'Restore' $entry.module 'RESTORED' $entry.name
                } catch {
                    $restoreFailed = $true
                    $report.results += [ordered]@{
                        id=$entry.module; status='FAILED'
                        description=$entry.kind; detail=$_.Exception.Message
                    }
                    Write-Journal-Safely 'Critical' 'Restore' $entry.module 'FAILED' $_.Exception.Message
                }
            }
        } finally {
            $lock.Dispose()
        }
        if ($restoreFailed) { $report.status='ERROR'; Emit-Report 1 }
        $report.status='RESTORED'
        Emit-Report 0
    }
    if ($Module -ieq 'All') {
        $selected = @($script:Catalog.Values | Where-Object {
            $_.mode -eq 'Safe' -or ($Profile -eq 'Advanced' -and $_.mode -eq 'Optional')
        })
    } else {
        $selected = @()
        foreach ($part in $Module.Split(',')) {
            $id = $part.Trim()
            if (-not $script:Catalog.Contains($id)) {
                throw "Unknown module '$id'. Available: $($script:Catalog.Keys -join ', ')"
            }
            if (@($selected | Where-Object { $_.id -eq $id }).Count -eq 0) {
                $selected += $script:Catalog[$id]
            }
        }
    }
    if ($selected.Count -eq 0) { throw 'No modules selected.' }
    if ($Action -eq 'Plan' -or ($Action -eq 'Apply' -and $WhatIf)) {
        $blocked = $false
        foreach ($item in $selected) {
            $status = if ($item.mode -eq 'AuditOnly') { 'AUDIT_ONLY' } elseif ($WhatIf) { 'WOULD_APPLY' } else { 'PLANNED' }
            if ($Action -eq 'Apply' -and $item.mode -eq 'AuditOnly') { $blocked=$true }
            $report.results += [ordered]@{
                id=$item.id; status=$status; description=$item.description
                detail=("Targets: " + @($item.operations).Count)
                targets=@($item.operations | ForEach-Object { Describe-Target $_ })
            }
        }
        if ($blocked) { $report.status='ERROR'; Emit-Report 3 }
        Emit-Report 0
    }
    if ($Action -eq 'Audit') {
        foreach ($item in $selected) {
            if ($item.mode -eq 'AuditOnly') {
                $report.results += [ordered]@{
                    id=$item.id; status='AUDIT_ONLY'
                    description=$item.description; detail='No changes performed'
                }
                continue
            }
            $states = @($item.operations | ForEach-Object { Read-Target $_ $item.id })
            $upToDate = $true
            $missing = 0
            for ($i=0; $i -lt $item.operations.Count; $i++) {
                if (-not $states[$i].present -and $item.operations[$i].Kind -ne 'Registry') {
                    $missing++
                } elseif (-not (Test-Target $item.operations[$i] $states[$i])) {
                    $upToDate = $false
                }
            }
            $status = if ($missing -eq $item.operations.Count) { 'NOT_FOUND' } elseif ($upToDate -and $missing -eq 0) { 'ALREADY_CONFIGURED' } else { 'CHANGE_AVAILABLE' }
            $report.results += [ordered]@{
                id=$item.id; status=$status; description=$item.description
                detail=("$missing missing targets")
            }
        }
        Emit-Report 0
    }
    if ($Action -ne 'Apply') { throw "Unsupported action $Action" }
    $unsupported = @($selected | Where-Object { $_.mode -eq 'AuditOnly' })
    if ($unsupported.Count -gt 0) {
        foreach ($item in $unsupported) {
            $report.results += [ordered]@{
                id=$item.id; status='AUDIT_ONLY'; description=$item.description
                detail='Refused to apply a speculative or risky tweak'
            }
        }
        $report.status='ERROR'; Emit-Report 3
    }
    if (-not (Is-Elevated)) { throw 'Administrator rights required for Apply.' }
    [void](New-Item -ItemType Directory -Path $backupDir -Force)
    [void](New-Item -ItemType Directory -Path $logDir -Force)
    $lock = [IO.File]::Open((Join-Path $workDir 'janitor.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $exitCode = 0
    $touched = @()
    try {
        $entries = @()
        foreach ($item in $selected) {
            foreach ($op in $item.operations) {
                $entries += (Read-Target $op $item.id)
            }
        }
        $stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
        $snapshotFile = Join-Path $backupDir "$stamp-$traceId.json"
        $snapshotObj = [ordered]@{
            schemaVersion=1; createdUtc=[datetime]::UtcNow.ToString('o')
            traceId=$traceId; root=$repoRoot; modules=@($selected | ForEach-Object id)
            entries=$entries
        }
        $snapshotJson = $snapshotObj | ConvertTo-Json -Depth 15
        $tempSnapshot = Join-Path $tmpDir "$traceId.json.tmp"
        [IO.File]::WriteAllText($tempSnapshot, $snapshotJson, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempSnapshot -Destination $snapshotFile -ErrorAction Stop
        $report.snapshot = $snapshotFile
        Write-Journal 'Info' 'Snapshot' '' 'SAVED' $snapshotFile
        foreach ($item in $selected) {
            $outcomes = @()
            foreach ($op in $item.operations) {
                $orig = @($entries | Where-Object {
                    $_.module -eq $item.id -and $_.kind -eq $op.Kind -and
                    $_.path -ceq $op.Path -and $_.name -ceq $op.Name
                })[0]
                $touched += $orig
                $outcome = Set-Target $op $orig
                if ($outcome -ne 'NOT_FOUND') {
                    $current = Read-Target $op $item.id
                    if (-not (Test-Target $op $current)) {
                        throw "Post-apply verification failed: $($item.id)/$($op.Name)"
                    }
                }
                $outcomes += $outcome
                Write-Journal 'Info' 'Apply' $item.id $outcome $op.Name
            }
            $status = if ('NOT_FOUND' -in $outcomes) { 'PARTIAL' } elseif ('APPLIED' -in $outcomes) { 'APPLIED' } else { 'UNCHANGED' }
            if ($status -eq 'PARTIAL') { $exitCode=2 }
            $report.results += [ordered]@{
                id=$item.id; status=$status; description=$item.description
                detail=($outcomes -join ',')
            }
        }
        $report.status = if ($exitCode -eq 2) { 'PARTIAL' } else { 'APPLIED' }
    } catch {
        $problem = $_.Exception.Message
        $report.status='ROLLBACK_ATTEMPTED'
        $report.results += [ordered]@{
            id='SYSTEM'; status='FAILED'; description='Apply'
            detail=$problem
        }
        Write-Journal-Safely 'Critical' 'Apply' '' 'FAILED' $problem
        $rollbackErrors = @()
        $reverse = @($touched)
        [array]::Reverse($reverse)
        foreach ($entry in $reverse) {
            try {
                Restore-Target $entry
                $originalOp = Find-Operation $entry
                if (-not (Confirm-Restored $originalOp $entry)) {
                    throw "Could not verify rollback for $($entry.module)/$($entry.name)"
                }
            } catch { $rollbackErrors += $_.Exception.Message }
        }
        if ($rollbackErrors.Count -gt 0) {
            $report.status='ROLLBACK_FAILED'
            $report.results += [ordered]@{
                id='SYSTEM'; status='FAILED'; description='Rollback'
                detail=($rollbackErrors -join ' | ')
            }
            Write-Journal-Safely 'Critical' 'Rollback' '' 'FAILED' ($rollbackErrors -join ' | ')
        } else {
            $report.status='ROLLED_BACK'
            Write-Journal-Safely 'Warning' 'Rollback' '' 'RESTORED' $problem
        }
        $exitCode=1
    } finally {
        $lock.Dispose()
    }
    Emit-Report $exitCode
} catch {
    $report.status='ERROR'
    $report.results += [ordered]@{
        id='SYSTEM'; status='ERROR'; description='Execution blocked'
        detail=$_.Exception.Message
    }
    Emit-Report 1
}
