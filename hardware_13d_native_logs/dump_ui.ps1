param(
  [string]$OutXml = "c:\Development\evidence_vault\hardware_13d_native_logs\uidump.xml"
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb -s ZA222V9Y3V shell uiautomator dump /sdcard/uidump.xml | Out-Null
& $adb -s ZA222V9Y3V pull /sdcard/uidump.xml $OutXml | Out-Null
[xml]$xml = Get-Content $OutXml
function Show-Nodes($node) {
  $text = $node.text
  $desc = $node.'content-desc'
  $cls = $node.class
  $click = $node.clickable
  $bounds = $node.bounds
  $pkg = $node.package
  if (($text -and $text.Trim() -ne '') -or ($desc -and $desc.Trim() -ne '') -or $click -eq 'true') {
    [PSCustomObject]@{
      pkg = $pkg
      cls = ($cls -replace '.*\.', '')
      click = $click
      bounds = $bounds
      text = $text
      desc = $desc
    }
  }
  foreach ($c in $node.node) { Show-Nodes $c }
}
Show-Nodes $xml.hierarchy.node | Format-Table -AutoSize -Wrap
