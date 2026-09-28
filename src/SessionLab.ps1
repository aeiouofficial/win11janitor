#requires -Version 5.1
<#
.SYNOPSIS
Transactional, opt-in EcoQoS sessions for explicitly selected background apps.
.DESCRIPTION
Inspect/Plan are read-only. Apply requires a saved, identity-bound plan plus
-Experimental. No game-process priority, affinity, CPU-set or anti-cheat writes.
#>
[CmdletBinding()]
param(
    [ValidateSet('Inspect','Plan','Apply','Restore')][string]$Action='Inspect',
    [int[]]$ProcessId=@(), [int[]]$BackgroundProcessId=@(),
    [string]$Plan='', [string]$Session='',
    [ValidateRange(1,120)][int]$PlanLifetimeMinutes=30,
    [switch]$Experimental, [switch]$ForceRestore, [switch]$Json
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([IO.Path]::GetPathRoot($root) -ine 'D:\') { throw 'D: repository required.' }
. (Join-Path $PSScriptRoot 'Workspace.ps1')
$work=Join-Path $root '.workspace'
$tmp=Join-Path $work 'tmp'; $sessions=Join-Path $work 'sessions'
$plans=Join-Path $sessions 'plans'
foreach($path in @($root,$work,$tmp,$sessions,$plans)) {
    [void](Assert-JanitorWorkspacePath -Path $path -AllowedRoot 'D:\')
}
[void](New-Item -ItemType Directory -Path $tmp -Force -ErrorAction Stop)
$env:TEMP=$tmp; $env:TMP=$tmp; $env:TMPDIR=$tmp
if (-not ('Win11Janitor.ProcessSessionNative' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'ProcessSessionNative.cs') -ErrorAction Stop
}
$traceId=[guid]::NewGuid().ToString('N')
$currentSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$currentSession=(Get-Process -Id $PID -ErrorAction Stop).SessionId
$report=[ordered]@{schemaVersion=1;action=$Action;traceId=$traceId
    status='OK';results=@();plan=$null;session=$null}
$blockedFragments=@('Riot Vanguard','EasyAntiCheat','Easy Anti-Cheat',
    'BattlEye','FACEIT','BEService','vgc.exe','vgk')

function Emit-SessionReport {
    param([int]$Code)
    if($Json) {
        [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
        $report | ConvertTo-Json -Depth 20 -Compress
    } else {
        Write-Output "win11janitor session-lab action=$Action status=$($report.status) traceId=$traceId"
        foreach($row in $report.results) {
            Write-Output ("{0}: {1}" -f $row.status,$row.detail)
        }
        if($report.plan){Write-Output "Plan: $($report.plan)"}
        if($report.session){Write-Output "Session: $($report.session)"}
    }
    exit $Code
}
function Write-AtomicJson {
    param([string]$Path,[object]$Value)
    [void](Assert-JanitorWorkspacePath -Path $Path -AllowedRoot $root)
    $temp=Join-Path $tmp ("session-" + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($temp,($Value|ConvertTo-Json -Depth 24),
        [Text.UTF8Encoding]::new($false))
    if(Test-Path -LiteralPath $Path -PathType Leaf) {
        [IO.File]::Replace($temp,$Path,$null)
    } else {
        Move-Item -LiteralPath $temp -Destination $Path -ErrorAction Stop
    }
}
function Resolve-DirectJson {
    param([string]$Path,[string]$Directory)
    if([string]::IsNullOrWhiteSpace($Path)){throw 'A JSON path is required.'}
    $full=[IO.Path]::GetFullPath($Path)
    [void](Assert-JanitorWorkspacePath -Path $full -AllowedRoot $Directory)
    if([IO.Path]::GetDirectoryName($full) -ine
        [IO.Path]::GetFullPath($Directory).TrimEnd('\')) {
        throw 'Nested or redirected session paths are not accepted.'
    }
    if([IO.Path]::GetExtension($full) -ine '.json' -or
        -not(Test-Path -LiteralPath $full -PathType Leaf)) {
        throw 'Session JSON does not exist.'
    }
    return $full
}
function Get-OwnerSid {
    param([int]$Id)
    $proc=Get-CimInstance Win32_Process -Filter "ProcessId=$Id" -ErrorAction Stop
    if($null -eq $proc){throw "Process $Id no longer exists."}
    $owner=Invoke-CimMethod -InputObject $proc -MethodName GetOwnerSid -ErrorAction Stop
    if([int]$owner.ReturnValue -ne 0 -or -not $owner.Sid) {
        throw "Cannot verify owner SID for process $Id."
    }
    return [string]$owner.Sid
}
function Get-ProcessDescriptor {
    param([int]$Id)
    if($Id -le 0){throw 'Process IDs must be positive.'}
    $native=[Win11Janitor.ProcessSessionNative]::ReadProcessState($Id)
    $path=[IO.Path]::GetFullPath([string]$native.ImagePath)
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Executable path for PID $Id is unavailable."
    }
    $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash
    $owner=Get-OwnerSid $Id
    $managed=Get-Process -Id $Id -ErrorAction Stop
    $name=[IO.Path]::GetFileName($path)
    return [ordered]@{
        pid=$Id; name=$name; imagePath=$path; sha256=$hash
        creationFileTimeUtc=[long]$native.CreationFileTimeUtc
        sessionId=[uint32]$native.SessionId; ownerSid=$owner
        isCritical=[bool]$native.IsCritical
        hasMainWindow=([intptr]$managed.MainWindowHandle -ne [intptr]::Zero)
        powerControlMask=[uint32]$native.PowerControlMask
        powerStateMask=[uint32]$native.PowerStateMask
        defaultCpuSets=@($native.DefaultCpuSets)
        ecoQosControlled=((([uint32]$native.PowerControlMask) -band 1) -ne 0)
        ecoQosEnabled=((([uint32]$native.PowerStateMask) -band 1) -ne 0)
    }
}
function Assert-BackgroundCandidate {
    param([object]$Descriptor)
    if($Descriptor.pid -eq $PID){throw 'Refusing to throttle the SessionLab process itself.'}
    if($Descriptor.ownerSid -cne $currentSid) {
        throw "PID $($Descriptor.pid) belongs to a different Windows account."
    }
    if([int]$Descriptor.sessionId -ne [int]$currentSession) {
        throw "PID $($Descriptor.pid) is outside the current interactive session."
    }
    if([bool]$Descriptor.isCritical) {
        throw "PID $($Descriptor.pid) is marked critical by Windows."
    }
    if([bool]$Descriptor.hasMainWindow) {
        throw "PID $($Descriptor.pid) owns a top-level window; EcoQoS is limited to explicit background processes."
    }
    $win=[IO.Path]::GetFullPath($env:WINDIR).TrimEnd('\')+'\'
    if($Descriptor.imagePath.StartsWith($win,[StringComparison]::OrdinalIgnoreCase)) {
        throw "PID $($Descriptor.pid) is a Windows-system executable."
    }
    foreach($marker in $blockedFragments) {
        if($Descriptor.imagePath.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "PID $($Descriptor.pid) matches an anti-cheat safety marker '$marker'."
        }
    }
}
function Test-IdentityMatch {
    param([object]$Expected,[object]$Current)
    return ([int]$Expected.pid -eq [int]$Current.pid -and
        [long]$Expected.creationFileTimeUtc -eq [long]$Current.creationFileTimeUtc -and
        [string]$Expected.imagePath -ceq [string]$Current.imagePath -and
        [string]$Expected.sha256 -ceq [string]$Current.sha256 -and
        [string]$Expected.ownerSid -ceq [string]$Current.ownerSid)
}
function Get-CpuTopologySummary {
    $sets=@([Win11Janitor.ProcessSessionNative]::ReadCpuSetTopology())
    $classes=@($sets|Group-Object EfficiencyClass|Sort-Object {[int]$_.Name}|
        ForEach-Object {[ordered]@{efficiencyClass=[int]$_.Name;logicalCpuSets=$_.Count}})
    $max=$null
    if($sets.Count -gt 0){$max=($sets|Measure-Object -Property EfficiencyClass -Maximum).Maximum}
    return [ordered]@{cpuSets=$sets.Count;efficiencyClasses=$classes
        heterogeneous=($classes.Count -gt 1);highestPerformanceClass=$max
        note='Windows defines higher EfficiencyClass as faster and less power-efficient; no CPU-set writes are performed.'}
}
function Read-JsonFile {
    param([string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop)
}
function Assert-PlanProcessCurrent {
    param([object]$Entry)
    $current=Get-ProcessDescriptor ([int]$Entry.pid)
    Assert-BackgroundCandidate $current
    if(-not(Test-IdentityMatch $Entry $current)) {
        throw "Process identity changed for PID $($Entry.pid)."
    }
    if([uint32]$current.powerControlMask -ne [uint32]$Entry.originalPowerControlMask -or
        [uint32]$current.powerStateMask -ne [uint32]$Entry.originalPowerStateMask) {
        throw "Power throttling state changed after plan for PID $($Entry.pid)."
    }
    return $current
}
try {
    if($Action -eq 'Inspect') {
        if($ProcessId.Count -eq 0){throw '-ProcessId is required for Inspect.'}
        $items=@()
        foreach($id in @($ProcessId|Select-Object -Unique)) {
            try {$items+=Get-ProcessDescriptor $id}
            catch {$items+=[ordered]@{pid=$id;status='UNAVAILABLE';reason=$_.Exception.Message}}
        }
        $report.results+=[ordered]@{status='READ_ONLY';detail='Process state inspected'
            processes=$items;cpuTopology=(Get-CpuTopologySummary)}
        Emit-SessionReport 0
    }
    if($Action -eq 'Plan') {
        if($BackgroundProcessId.Count -eq 0){throw '-BackgroundProcessId is required for Plan.'}
        if($BackgroundProcessId.Count -gt 16){throw 'At most 16 background PIDs per session.'}
        $entries=@()
        foreach($id in @($BackgroundProcessId|Select-Object -Unique)) {
            $d=Get-ProcessDescriptor $id
            Assert-BackgroundCandidate $d
            $entries+=[ordered]@{
                pid=$d.pid;name=$d.name;imagePath=$d.imagePath;sha256=$d.sha256
                creationFileTimeUtc=$d.creationFileTimeUtc;ownerSid=$d.ownerSid
                sessionId=$d.sessionId;isCritical=$d.isCritical;hasMainWindow=$d.hasMainWindow
                defaultCpuSets=$d.defaultCpuSets
                originalPowerControlMask=$d.powerControlMask
                originalPowerStateMask=$d.powerStateMask
                desiredPowerControlMask=([uint32]$d.powerControlMask -bor 1)
                desiredPowerStateMask=([uint32]$d.powerStateMask -bor 1)
                change='EcoQoSBackground'
            }
        }
        [void](New-Item -ItemType Directory -Path $plans -Force -ErrorAction Stop)
        $now=[datetime]::UtcNow
        $planObj=[ordered]@{schemaVersion=1;kind='EcoQoSPlan';state='PLANNED'
            createdUtc=$now.ToString('o')
            expiresUtc=$now.AddMinutes($PlanLifetimeMinutes).ToString('o')
            userSid=$currentSid;sessionId=$currentSession;entries=$entries
            cpuTopology=(Get-CpuTopologySummary)
            source='Microsoft SetProcessInformation/ProcessPowerThrottling'}
        $path=Join-Path $plans ("plan-$($now.ToString('yyyyMMddTHHmmssZ'))-$traceId.json")
        Write-AtomicJson $path $planObj
        $report.plan=$path
        $report.results+=[ordered]@{status='PLANNED';detail="$($entries.Count) background process(es)"
            processes=$entries}
        Emit-SessionReport 0
    }
    if($Action -eq 'Apply') {
        if(-not $Experimental){throw 'Apply requires explicit -Experimental.'}
        $planPath=Resolve-DirectJson $Plan $plans
        $data=Read-JsonFile $planPath
        if($data.schemaVersion -ne 1 -or $data.kind -ne 'EcoQoSPlan' -or
            $data.state -ne 'PLANNED'){throw 'Unsupported or already-consumed plan.'}
        if($data.userSid -cne $currentSid){throw 'Plan belongs to another Windows account.'}
        if([int]$data.sessionId -ne [int]$currentSession){throw 'Plan belongs to another session.'}
        if([datetime]::Parse($data.expiresUtc).ToUniversalTime() -lt [datetime]::UtcNow) {
            throw 'Plan expired; create a fresh plan.'
        }
        foreach($entry in @($data.entries)){[void](Assert-PlanProcessCurrent $entry)}
        [void](New-Item -ItemType Directory -Path $sessions -Force -ErrorAction Stop)
        $sessionObj=[ordered]@{schemaVersion=1;kind='EcoQoSSession';state='PREPARED'
            createdUtc=[datetime]::UtcNow.ToString('o');userSid=$currentSid
            sourcePlan=$planPath;entries=@($data.entries);results=@()}
        $sessionPath=Join-Path $sessions ("session-$([datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))-$traceId.json")
        Write-AtomicJson $sessionPath $sessionObj
        $report.session=$sessionPath
        $touched=@()
        try {
            foreach($entry in @($sessionObj.entries)) {
                [Win11Janitor.ProcessSessionNative]::SetPowerState(
                    [int]$entry.pid,[long]$entry.creationFileTimeUtc,
                    [uint32]$entry.desiredPowerControlMask,[uint32]$entry.desiredPowerStateMask)
                $touched+=,$entry
                $verify=[Win11Janitor.ProcessSessionNative]::ReadProcessState([int]$entry.pid)
                if([uint32]$verify.PowerControlMask -ne [uint32]$entry.desiredPowerControlMask -or
                    [uint32]$verify.PowerStateMask -ne [uint32]$entry.desiredPowerStateMask) {
                    throw "EcoQoS verification failed for PID $($entry.pid)."
                }
                $sessionObj.results+=,[ordered]@{pid=$entry.pid;status='APPLIED'}
                Write-AtomicJson $sessionPath $sessionObj
            }
            $sessionObj.state='APPLIED';$sessionObj.appliedUtc=[datetime]::UtcNow.ToString('o')
            Write-AtomicJson $sessionPath $sessionObj
            $data.state='CONSUMED';$data.session=$sessionPath
            Write-AtomicJson $planPath $data
            $report.results+=[ordered]@{status='APPLIED';detail="$($touched.Count) EcoQoS process(es)"}
            Emit-SessionReport 0
        } catch {
            $problem=$_.Exception.Message;$rollbackErrors=@()
            $reverse=@($touched);[array]::Reverse($reverse)
            foreach($entry in $reverse) {
                try {
                    [Win11Janitor.ProcessSessionNative]::SetPowerState(
                        [int]$entry.pid,[long]$entry.creationFileTimeUtc,
                        [uint32]$entry.originalPowerControlMask,[uint32]$entry.originalPowerStateMask)
                } catch {$rollbackErrors+=$_.Exception.Message}
            }
            $sessionObj.state=if($rollbackErrors.Count){'ROLLBACK_FAILED'}else{'ROLLED_BACK'}
            $sessionObj.error=$problem;$sessionObj.rollbackErrors=$rollbackErrors
            Write-AtomicJson $sessionPath $sessionObj
            $data.state='FAILED';$data.session=$sessionPath;$data.error=$problem
            Write-AtomicJson $planPath $data
            throw "$problem Rollback errors: $($rollbackErrors -join ' | ')"
        }
    }
    if($Action -eq 'Restore') {
        $sessionPath=Resolve-DirectJson $Session $sessions
        $data=Read-JsonFile $sessionPath
        if($data.schemaVersion -ne 1 -or $data.kind -ne 'EcoQoSSession') {
            throw 'Unsupported session journal.'
        }
        if($data.userSid -cne $currentSid){throw 'Session belongs to another Windows account.'}
        if($data.state -notin @('APPLIED','ROLLBACK_FAILED','RESTORE_FAILED')) {
            throw "Session state '$($data.state)' is not restorable."
        }
        $workItems=@();$conflicts=@()
        foreach($entry in @($data.entries)) {
            if($null -eq (Get-Process -Id ([int]$entry.pid) -ErrorAction SilentlyContinue)) {
                $workItems+=,[ordered]@{entry=$entry;state='EXITED';current=$null};continue
            }
            try {
                $current=Get-ProcessDescriptor ([int]$entry.pid)
                if(-not(Test-IdentityMatch $entry $current)) {
                    $conflicts+="PID $($entry.pid) identity changed";continue
                }
                $atApplied=([uint32]$current.powerControlMask -eq [uint32]$entry.desiredPowerControlMask -and
                    [uint32]$current.powerStateMask -eq [uint32]$entry.desiredPowerStateMask)
                $atOriginal=([uint32]$current.powerControlMask -eq [uint32]$entry.originalPowerControlMask -and
                    [uint32]$current.powerStateMask -eq [uint32]$entry.originalPowerStateMask)
                if(-not $atApplied -and -not $atOriginal -and -not $ForceRestore) {
                    $conflicts+="PID $($entry.pid) power state changed externally";continue
                }
                $workItems+=,[ordered]@{entry=$entry
                    state=if($atOriginal){'ORIGINAL'}else{'RESTORE'};current=$current}
            } catch {$conflicts+="PID $($entry.pid): $($_.Exception.Message)"}
        }
        if($conflicts.Count) {
            $report.status='CONFLICT'
            $report.results+=[ordered]@{status='CONFLICT';detail=($conflicts -join ' | ')}
            Emit-SessionReport 4
        }
        $failed=@()
        foreach($item in $workItems) {
            $entry=$item.entry
            if($item.state -eq 'EXITED') {
                $report.results+=[ordered]@{status='EXITED';detail="PID $($entry.pid) exited; volatile state is gone"}
                continue
            }
            if($item.state -eq 'ORIGINAL') {
                $report.results+=[ordered]@{status='UNCHANGED';detail="PID $($entry.pid) already original"}
                continue
            }
            try {
                [Win11Janitor.ProcessSessionNative]::SetPowerState(
                    [int]$entry.pid,[long]$entry.creationFileTimeUtc,
                    [uint32]$entry.originalPowerControlMask,[uint32]$entry.originalPowerStateMask)
                $verify=[Win11Janitor.ProcessSessionNative]::ReadProcessState([int]$entry.pid)
                if([uint32]$verify.PowerControlMask -ne [uint32]$entry.originalPowerControlMask -or
                    [uint32]$verify.PowerStateMask -ne [uint32]$entry.originalPowerStateMask) {
                    throw 'Post-restore verification failed.'
                }
                $report.results+=[ordered]@{status='RESTORED';detail="PID $($entry.pid)"}
            } catch {$failed+="PID $($entry.pid): $($_.Exception.Message)"}
        }
        if($failed.Count) {
            $data.state='RESTORE_FAILED';$data.restoreErrors=$failed
            Write-AtomicJson $sessionPath $data
            $report.status='ERROR';$report.results+=[ordered]@{status='FAILED';detail=($failed -join ' | ')}
            Emit-SessionReport 1
        }
        $data.state='RESTORED';$data.restoredUtc=[datetime]::UtcNow.ToString('o')
        Write-AtomicJson $sessionPath $data
        $report.session=$sessionPath
        Emit-SessionReport 0
    }
    throw "Unsupported action $Action"
} catch {
    $report.status='ERROR'
    $report.results+=[ordered]@{status='ERROR';detail=$_.Exception.Message}
    Emit-SessionReport 1
}
