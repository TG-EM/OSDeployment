<#
Loads Functions
Creates Setup Complete Files
#>

Set-ExecutionPolicy Bypass -Force

Write-Host "Starting tg-main.ps1..." -ForegroundColor Green

# Load Menu
Write-Host "Loading tg-ap-menu.ps1..." -ForegroundColor Cyan
iex (irm 'https://raw.githubusercontent.com/TG-EM/OSDeployment/refs/heads/main/tg-ap-menu.ps1')

# Validate Menu Selections
if (-not $GroupTag) {
    Write-Error "No GroupTag selected. Exiting deployment."
    exit 1
}

if (-not $Global:OSLanguage) {
    Write-Warning "No language selected. Defaulting to nl-NL."
    $Global:OSLanguage = 'nl-NL'
}

Write-Host "Selected GroupTag: $GroupTag" -ForegroundColor Yellow
Write-Host "Selected Language: $Global:OSLanguage" -ForegroundColor Yellow

Start-Sleep -Seconds 2

# Load Functions
Write-Host "Loading tg-functions.ps1..." -ForegroundColor Cyan
iex (irm 'https://raw.githubusercontent.com/TG-EM/OSDeployment/refs/heads/main/tg-functions.ps1')

# WinPE Stuff
if ($env:SystemDrive -eq 'X:') {

    # OS Variables
    $Product = Get-MyComputerProduct

    $OSVersion    = 'Windows 11'
    $OSReleaseID  = '25H2'
    $OSName       = "Windows 11 $OSReleaseID x64"
    $OSEdition    = 'Pro'
    $OSActivation = 'Volume'

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
    Write-Host "Searching for driver pack..." -ForegroundColor Cyan

    $DriverPack = Get-OSDCloudDriverPack `
        -Product $Product `
        -OSVersion $OSVersion `
        -OSReleaseID $OSReleaseID

    if ($DriverPack) {
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
        Write-Host "Driver Pack Found: $($DriverPack.Name)" -ForegroundColor Green
    }
    else {
        Write-Warning "No driver pack found for product: $Product"
    }

    Write-Output $Global:MyOSDCloud

    # Load Latest OSD Module
    $ModulePath = Get-ChildItem "$Env:ProgramFiles\WindowsPowerShell\Modules\OSD" -Directory |
        Sort-Object {
            try { [version]$_.Name }
            catch { [version]'0.0.0.0' }
        } |
        Select-Object -Last 1 -ExpandProperty FullName

    if (-not $ModulePath) {
        Write-Error "OSD Module not found."
        exit 1
    }

    Import-Module "$ModulePath\OSD.psd1" -Force

    # Start OSDCloud
    Write-Host "Starting OSDCloud..." -ForegroundColor Green

    try {
        Start-OSDCloud `
            -OSName $OSName `
            -OSEdition $OSEdition `
            -OSActivation $OSActivation `
            -OSLanguage $OSLanguage
    }
    catch {
        Write-Error "OSDCloud deployment failed."
        Write-Error $_.Exception.Message
        exit 1
    }

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

    # Create SetupComplete.cmd
    Set-SetupCompleteOSDCloudUSB

    # Save Image To USB
    $OSDCloudUSB = Get-Volume.usb |
        Where-Object {
            $_.FileSystemLabel -match 'OSDCloud' -or
            $_.FileSystemLabel -match 'BHIMAGE'
        } |
        Select-Object -First 1

    if ($OSDCloudUSB) {

        $DriverPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\OS"

        if (!(Test-Path $DriverPath)) {
            New-Item `
                -ItemType Directory `
                -Path $DriverPath `
                -Force | Out-Null
        }

        $USBImage = Get-ChildItem `
            -Path $DriverPath `
            -Filter *.esd `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        $DownloadedImage = Get-ChildItem `
            -Path "C:\OSDCloud\OS" `
            -Filter *.esd `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($DownloadedImage) {

            if (($USBImage -eq $null) -or ($USBImage.Name -ne $DownloadedImage.Name)) {

                if ($USBImage) {
                    Remove-Item `
                        $USBImage.FullName `
                        -Force `
                        -ErrorAction SilentlyContinue
                }

                Copy-Item `
                    -Path $DownloadedImage.FullName `
                    -Destination (Join-Path $DriverPath $DownloadedImage.Name) `
                    -Force

                Write-Host "Cached image copied to USB." -ForegroundColor Green
            }
        }
    }

    # Keyboard Layout
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

        default {
            Write-Warning "No keyboard layout mapping configured for $OSLanguage"
        }
    }

    Write-Host "Deployment complete. Rebooting in 10 seconds..." -ForegroundColor Green

    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
