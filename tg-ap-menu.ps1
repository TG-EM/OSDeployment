#================================================
# Window Functions
#================================================

$script:showWindowAsync = Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru

function Hide-CmdWindow {
    $CMDProcess = Get-Process -Name cmd -ErrorAction Ignore

    foreach ($Item in $CMDProcess) {
        $null = $script:showWindowAsync::ShowWindowAsync(
            (Get-Process -Id $Item.Id).MainWindowHandle,
            2
        )
    }
}

function Hide-PowershellWindow {
    $null = $script:showWindowAsync::ShowWindowAsync(
        (Get-Process -Id $PID).MainWindowHandle,
        2
    )
}

function Show-PowershellWindow {
    $null = $script:showWindowAsync::ShowWindowAsync(
        (Get-Process -Id $PID).MainWindowHandle,
        10
    )
}

Hide-CmdWindow
Hide-PowershellWindow

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================
# STEP 1 - SELECT GROUPTAG
# ==========================================

$Form1 = New-Object System.Windows.Forms.Form
$Form1.Text = "Step 1 - Select GroupTag"
$Form1.Size = New-Object System.Drawing.Size(500,400)
$Form1.StartPosition = "CenterScreen"
$Form1.TopMost = $true
$Form1.FormBorderStyle = 'FixedDialog'
$Form1.MaximizeBox = $false
$Form1.MinimizeBox = $false

$Label1 = New-Object System.Windows.Forms.Label
$Label1.Location = New-Object System.Drawing.Point(10,10)
$Label1.Size = New-Object System.Drawing.Size(300,20)
$Label1.Text = "Select Autopilot GroupTag"
$Form1.Controls.Add($Label1)

$List1 = New-Object System.Windows.Forms.ListBox
$List1.Location = New-Object System.Drawing.Point(10,40)
$List1.Size = New-Object System.Drawing.Size(300,250)

@(
    "PersonalUserNL"
    "PersonalUserEN"
    "PersonalUserDE"
    "PersonalUserFR"
    "PersonalAdminNL"
    "PersonalAdminEN"
    "PersonalAdminDE"
    "PersonalAdminFR"
) | ForEach-Object {
    [void]$List1.Items.Add($_)
}

$List1.SelectedIndex = 0

$Form1.Controls.Add($List1)

$Btn1 = New-Object System.Windows.Forms.Button
$Btn1.Text = "Next"
$Btn1.Location = New-Object System.Drawing.Point(180,310)
$Btn1.DialogResult = [System.Windows.Forms.DialogResult]::OK
$Form1.Controls.Add($Btn1)

$Cancel1 = New-Object System.Windows.Forms.Button
$Cancel1.Text = "Cancel"
$Cancel1.Location = New-Object System.Drawing.Point(280,310)
$Cancel1.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$Form1.Controls.Add($Cancel1)

$Form1.AcceptButton = $Btn1
$Form1.CancelButton = $Cancel1

$result1 = $Form1.ShowDialog()

if ($result1 -ne [System.Windows.Forms.DialogResult]::OK) {
    $Form1.Dispose()
    throw "Deployment cancelled during GroupTag selection."
}

$Global:GroupTag = $List1.SelectedItem

$Form1.Dispose()

if (-not $Global:GroupTag) {
    throw "No GroupTag selected."
}

# ==========================================
# STEP 2 - SELECT WINDOWS LANGUAGE
# ==========================================

$Form2 = New-Object System.Windows.Forms.Form
$Form2.Text = "Step 2 - Select Windows Language"
$Form2.Size = New-Object System.Drawing.Size(500,350)
$Form2.StartPosition = "CenterScreen"
$Form2.TopMost = $true
$Form2.FormBorderStyle = 'FixedDialog'
$Form2.MaximizeBox = $false
$Form2.MinimizeBox = $false

$Label2 = New-Object System.Windows.Forms.Label
$Label2.Location = New-Object System.Drawing.Point(10,10)
$Label2.Size = New-Object System.Drawing.Size(450,20)
$Label2.Text = "Select Windows Installation Language for $Global:GroupTag"
$Form2.Controls.Add($Label2)

$List2 = New-Object System.Windows.Forms.ListBox
$List2.Location = New-Object System.Drawing.Point(10,40)
$List2.Size = New-Object System.Drawing.Size(250,180)

@(
    "Dutch"
    "English"
    "German"
    "French"
) | ForEach-Object {
    [void]$List2.Items.Add($_)
}

$List2.SelectedIndex = 0

$Form2.Controls.Add($List2)

$Btn2 = New-Object System.Windows.Forms.Button
$Btn2.Text = "Deploy"
$Btn2.Location = New-Object System.Drawing.Point(180,250)
$Btn2.DialogResult = [System.Windows.Forms.DialogResult]::OK
$Form2.Controls.Add($Btn2)

$Cancel2 = New-Object System.Windows.Forms.Button
$Cancel2.Text = "Cancel"
$Cancel2.Location = New-Object System.Drawing.Point(280,250)
$Cancel2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$Form2.Controls.Add($Cancel2)

$Form2.AcceptButton = $Btn2
$Form2.CancelButton = $Cancel2

$result2 = $Form2.ShowDialog()

if ($result2 -ne [System.Windows.Forms.DialogResult]::OK) {
    $Form2.Dispose()
    throw "Deployment cancelled during language selection."
}

$Language = $List2.SelectedItem

$Form2.Dispose()

if (-not $Language) {
    throw "No language selected."
}

# ==========================================
# STORE LANGUAGE
# ==========================================

switch ($Language) {

    "Dutch" {
        $Global:OSLanguage = "nl-NL"
    }

    "English" {
        $Global:OSLanguage = "en-US"
    }

    "German" {
        $Global:OSLanguage = "de-DE"
    }

    "French" {
        $Global:OSLanguage = "fr-FR"
    }

    default {
        $Global:OSLanguage = "nl-NL"
    }
}

Show-PowershellWindow

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Deployment Selection Complete" -ForegroundColor Green
Write-Host "GroupTag   : $Global:GroupTag" -ForegroundColor Yellow
Write-Host "OSLanguage : $Global:OSLanguage" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
