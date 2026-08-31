param(
  [string]$Serial = "ZA222V9Y3V"
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$outDir = "c:\Development\evidence_vault\hardware_13d_native_logs"
$xmlPath = Join-Path $outDir "uidump_5c3_live.xml"

function Invoke-Adb {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
  & $adb -s $Serial @Rest
}

function Focus-Harness {
  Invoke-Adb shell am force-stop com.android.chrome | Out-Null
  Invoke-Adb shell am start -W -n com.example.evidence_vault/.MainActivity | Out-Null
  Start-Sleep -Milliseconds 800
}

function Get-DumpNodes {
  Invoke-Adb shell uiautomator dump /sdcard/uidump.xml | Out-Null
  Invoke-Adb pull /sdcard/uidump.xml $xmlPath | Out-Null
  [xml]$xml = Get-Content $xmlPath
  $script:walkNodes = New-Object System.Collections.Generic.List[object]
  function Walk-Node($node) {
    if ($null -eq $node) { return }
    $text = [string]$node.text
    $desc = [string]$node.'content-desc'
    $click = [string]$node.clickable
    $pkg = [string]$node.package
    $bounds = [string]$node.bounds
    if (($text -and $text.Trim() -ne '') -or ($desc -and $desc.Trim() -ne '') -or $click -eq 'true') {
      $script:walkNodes.Add([PSCustomObject]@{
        pkg = $pkg
        click = $click
        bounds = $bounds
        text = $text
        desc = $desc
      }) | Out-Null
    }
    foreach ($c in $node.node) { Walk-Node $c }
  }
  Walk-Node $xml.hierarchy.node
  return $script:walkNodes
}

function Get-BoundsCenter([string]$bounds) {
  if ($bounds -notmatch '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') { return $null }
  return @{
    x = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
    y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
  }
}

function Find-UiNode($nodes, [string]$needle) {
  foreach ($n in $nodes) {
    if ($n.text -eq $needle -or $n.desc -eq $needle) { return $n }
    if ($n.text -like "*$needle*" -or $n.desc -like "*$needle*") { return $n }
  }
  return $null
}

function Invoke-TapLabel($nodes, [string]$needle) {
  $n = Find-UiNode $nodes $needle
  if ($null -eq $n) {
    Write-Host "MISSING $needle"
    return $false
  }
  $c = Get-BoundsCenter $n.bounds
  Write-Host "TAP $needle at $($c.x),$($c.y)"
  Invoke-Adb shell input tap $c.x $c.y
  return $true
}

function Save-Shot([string]$name) {
  Invoke-Adb shell screencap -p "/sdcard/$name.png"
  Invoke-Adb pull "/sdcard/$name.png" (Join-Path $outDir "$name.png") | Out-Null
}

function Confirm-Vault($nodes) {
  $pkg = ($nodes | Select-Object -First 1).pkg
  if ($pkg -ne 'com.example.evidence_vault') {
    Write-Host "NOT VAULT $pkg - refocus"
    Focus-Harness
    return Get-DumpNodes
  }
  return $nodes
}

Write-Host 'FOCUS'
Focus-Harness
$nodes = Confirm-Vault (Get-DumpNodes)
$nodes | Format-Table -AutoSize

Write-Host 'OPEN PHOTO'
if (-not (Invoke-TapLabel $nodes 'Open photo')) { throw 'Open photo missing' }
Start-Sleep -Seconds 1
$nodes = Confirm-Vault (Get-DumpNodes)
$nodes | Format-Table -AutoSize
Save-Shot 'ev_5c3_image_open'

Write-Host 'ZOOM IN'
Invoke-TapLabel $nodes 'Zoom in' | Out-Null
Start-Sleep -Milliseconds 400
Invoke-TapLabel $nodes 'Zoom in' | Out-Null
Start-Sleep -Milliseconds 400
Write-Host 'PAN'
Invoke-Adb shell input swipe 700 1400 280 980 350
Start-Sleep -Milliseconds 400
Save-Shot 'ev_5c3_image_zoom_pan'
$nodes = Confirm-Vault (Get-DumpNodes)
Write-Host 'RESET'
Invoke-TapLabel $nodes 'Reset zoom' | Out-Null
Start-Sleep -Milliseconds 300
Write-Host 'ANDROID BACK'
Invoke-Adb shell input keyevent 4
Start-Sleep -Seconds 1
$nodes = Confirm-Vault (Get-DumpNodes)
$nodes | Format-Table -AutoSize
if (-not (Find-UiNode $nodes 'Open photo')) { throw 'Did not return after image back' }

Write-Host 'LARGE PHOTO'
if (-not (Invoke-TapLabel $nodes 'Open large photo')) { throw 'Open large photo missing' }
Start-Sleep -Seconds 2
$nodes = Confirm-Vault (Get-DumpNodes)
Save-Shot 'ev_5c3_image_large'
$nodes | Format-Table -AutoSize
Invoke-Adb shell input keyevent 4
Start-Sleep -Seconds 1
$nodes = Confirm-Vault (Get-DumpNodes)

Write-Host 'VIDEO'
if (-not (Invoke-TapLabel $nodes 'Open video')) { throw 'Open video missing' }
Start-Sleep -Seconds 1
$nodes = Confirm-Vault (Get-DumpNodes)
Save-Shot 'ev_5c3_video'
$nodes | Format-Table -AutoSize
Invoke-Adb shell input keyevent 4
Start-Sleep -Seconds 1
$nodes = Confirm-Vault (Get-DumpNodes)

Write-Host 'DOCUMENT'
if (-not (Invoke-TapLabel $nodes 'Open document')) { throw 'Open document missing' }
Start-Sleep -Seconds 2
$nodes = Confirm-Vault (Get-DumpNodes)
Save-Shot 'ev_5c3_document'
$nodes | Format-Table -AutoSize
Invoke-Adb shell input keyevent 4
Start-Sleep -Seconds 1
$nodes = Confirm-Vault (Get-DumpNodes)
$nodes | Format-Table -AutoSize
if (-not (Find-UiNode $nodes 'Open photo')) { throw 'Did not return after document back' }

Write-Host 'PASS COMPLETE'
