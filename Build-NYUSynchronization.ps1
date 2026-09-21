$ErrorActionPreference = 'Stop'
$framework = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
$destination = $PSScriptRoot
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$output = Join-Path $destination 'NYUSynchronization.exe'
& (Join-Path $framework 'csc.exe') /nologo /target:winexe /optimize+ "/out:$output" "/win32icon:$PSScriptRoot/NYUSynchronization.ico" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Security.dll "/reference:$framework/WPF/UIAutomationClient.dll" "/reference:$framework/WPF/UIAutomationTypes.dll" "/reference:$framework/WPF/WindowsBase.dll" (Join-Path $PSScriptRoot 'NYUSynchronization.cs')
if($LASTEXITCODE -ne 0) { throw 'NYU Sync build failed' }
# Machine-local application locations; no secrets or shared configuration.
if (-not ('NYUIni' -as [type])) {
    Add-Type @'
using System.Runtime.InteropServices;
public static class NYUIni {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    public static extern bool WritePrivateProfileString(string section,string key,string value,string path);
}
'@
}
$state = Join-Path $destination 'State/watcher.ini'
$psApps = @(Get-StartApps | Where-Object { $_.Name -eq 'NYU PowerScribe' })
if($psApps.Count -eq 1 -and (Test-Path -LiteralPath $psApps[0].AppID)) {
    [NYUIni]::WritePrivateProfileString('Paths','ps360',$psApps[0].AppID,$state) | Out-Null
}
$visage = Join-Path $env:ProgramFiles 'Visage Imaging/Visage 7.1/bin/arch-Win/vsclient.exe'
if(Test-Path -LiteralPath $visage) {
    [NYUIni]::WritePrivateProfileString('Paths','visage',$visage,$state) | Out-Null
}
Write-Output 'NYU Sync built successfully.'
