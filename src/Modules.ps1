# Single source of truth: safe/opt-in/audit-only modules.
function New-Reg {
    param([string]$Path, [string]$Name, [int]$Value, [string]$ValueKind='DWord')
    return [pscustomobject]@{ Kind='Registry'; Path=$Path; Name=$Name; Value=$Value; ValueKind=$ValueKind }
}
function New-Task {
    param([string]$Path, [string]$Name)
    return [pscustomobject]@{ Kind='Task'; Path=$Path; Name=$Name; Value='Disabled' }
}
function New-Service {
    param([string]$Name)
    return [pscustomobject]@{ Kind='Service'; Path=''; Name=$Name; Value='Disabled' }
}
$script:Catalog = [ordered]@{}
function Add-Module {
    param([string]$Id, [string]$Mode, [string]$Description, [object[]]$Operations,
          [int]$MinBuild = 22000, [switch]$ProPolicy, [switch]$EdgeRequired,
          [string]$Impact = '', [string]$Reference = '')
    $script:Catalog[$Id] = [pscustomobject]@{
        id=$Id; mode=$Mode; description=$Description; operations=@($Operations)
        minBuild=$MinBuild; proPolicy=[bool]$ProPolicy; edgeRequired=[bool]$EdgeRequired
        impact=$Impact; reference=$Reference
    }
}
Add-Module '01' 'Safe' 'Required diagnostic level, preserving stricter preexisting policy' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1)
)
Add-Module '02' 'Safe' 'Disable publishing and uploading activity history' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0)
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0)
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0)
)
Add-Module '03' 'Safe' 'Disable Start menu web search suggestions for current user' @(
    (New-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1)
)
Add-Module '04' 'Safe' 'Disable personalized experiences based on diagnostic data' @(
    (New-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0)
)
Add-Module '05' 'AuditOnly' 'MMCSS registry tweaks have no proven universal gain' @()
Add-Module '06' 'Optional' 'Disable game capture; explicitly opt in only' @(
    (New-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0)
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0)
)
Add-Module '07' 'Optional' 'Disable DiagTrack only; preserve SysMain' @(
    (New-Service 'DiagTrack')
)
Add-Module '08' 'Optional' 'Disable Fast Startup while preserving hibernation' @(
    (New-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0)
)
Add-Module '09' 'AuditOnly' 'NTFS last-access default already optimized; avoid global override' @()
Add-Module '10' 'AuditOnly' 'Avoid global 8.3 changes with legacy compatibility risk' @()
Add-Module '11' 'AuditOnly' 'No blanket RSS/RSC/ECN/TCP override without benchmarks' @()
Add-Module '12' 'AuditOnly' 'Never disable Nagle across every adapter' @()
Add-Module '13' 'Optional' 'Disable three clearly identified telemetry tasks only' @(
    (New-Task '\Microsoft\Windows\Customer Experience Improvement Program\' 'Consolidator')
    (New-Task '\Microsoft\Windows\Customer Experience Improvement Program\' 'UsbCeip')
    (New-Task '\Microsoft\Windows\Feedback\Siuf\' 'DmClient')
)
Add-Module '14' 'AuditOnly' 'Preserve ETW for reliability and diagnosis' @()
Add-Module '15' 'AuditOnly' 'Keep adaptive core parking and the original power plan' @()
Add-Module '16' 'Optional' 'Disable current-user pointer acceleration and transparency only' @(
    (New-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' 0 'String')
    (New-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' 0 'String')
    (New-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' 0 'String')
    (New-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0)
)
Add-Module '17' 'Safe' 'Disable current-user advertising identifier' @(
    (New-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0)
)

# Additions are opt-in and gated by the documented OS edition/build or Edge installation.
Add-Module '18' 'Optional' 'Disable search highlights, retaining local search' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'EnableDynamicContentInWSB' 0)
) -MinBuild 22621 -ProPolicy -Impact 'Removes dynamic Search content; Group Policy precedence applies.' -Reference 'https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search'
Add-Module '19' 'Optional' 'Disable cloud-source queries within Windows Search' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCloudSearch' 0)
) -ProPolicy -Impact 'OneDrive/SharePoint results may no longer appear in Windows Search.' -Reference 'https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search'
Add-Module '20' 'Optional' 'Disable Widgets through the supported device policy' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0)
) -ProPolicy -Impact 'Widgets including its taskbar entry become unavailable.' -Reference 'https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests'
Add-Module '21' 'Optional' 'Stop Edge background applications after the browser closes' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0)
) -EdgeRequired -Impact 'Edge extensions/background apps will not stay active after browser exit.' -Reference 'https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled'
Add-Module '22' 'Optional' 'Disable Microsoft Edge startup boost' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0)
) -EdgeRequired -Impact 'Edge cold startup may be slower, background resource use may decline.' -Reference 'https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled'
Add-Module '23' 'Optional' 'Disable cross-device Clipboard sync while retaining local history' @(
    (New-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'AllowCrossDeviceClipboard' 0)
) -ProPolicy -Impact 'Clipboard data will not synchronize with your other devices.' -Reference 'https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy'
