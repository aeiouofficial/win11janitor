# Capability gates: never infer edition support from successful registry writes.
function Get-JanitorCapabilities {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $edge = $false
    $appPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
    if (Test-Path -LiteralPath $appPath) {
        $exe = (Get-Item -LiteralPath $appPath -ErrorAction Stop).GetValue('')
        if ($exe -and (Test-Path -LiteralPath ([string]$exe) -PathType Leaf)) { $edge = $true }
    }
    if (-not $edge) {
        foreach ($root in @(${env:ProgramFiles}, ${env:ProgramFiles(x86)})) {
            if ($root -and (Test-Path -LiteralPath (Join-Path $root 'Microsoft\Edge\Application\msedge.exe') -PathType Leaf)) {
                $edge = $true
            }
        }
    }
    return [pscustomobject]@{
        build = [int]$os.BuildNumber
        edition = [string]$cv.EditionID
        client = ([int]$os.ProductType -eq 1)
        edgePresent = $edge
    }
}
function Get-ModuleSupportReason {
    param([object]$Item, [object]$Capabilities)
    if (-not $Capabilities.client) { return 'Windows client installation required.' }
    if ([int]$Capabilities.build -lt [int]$Item.minBuild) {
        return "Windows build $($Item.minBuild) or later required; found $($Capabilities.build)."
    }
    if ($Item.proPolicy) {
        $editions = @('Professional','ProfessionalN','ProfessionalWorkstation',
            'ProfessionalWorkstationN','Enterprise','EnterpriseN','EnterpriseS',
            'EnterpriseSN','Education','EducationN','IoTEnterprise','IoTEnterpriseS')
        if ($Capabilities.edition -notin $editions) {
            return "This policy is not supported on Windows edition '$($Capabilities.edition)'."
        }
    }
    if ($Item.edgeRequired -and -not $Capabilities.edgePresent) {
        return 'Microsoft Edge installation was not detected.'
    }
    return $null
}
