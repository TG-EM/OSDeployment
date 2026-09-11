<#
Loads Functions
Creates Setup Complete Files
#>

Set-ExecutionPolicy Bypass -Force

Write-Host "Starting tg-main.ps1..." -ForegroundColor Green

# Load Menu
Write-Host "Loading tg-ap-menu.ps1..." -ForegroundColor Cyan
iex (irm "https://raw.githubusercontent.com/TG-EM/OSDeployment/refs/heads/main/tg-ap-menu.ps1")

Write-Host "Selected GroupTag: $GroupTag" -ForegroundColor Yellow
Write-Host "Selected Language: $Global:OSLanguage" -ForegroundColor Yellow

Start-Sleep -Seconds 2

# Load Functions
Write-Host "Loading tg-functions.ps1..." -ForegroundColor Cyan
iex (irm "https://raw.githubusercontent.com/TG-EM/OSDeployment/refs/heads/main/tg-functions.ps1")

Set-ExecutionPolicy Bypass -Force

# WinPE Stuff
if ($env:SystemDrive -eq 'X:') {

    # OS Variables
    $Product = Get-MyComputerProduct

    $OSVersion = 'Windows 11'
    $OSReleaseID = '25H2'
    $OSName = 'Windows 11 25H2 x64'
    $OSEdition = 'Pro'
    $OSActivation = 'Volume'

    # Language selected in tg-ap-menu.ps1
    if (-not $Global:OSLanguage) {
        $Global:OSLanguage = 'nl-NL'
    }

    $OSLanguage = $Global:OSLanguage

    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Deployment Configuration" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "GroupTag   : $GroupTag"
    Write-Host "OSLanguage : $OSLanguage"
    Write-Host "OSName     : $OSName"
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    # OSDCloud Variables
    $Global:MyOSDCloud = [ordered]@{
        Restart               = $false
        RecoveryPartition     = $true
        OEMActivation         = $true
        WindowsUpdate         = $true
        WindowsUpdateDrivers  = $true
        WindowsDefenderUpdate = $true
        SetTimeZone           = $true
        ClearDiskConfirm      = $false
        ShutdownSetupComplete = $true
        SyncMSUpCatDriverUSB  = $true
    }

    # Driver Pack
    $DriverPack = Get-OSDCloudDriverPack `
        -Product $Product `
        -OSVersion $OSVersion `
        -OSReleaseID $OSReleaseID

    if ($DriverPack) {
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
    }

    Write-Output $Global:MyOSDCloud

    # Load OSD Module
    $ModulePath = (
        Get-ChildItem "$($Env:ProgramFiles)\WindowsPowerShell\Modules\OSD" |
        Where-Object { $_.Attributes -match "Directory" } |
        Select-Object -Last 1
    ).FullName

    Import-Module "$ModulePath\OSD.psd1" -Force

    # Start OSDCloud
    Write-Host "Starting OSDCloud..." -ForegroundColor Green

    Start-OSDCloud `
        -OSName $OSName `
        -OSEdition $OSEdition `
        -OSActivation $OSActivation `
        -OSLanguage $OSLanguage

    Write-Host "OSDCloud Complete. Running Post Actions..." -ForegroundColor Green

    # Copy CMTrace
    if (Test-Path "X:\Windows\System32\CMTrace.exe") {
        Copy-Item `
            "X:\Windows\System32\CMTrace.exe" `
            -Destination "C:\Windows\System32\CMTrace.exe" `
            -Force
    }

    # Save GroupTag
    $GroupTag | Out-File `
        -FilePath "C:\Windows\DeviceType.txt" `
        -Force

    # Create SetupComplete
    Set-SetupCompleteOSDCloudUSB

    # Save Windows Image on USB
    $OSDCloudUSB = Get-Volume.usb |
        Where-Object {
            $_.FileSystemLabel -match 'OSDCloud' -or
            $_.FileSystemLabel -match 'BHIMAGE'
        } |
        Select-Object -First 1

    if ($OSDCloudUSB) {

        $DriverPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\OS\"

        if (!(Test-Path $DriverPath)) {
            New-Item `
                -ItemType Directory `
                -Path $DriverPath `
                -Force | Out-Null
        }

        $ImageFileName = Get-ChildItem `
            -Path $DriverPath `
            -Filter *.esd `
            -Name `
            -ErrorAction SilentlyContinue

        $ImageFileNameDL = Get-ChildItem `
            -Path "C:\OSDCloud\OS" `
            -Filter *.esd `
            -Name `
            -ErrorAction SilentlyContinue

        if ($ImageFileNameDL) {

            if ($ImageFileName -ne $ImageFileNameDL) {

                if ($ImageFileName) {
                    Remove-Item `
                        "$DriverPath$ImageFileName" `
                        -Force `
                        -ErrorAction SilentlyContinue
                }

                Copy-Item `
                    -Path "C:\OSDCloud\OS\$ImageFileNameDL" `
                    -Destination "$DriverPath$ImageFileNameDL" `
                    -Force
            }
        }
    }

    # Keyboard Layouts based on selected language
    switch ($OSLanguage) {

        'nl-NL' {
            Dism /image:C:\ /Set-InputLocale:0413:00020409
        }

        'en-US' {
            Dism /image:C:\ /Set-InputLocale:0409:00000409
        }

        'de-DE' {
            Dism /image:C:\ /Set-InputLocale:0407:00000407
        }

        'fr-FR' {
            Dism /image:C:\ /Set-InputLocale:040C:0000040C
        }
    }

    Restart-Computer
}