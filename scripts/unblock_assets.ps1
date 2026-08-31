# Removes Windows Mark-of-the-Web streams that block Flutter asset bundling.
Get-ChildItem -Path "$PSScriptRoot\..\assets" -File -Recurse | ForEach-Object {
    Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue
    foreach ($stream in @('Zone.Identifier', 'mshield')) {
        Remove-Item -LiteralPath $_.FullName -Stream $stream -ErrorAction SilentlyContinue
    }
}

Write-Host "Asset files unblocked."
