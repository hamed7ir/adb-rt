# adb-rt :: usbbind.ps1 -- writes the ADB device-interface GUID onto WinUSB-bound composite
# children so libusb can find them. NEEDS AN ADMINISTRATOR PROMPT.
#
# WHY A REGISTRY WRITE AND NOT AN INF
#   Windows RT 8.1 refuses every unsigned third-party driver package:
#       "The third-party INF does not contain digital signature information."
#   and there is no override on ARM. But the INF's ONLY net effect on RT is this one value --
#   winusb.sys is already bound to the node by WCID (in-box winusb.inf, Microsoft-signed).
#   So we write exactly what the INF's [Dev_AddReg] would have written, and nothing else.
#
#   The value and GUID are not invented: Windows 10/11's OWN in-box winusb.inf contains
#       [Generic.Section.NTamd64]
#       %USB\MS_COMP_ADB.DeviceDesc% = ADB,USB\Class_ff&SubClass_42&Prot_01
#       [ADB.HW.AddReg]
#       HKR,,DeviceInterfaceGUIDs,0x10000,"{F72FE0D4-CBCB-407d-8814-9ED673D0DD6B}"
#   Windows 8.1's winusb.inf has no such section -- that section was added after RT shipped.
#   This script backfills it. Same key, same value, same GUID.
#
# Exit: 0 = wrote or nothing to do, 1 = write failed / verify failed, 2 = cannot run.

param([switch]$Undo,
      [string]$Root = 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB')  # -Root exists so the WRITE path can be tested
                                                                  # against a throwaway HKCU tree. Elevation is
                                                                  # only waived when -Root is NOT the real one.

$ErrorActionPreference = 'Continue'
$ADB_GUID = '{F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}'
$realRoot = 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB'
$root     = $Root
$winusbby = @('WinUSB','libusbK','libusb0')

Write-Output 'adb-rt usbbind -- backfill DeviceInterfaceGUIDs on WinUSB composite children'
Write-Output '================================================================'

if ($root -eq $realRoot) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output 'NOT ELEVATED. Right-click adb-usb-bind.cmd -> Run as administrator.'
        Write-Output 'Nothing was read and nothing was changed.'
        exit 2
    }
    Write-Output 'elevation     : OK (Administrator)'
} else {
    Write-Output ('SELF-TEST ROOT: {0}  (elevation gate waived, real devices untouched)' -f $root)
}

if (-not (Test-Path $root)) {
    Write-Output 'SELF-TEST FAIL: cannot open the USB Enum key. READER failure, not a finding.'
    exit 2
}
$allKeys = @(Get-ChildItem $root -ErrorAction SilentlyContinue)
if ($allKeys.Count -eq 0) {
    Write-Output 'SELF-TEST FAIL: USB Enum key listed ZERO hardware ids. READER failure.'
    exit 2
}
Write-Output ("self-test     : OK -- {0} USB hardware ids readable" -f $allKeys.Count)
Write-Output ("mode          : {0}" -f $(if ($Undo) { 'UNDO (remove the value)' } else { 'WRITE' }))
Write-Output ''

$targets = @()
foreach ($r in $allKeys) {
    if ($r.PSChildName -notmatch '&MI_') { continue }
    foreach ($inst in @(Get-ChildItem $r.PSPath -ErrorAction SilentlyContinue)) {
        $svc = (Get-ItemProperty $inst.PSPath -Name Service -ErrorAction SilentlyContinue).Service
        if ($winusbby -contains $svc) {
            $targets += New-Object PSObject -Property @{
                Id   = ('USB\' + $r.PSChildName + '\' + $inst.PSChildName)
                Dp   = (Join-Path $inst.PSPath 'Device Parameters')
                Svc  = $svc
            }
        }
    }
}

if ($targets.Count -eq 0) {
    Write-Output 'No WinUSB-family composite child (...&MI_xx) found on this machine.'
    Write-Output 'Plug the phone in and set USB mode to File transfer, then run this again.'
    exit 2
}

$changed = 0
$failed  = 0
foreach ($t in $targets) {
    Write-Output ('NODE  : {0}   (Svc {1})' -f $t.Id, $t.Svc)
    if (-not (Test-Path $t.Dp)) {
        try { New-Item -Path $t.Dp -Force | Out-Null } catch { }
    }
    $before = (Get-ItemProperty $t.Dp -Name DeviceInterfaceGUIDs -ErrorAction SilentlyContinue).DeviceInterfaceGUIDs
    Write-Output ('  before: {0}' -f $(if ($before) { $before -join ' ; ' } else { '<NONE>' }))

    if ($Undo) {
        if (-not $before) { Write-Output '  ==> nothing to undo'; continue }
        try { Remove-ItemProperty -Path $t.Dp -Name DeviceInterfaceGUIDs -Force -ErrorAction Stop }
        catch { Write-Output ('  ==> REMOVE FAILED: {0}' -f $_.Exception.Message); $failed++; continue }
    } else {
        if ($before -and ($before -join ' ') -match [regex]::Escape('F72FE0D4')) {
            Write-Output '  ==> already present, left alone'
            continue
        }
        try {
            New-ItemProperty -Path $t.Dp -Name DeviceInterfaceGUIDs -PropertyType MultiString `
                             -Value @($ADB_GUID) -Force -ErrorAction Stop | Out-Null
        } catch { Write-Output ('  ==> WRITE FAILED: {0}' -f $_.Exception.Message); $failed++; continue }
    }

    # verify the ARTIFACT, never the exit code
    $after = (Get-ItemProperty $t.Dp -Name DeviceInterfaceGUIDs -ErrorAction SilentlyContinue).DeviceInterfaceGUIDs
    Write-Output ('  after : {0}' -f $(if ($after) { $after -join ' ; ' } else { '<NONE>' }))
    $wantSet = (-not $Undo)
    $isSet   = [bool]$after
    if ($wantSet -ne $isSet) { Write-Output '  ==> VERIFY FAILED'; $failed++ }
    else { Write-Output '  ==> OK'; $changed++ }
}

Write-Output ''
Write-Output '--- verdict ---'
Write-Output ('nodes changed : {0}' -f $changed)
Write-Output ('failures      : {0}' -f $failed)
if ($failed -gt 0) { exit 1 }
if ($changed -gt 0) {
    Write-Output ''
    Write-Output 'NOW UNPLUG THE PHONE AND PLUG IT BACK IN -- winusb.sys reads this value only'
    Write-Output 'when the device starts. Then run:   usbprobe.exe   and   adb-usb.cmd devices'
}
exit 0
