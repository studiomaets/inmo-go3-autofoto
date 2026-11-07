param(
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$ApkDirectory = (Join-Path $PSScriptRoot 'work\inmo-apk'),
    [string]$WorkingDirectory = (Join-Path $PSScriptRoot 'work')
)
$ErrorActionPreference = 'Stop'
if (-not $JavaHome) { throw 'Set JAVA_HOME or pass -JavaHome with your JDK 17 directory.' }
$java = Join-Path $JavaHome 'bin\java.exe'
$editor = Join-Path $PSScriptRoot 'tools\apkeditor.jar'
$apktool = Join-Path $PSScriptRoot 'tools\apktool.jar'
foreach ($required in @($java, $editor, $apktool, (Join-Path $ApkDirectory 'base.apk'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing input/tool: $required. See BUILD.md." }
}
$working = [IO.Path]::GetFullPath($WorkingDirectory)
$decoded = Join-Path $working 'inmo-autofoto'
if (Test-Path -LiteralPath $decoded) { throw 'Decoded tree already exists. Reuse it with build.ps1 or choose a fresh -WorkingDirectory.' }
New-Item -ItemType Directory -Force -Path $working | Out-Null
$merged = Join-Path $working 'inmo-merged.apk'
& $java -jar $editor m -i $ApkDirectory -o $merged
if ($LASTEXITCODE -ne 0) { throw 'APK merge failed.' }
& $java -jar $apktool d $merged -o $decoded
if ($LASTEXITCODE -ne 0) { throw 'APK decode failed.' }
Write-Output "Prepared: $decoded"
