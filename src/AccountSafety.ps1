# Do not configure an unrelated administrator profile when UAC switches accounts.
function Assert-JanitorAccountContext {
    param([object[]]$Targets, [string]$ExpectedUserSid='')
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($ExpectedUserSid -and $ExpectedUserSid -cne $sid) {
        throw 'ExpectedUserSid does not match the elevated process account.'
    }
    $userTargets=@($Targets | Where-Object {
        $_.path -and ([string]$_.path).StartsWith('HKCU:',[StringComparison]::OrdinalIgnoreCase)
    })
    if ($userTargets.Count -eq 0) { return $sid }
    $session=(Get-Process -Id $PID -ErrorAction Stop).SessionId
    $shells=@(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction Stop |
        Where-Object SessionId -eq $session)
    $owners=@()
    foreach ($shell in $shells) {
        $owner=Invoke-CimMethod -InputObject $shell -MethodName GetOwnerSid -ErrorAction Stop
        if ($owner.ReturnValue -eq 0 -and $owner.Sid) {
            $owners += [string]$owner.Sid
        }
    }
    $owners=@($owners | Select-Object -Unique)
    if ($owners.Count -eq 0 -and -not $ExpectedUserSid) {
        throw 'Cannot verify the interactive owner of HKCU. Supply -ExpectedUserSid for an intentionally headless session.'
    }
    if (@($owners | Where-Object { $_ -cne $sid }).Count -gt 0) {
        throw 'UAC elevated under a different user than the interactive desktop. Refusing HKCU changes.'
    }
    return $sid
}
function Assert-SnapshotAccount {
    param([object]$Data, [string]$ExpectedUserSid='')
    $entries=@($Data.entries | Where-Object {
        $_.path -and ([string]$_.path).StartsWith('HKCU:',[StringComparison]::OrdinalIgnoreCase)
    })
    if ($entries.Count -eq 0) { return }
    $sid=Assert-JanitorAccountContext -Targets $entries -ExpectedUserSid $ExpectedUserSid
    if ($Data.PSObject.Properties.Name -contains 'userSid' -and $Data.userSid) {
        if ($Data.userSid -cne $sid) {
            throw 'Snapshot was created for a different user account.'
        }
    } elseif (-not $ExpectedUserSid) {
        throw 'Legacy snapshot lacks account binding. Rerun Restore with -ExpectedUserSid.'
    }
}
