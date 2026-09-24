# adb-rt :: usbreg.ps1 -- READ ONLY. Reports why libusb can or cannot open a USB node.
#
# Background (measured, not guessed):
#   libusb reaches a COMPOSITE child (...&MI_xx) only through EXT_PASS, which enumerates
#   device-interface GUIDs harvested from each node's
#       HKLM\SYSTEM\CurrentControlSet\Enum\USB\<hw-id>\<inst>\Device Parameters
#           DeviceInterfaceGUIDs      (REG_MULTI_SZ)
#   -- libusb-1.0.28/libusb/os/windows_winusb.c:1785 (get_guid) and :2016
#      (set_composite_interface, reached only from HID_PASS/EXT_PASS).
#   A NON-composite node is found in DEV_PASS via GUID_DEVINTERFACE_USB_DEVICE, which the
#   hub registers for every device -- so a single-interface device needs NO extra GUID.
#   That asymmetry is the whole bug: WinUSB bound to &MI_01 is NECESSARY BUT NOT SUFFICIENT.
#
# Exit: 0 = nothing blocked, 1 = at least one node blocked, 2 = COULD NOT READ (not a verdict).

param([string]$Vid = 'VID_0E8D',
      [string]$Root = 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB')   # -Root exists so this reader can be negative-tested

$ErrorActionPreference = 'Continue'
$root     = $Root
$winusbby = @('WinUSB','libusbK','libusb0')

Write-Output 'adb-rt usbreg -- WinUSB / libusb device-interface GUID report'
Write-Output '================================================================'
Write-Output ("registry root : {0}" -f $root)
Write-Output ("filter        : {0}*" -f $Vid)
Write-Output ''

# --- reader self-test: a reader that cannot read must NOT look like an empty result -------
if (-not (Test-Path $root)) {
    Write-Output 'SELF-TEST FAIL: cannot open the USB Enum key at all.'
    Write-Output 'This is a READER failure, not a finding. Nothing below is evidence.'
    exit 2
}
$allKeys = @(Get-ChildItem $root -ErrorAction SilentlyContinue)
if ($allKeys.Count -eq 0) {
    Write-Output 'SELF-TEST FAIL: the USB Enum key opened but listed ZERO hardware ids.'
    Write-Output 'That never happens on a working machine. READER failure, not a finding.'
    exit 2
}
Write-Output ("self-test     : OK -- {0} USB hardware ids readable" -f $allKeys.Count)
Write-Output ''

$roots = @($allKeys | Where-Object { $_.PSChildName -like ($Vid + '*') })
if ($roots.Count -eq 0) {
    Write-Output ("NO MATCH: no hardware id under USB starts with '{0}'." -f $Vid)
    Write-Output 'The phone has never been attached to this machine, or the VID is wrong.'
    Write-Output 'This is a MISSING INPUT, not a verdict about libusb.'
    exit 2
}

$blocked = 0
$ok      = 0

foreach ($r in $roots) {
  foreach ($inst in @(Get-ChildItem $r.PSPath -ErrorAction SilentlyContinue)) {
    $p    = $inst.PSPath
    $svc  = (Get-ItemProperty $p -Name Service    -ErrorAction SilentlyContinue).Service
    $desc = (Get-ItemProperty $p -Name DeviceDesc -ErrorAction SilentlyContinue).DeviceDesc
    $dp   = Join-Path $p 'Device Parameters'

    $guids = $null
    if (Test-Path $dp) {
        $g = (Get-ItemProperty $dp -Name DeviceInterfaceGUIDs -ErrorAction SilentlyContinue).DeviceInterfaceGUIDs
        if (-not $g) { $g = (Get-ItemProperty $dp -Name DeviceInterfaceGUID -ErrorAction SilentlyContinue).DeviceInterfaceGUID }
        if ($g) { $guids = ($g -join ' ; ') }
    }
    if (-not $guids) { $guids = '<NONE>' }
    if (-not $svc)   { $svc   = '<none>' }

    $isChild  = $r.PSChildName -match '&MI_'
    $isWinusb = $winusbby -contains $svc

    if ($isChild -and $isWinusb -and ($guids -eq '<NONE>')) {
        $verdict = 'BLOCKED  -- WinUSB is bound but NO DeviceInterfaceGUIDs; libusb EXT_PASS cannot see it'
        $blocked++
    } elseif ($isChild -and $isWinusb) {
        $verdict = 'OK       -- composite child reachable via EXT_PASS'
        $ok++
    } elseif ($isChild) {
        $verdict = ('n/a      -- composite child, not a WinUSB-family service ({0})' -f $svc)
    } elseif ($isWinusb) {
        $verdict = 'OK       -- single-interface node, reachable via DEV_PASS (no GUID needed)'
        $ok++
    } elseif ($svc -eq 'usbccgp') {
        $verdict = 'n/a      -- composite parent; binds itself, children are what matter'
    } else {
        $verdict = ('n/a      -- service {0}' -f $svc)
    }

    Write-Output ('NODE  : USB\{0}\{1}' -f $r.PSChildName, $inst.PSChildName)
    Write-Output ('  Desc : {0}' -f $desc)
    Write-Output ('  Svc  : {0}' -f $svc)
    Write-Output ('  GUIDs: {0}' -f $guids)
    Write-Output ('  ==> {0}' -f $verdict)
  }
}

Write-Output ''
Write-Output '--- verdict ---'
Write-Output ('reachable by libusb : {0}' -f $ok)
Write-Output ('BLOCKED             : {0}' -f $blocked)
if ($blocked -gt 0) {
    Write-Output ''
    Write-Output 'Run adb-usb-bind.cmd FROM AN ADMINISTRATOR PROMPT, then unplug and replug the phone.'
    exit 1
}
Write-Output 'Nothing blocked. If adb still fails, the cause is NOT the interface GUID.'
exit 0
