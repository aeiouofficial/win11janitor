#requires -Version 5.1
<#
.SYNOPSIS
Read-only inventory. -Save writes JSON under D: workspace only.
#>
[CmdletBinding()]
param(
    [ValidateSet('All','Hardware','Startup','Interrupts')][string]$Category = 'All',
    [switch]$Save, [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([IO.Path]::GetPathRoot($root) -ine 'D:\') { throw 'Repository must reside on D:.' }
 . (Join-Path $PSScriptRoot 'Workspace.ps1')
$work = Join-Path $root '.workspace'; $tmp = Join-Path $work 'tmp'
[void](Assert-JanitorWorkspacePath -Path $root -AllowedRoot 'D:\')
[void](Assert-JanitorWorkspacePath -Path $tmp -AllowedRoot $root)
[void](New-Item -ItemType Directory -Path $tmp -Force -ErrorAction Stop)
$env:TEMP=$tmp; $env:TMP=$tmp; $env:TMPDIR=$tmp
. (Join-Path $PSScriptRoot 'Capabilities.ps1')
$traceId=[guid]::NewGuid().ToString('N')
$report=[ordered]@{schemaVersion=1; timestampUtc=[datetime]::UtcNow.ToString('o')
    traceId=$traceId; category=$Category; status='OK'; probes=@{}; savedTo=$null}
function Invoke-Probe {
    param([string]$Name, [scriptblock]$Action)
    try { $v = & $Action; $report.probes[$Name]=[ordered]@{status='OK'; data=$v} }
    catch { $report.status='PARTIAL'; $report.probes[$Name]=[ordered]@{
        status='UNAVAILABLE'; reason=$_.Exception.Message} }
}
function Get-HardwareInventory {
    $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $cpu=@(Get-CimInstance Win32_Processor -ErrorAction Stop | ForEach-Object {
        [ordered]@{name=$_.Name; physicalCores=$_.NumberOfCores
            logicalProcessors=$_.NumberOfLogicalProcessors; maxClockMHz=$_.MaxClockSpeed}
    })
    $gpus=@(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
        [ordered]@{name=$_.Name; driverVersion=$_.DriverVersion; status=$_.Status}
    })
    $memory=[math]::Round(([double]$os.TotalVisibleMemorySize*1024/1GB),2)
    $disks=@()
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        $disks=@(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
            [ordered]@{name=$_.FriendlyName; mediaType=[string]$_.MediaType
                health=[string]$_.HealthStatus; sizeGB=[math]::Round($_.Size/1GB,1)}
        })
    }
    $battery=@(Get-CimInstance Win32_Battery -ErrorAction Stop | ForEach-Object {
        [ordered]@{name=$_.Name; batteryStatus=$_.BatteryStatus
            estimatedChargeRemaining=$_.EstimatedChargeRemaining}
    })
    $caps=Get-JanitorCapabilities
    return [ordered]@{
        windows=[ordered]@{caption=$os.Caption; edition=$cv.EditionID
            build=[int]$os.BuildNumber; client=([int]$os.ProductType -eq 1)}
        cpu=$cpu; gpu=$gpus; memoryGB=$memory
        disks=$disks; batteries=$battery
        capabilities=[ordered]@{edgePresent=$caps.edgePresent}
        notes=@('Storage media type is reported by Windows, not independently verified.',
                'P-core/E-core classification and FPS are not inferred from CPU model names.')
    }
}
function Get-StartupInventory {
    $entries=@()
    foreach ($pair in @(
        @{scope='Machine';path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'},
        @{scope='User';path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'}
    )) {
        if (-not (Test-Path -LiteralPath $pair.path)) { continue }
        $key=Get-Item -LiteralPath $pair.path -ErrorAction Stop
        foreach ($name in @($key.GetValueNames())) {
            $entries += [ordered]@{name=$name; scope=$pair.scope; source='Run';
                commandRedacted=$true}
        }
    }
    $tasks=@()
    foreach ($task in @(Get-ScheduledTask -ErrorAction Stop)) {
        foreach ($trigger in @($task.Triggers)) {
            if ($null -ne $trigger -and $trigger.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger') {
                $tasks += [ordered]@{name=$task.TaskName; path=$task.TaskPath
                    state=[string]$task.State; trigger='Logon'}
                break
            }
        }
    }
    $folders=@()
    foreach ($f in @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp')
    )) {
        if (Test-Path -LiteralPath $f -PathType Container) {
            $scope = if ($f.StartsWith($env:APPDATA,[StringComparison]::OrdinalIgnoreCase)) { 'User' } else { 'Machine' }
            $folders += @(Get-ChildItem -LiteralPath $f -File -ErrorAction Stop | ForEach-Object {
                [ordered]@{name=$_.Name; scope=$scope}
            })
        }
    }
    return [ordered]@{runEntries=$entries; logonTasks=$tasks; startupFolderEntries=$folders
        note='Startup commands are omitted to avoid leaking private paths and tokens.'}
}
function Get-InterruptInventory {
    $results=@()
    $devices=@(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object {
        $_.PNPDeviceID -like 'PCI\*' -and $_.PNPClass -in @('Display','Net','USB','MEDIA')
    })
    foreach ($device in $devices) {
        $base='HKLM:\SYSTEM\CurrentControlSet\Enum\' + $device.PNPDeviceID +
            '\Device Parameters\Interrupt Management'
        $row=[ordered]@{device=$device.Name; class=$device.PNPClass
            msiMode='UNKNOWN'; affinityPolicy='DEFAULT_OR_UNKNOWN'
            affinityMaskHex=$null; status='OK'}
        try {
            $msi=Join-Path $base 'MessageSignaledInterruptProperties'
            if (Test-Path -LiteralPath $msi) {
                $key=Get-Item -LiteralPath $msi -ErrorAction Stop
                if (@($key.GetValueNames()) -contains 'MSISupported') {
                    $row.msiMode=if ([int]$key.GetValue('MSISupported') -eq 1) {'ENABLED_IN_REGISTRY'} else {'DISABLED_IN_REGISTRY'}
                }
            }
            $aff=Join-Path $base 'Affinity Policy'
            if (Test-Path -LiteralPath $aff) {
                $key=Get-Item -LiteralPath $aff -ErrorAction Stop
                if (@($key.GetValueNames()) -contains 'DevicePolicy') {
                    $row.affinityPolicy=[int]$key.GetValue('DevicePolicy')
                }
                if (@($key.GetValueNames()) -contains 'AssignmentSetOverride') {
                    $v=[byte[]]$key.GetValue('AssignmentSetOverride')
                    $row.affinityMaskHex=[BitConverter]::ToString($v).Replace('-','')
                }
            }
        } catch { $row.status='UNAVAILABLE'; $row.msiMode='UNKNOWN' }
        $results += $row
    }
    return [ordered]@{devices=$results
        note='Registry policy only. Actual ISR/DPC routing requires ETW verification.'}
}
if ($Category -in @('All','Hardware')) { Invoke-Probe 'Hardware' { Get-HardwareInventory } }
if ($Category -in @('All','Startup')) { Invoke-Probe 'Startup' { Get-StartupInventory } }
if ($Category -in @('All','Interrupts')) { Invoke-Probe 'Interrupts' { Get-InterruptInventory } }
if ($Save) {
    $dest=Join-Path $work 'benchmarks'
    [void](Assert-JanitorWorkspacePath -Path $dest -AllowedRoot $root)
    [void](New-Item -ItemType Directory -Path $dest -Force -ErrorAction Stop)
    $filename=Join-Path $dest ("inventory-" + [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + "-$traceId.json")
    $report.savedTo=$filename
    $payload=$report | ConvertTo-Json -Depth 18
    $tempfile=Join-Path $tmp "$traceId-inventory.tmp"
    [IO.File]::WriteAllText($tempfile,$payload,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempfile -Destination $filename -ErrorAction Stop
}
if ($Json) {
    [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
    $report | ConvertTo-Json -Depth 18 -Compress
} else {
    Write-Output "win11janitor diagnostics category=$Category status=$($report.status) traceId=$traceId"
    foreach ($name in $report.probes.Keys) {
        Write-Output ($name + ': ' + $report.probes[$name].status)
    }
    if ($report.savedTo) { Write-Output "Inventory: $($report.savedTo)" }
}
if ($report.status -eq 'PARTIAL') { exit 2 }
exit 0
