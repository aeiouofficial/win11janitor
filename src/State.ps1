# Read and restore original values before and after each module.
function Get-RegistryKeyOrNull {
    param([string]$Path)
    try { return (Get-Item -LiteralPath $Path -ErrorAction Stop) }
    catch [System.Management.Automation.ItemNotFoundException] { return $null }
}
function Read-Target {
    param([object]$Op, [string]$ModuleId)
    $s = [ordered]@{
        module=$ModuleId; kind=$Op.Kind; path=$Op.Path; name=$Op.Name
        present=$false; keyPresent=$false; previousValue=$null
        previousKind=$null; previousStart=$null; previousDelayed=$null
        delayedPresent=$false; previouslyRunning=$false
    }
    switch ($Op.Kind) {
        'Registry' {
            $key = Get-RegistryKeyOrNull -Path $Op.Path
            if ($null -eq $key) { break }
            $s.keyPresent = $true
            if (@($key.GetValueNames()) -contains $Op.Name) {
                $s.present = $true
                $s.previousKind = [string]$key.GetValueKind($Op.Name)
                $s.previousValue = $key.GetValue(
                    $Op.Name, $null,
                    [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
        }
        'Service' {
            $svc = Get-CimInstance Win32_Service -Filter "Name='$($Op.Name)'" -ErrorAction Stop
            if ($null -eq $svc) { break }
            $s.present = $true
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $Op.Name
            $svcKey = Get-Item -LiteralPath $regPath -ErrorAction Stop
            $s.previousStart = [int]$svcKey.GetValue('Start')
            $s.delayedPresent = @($svcKey.GetValueNames()) -contains 'DelayedAutoStart'
            if ($s.delayedPresent) { $s.previousDelayed = [int]$svcKey.GetValue('DelayedAutoStart') }
            $s.previouslyRunning = ($svc.State -eq 'Running')
        }
        'Task' {
            $task = $null
            try {
                $task = Get-ScheduledTask -TaskPath $Op.Path -TaskName $Op.Name -ErrorAction Stop
            } catch {
                if ($_.FullyQualifiedErrorId -notlike 'CmdletizationQuery_NotFound,*') { throw }
            }
            if ($null -eq $task) { break }
            $s.present = $true
            $s.previousValue = [string]$task.State
        }
        default { throw "Unknown operation type: $($Op.Kind)" }
    }
    return [pscustomobject]$s
}
function Test-Target {
    param([object]$Op, [object]$State)
    switch ($Op.Kind) {
        'Registry' {
            if (-not $State.present) { return $false }
            # Never relax an existing Security-level diagnostic policy on Enterprise/Education.
            if ($Op.Name -eq 'AllowTelemetry' -and
                $Op.Path -eq 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -and
                $State.previousKind -eq 'DWord' -and [int]$State.previousValue -eq 0) {
                return $true
            }
            $desired = if ($Op.ValueKind -eq 'String') { [string]$Op.Value } else { [int]$Op.Value }
            return ([string]$State.previousValue -eq [string]$desired -and
                    $State.previousKind -eq $Op.ValueKind)
        }
        'Service' {
            return ($State.present -and $State.previousStart -eq 4 -and
                    -not $State.previouslyRunning)
        }
        'Task' { return ($State.present -and $State.previousValue -eq 'Disabled') }
    }
    return $false
}
function Set-Target {
    param([object]$Op, [object]$Original)
    if (-not $Original.present -and $Op.Kind -ne 'Registry') { return 'NOT_FOUND' }
    if (Test-Target $Op $Original) { return 'UNCHANGED' }
    switch ($Op.Kind) {
        'Registry' {
            if (-not (Test-Path -LiteralPath $Op.Path)) {
                New-Item -Path $Op.Path -Force -ErrorAction Stop | Out-Null
            }
            $value = if ($Op.ValueKind -eq 'String') { [string]$Op.Value } else { [int]$Op.Value }
            New-ItemProperty -LiteralPath $Op.Path -Name $Op.Name -Value $value -PropertyType $Op.ValueKind -Force -ErrorAction Stop | Out-Null
        }
        'Service' {
            Set-Service -Name $Op.Name -StartupType Disabled -ErrorAction Stop
            $service = Get-Service -Name $Op.Name -ErrorAction Stop
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $Op.Name -ErrorAction Stop
            }
        }
        'Task' {
            Disable-ScheduledTask -TaskPath $Op.Path -TaskName $Op.Name -ErrorAction Stop | Out-Null
        }
    }
    return 'APPLIED'
}
function Restore-Target {
    param([object]$Entry)
    switch ($Entry.kind) {
        'Registry' {
            $key = Get-RegistryKeyOrNull -Path $Entry.path
            if ($Entry.present) {
                if ($null -eq $key) {
                    New-Item -Path $Entry.path -Force -ErrorAction Stop | Out-Null
                }
                New-ItemProperty -LiteralPath $Entry.path -Name $Entry.name -Value $Entry.previousValue -PropertyType $Entry.previousKind -Force -ErrorAction Stop | Out-Null
            } else {
                if ($null -eq $key -and $Entry.keyPresent) {
                    New-Item -Path $Entry.path -Force -ErrorAction Stop | Out-Null
                    $key = Get-RegistryKeyOrNull -Path $Entry.path
                }
                if ($null -ne $key -and @($key.GetValueNames()) -contains $Entry.name) {
                    Remove-ItemProperty -LiteralPath $Entry.path -Name $Entry.name -ErrorAction Stop
                }
                if (-not $Entry.keyPresent -and $null -ne $key) {
                    $key = Get-RegistryKeyOrNull -Path $Entry.path
                    if ($null -ne $key -and @($key.GetValueNames()).Count -eq 0 -and
                        $key.SubKeyCount -eq 0) {
                        Remove-Item -LiteralPath $Entry.path -ErrorAction Stop
                    }
                }
            }
        }
        'Service' {
            if (-not $Entry.present) { return }
            $mode = switch ([int]$Entry.previousStart) {
                2 { 'Automatic' }
                3 { 'Manual' }
                4 { 'Disabled' }
                default { throw "Unsupported service startup mode in snapshot" }
            }
            Set-Service -Name $Entry.name -StartupType $mode -ErrorAction Stop
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $Entry.name
            if ($Entry.delayedPresent) {
                New-ItemProperty -LiteralPath $regPath -Name 'DelayedAutoStart' -PropertyType DWord -Value ([int]$Entry.previousDelayed) -Force -ErrorAction Stop | Out-Null
            } else {
                Remove-ItemProperty -LiteralPath $regPath -Name 'DelayedAutoStart' -ErrorAction SilentlyContinue
            }
            $svc = Get-Service -Name $Entry.name -ErrorAction Stop
            if ($Entry.previouslyRunning -and $svc.Status -ne 'Running') {
                Start-Service -Name $Entry.name -ErrorAction Stop
            } elseif (-not $Entry.previouslyRunning -and $svc.Status -eq 'Running') {
                Stop-Service -Name $Entry.name -ErrorAction Stop
            }
        }
        'Task' {
            if (-not $Entry.present) { return }
            if ($Entry.previousValue -eq 'Disabled') {
                Disable-ScheduledTask -TaskPath $Entry.path -TaskName $Entry.name -ErrorAction Stop | Out-Null
            } else {
                Enable-ScheduledTask -TaskPath $Entry.path -TaskName $Entry.name -ErrorAction Stop | Out-Null
            }
        }
        default { throw "Unknown rollback operation $($Entry.kind)" }
    }
}
function Confirm-Restored {
    param([object]$Op, [object]$Original)
    $current = Read-Target $Op $Original.module
    if ($Op.Kind -eq 'Registry') {
        return ($current.present -eq $Original.present -and
            $current.keyPresent -eq $Original.keyPresent -and
            ((-not $Original.present) -or
             ([string]$current.previousValue -ceq [string]$Original.previousValue -and
              $current.previousKind -eq $Original.previousKind)))
    }
    if ($Op.Kind -eq 'Service') {
        return (($current.present -eq $Original.present) -and
                (-not $Original.present -or
                 ($current.previousStart -eq $Original.previousStart -and
                  $current.delayedPresent -eq $Original.delayedPresent -and
                  $current.previousDelayed -eq $Original.previousDelayed -and
                  $current.previouslyRunning -eq $Original.previouslyRunning)))
    }
    if ($Op.Kind -eq 'Task') {
        return ($current.present -eq $Original.present -and
                ((-not $Original.present) -or
                 (($current.previousValue -eq 'Disabled') -eq
                  ($Original.previousValue -eq 'Disabled'))))
    }
    return $false
}

# Compare the complete captured state. This prevents restore from clobbering
# settings altered by other tools or Group Policy since this snapshot applied.
function Test-SameTargetState {
    param([object]$Op, [object]$A, [object]$B)
    if ([bool]$A.present -ne [bool]$B.present) { return $false }
    if ($Op.Kind -eq 'Registry' -and
        $A.PSObject.Properties.Name -contains 'keyPresent' -and
        $B.PSObject.Properties.Name -contains 'keyPresent' -and
        [bool]$A.keyPresent -ne [bool]$B.keyPresent) { return $false }
    if (-not $A.present) { return $true }
    switch ($Op.Kind) {
        'Registry' {
            return (($A.previousKind -ceq $B.previousKind) -and
                ([string]$A.previousValue -ceq [string]$B.previousValue))
        }
        'Service' {
            return (($A.previousStart -eq $B.previousStart) -and
                ($A.delayedPresent -eq $B.delayedPresent) -and
                ($A.previousDelayed -eq $B.previousDelayed) -and
                ($A.previouslyRunning -eq $B.previouslyRunning))
        }
        'Task' { return ($A.previousValue -ceq $B.previousValue) }
    }
    throw 'Unsupported target type in preflight comparison.'
}
