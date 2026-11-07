param(
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$AndroidSdk = $env:ANDROID_SDK_ROOT,
    [string]$BuildToolsVersion = '35.0.0',
    [string]$AndroidPlatform = 'android-35',
    [string]$WorkingDirectory = (Join-Path $PSScriptRoot 'work'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'dist')
)
$ErrorActionPreference = 'Stop'
if (-not $JavaHome) { throw 'Set JAVA_HOME or pass -JavaHome with your JDK 17 directory.' }
if (-not $AndroidSdk) { $AndroidSdk = $env:ANDROID_HOME }
if (-not $AndroidSdk) { throw 'Set ANDROID_SDK_ROOT or pass -AndroidSdk.' }
$taskRoot = [IO.Path]::GetFullPath($WorkingDirectory)
$decoded = Join-Path $taskRoot 'inmo-autofoto'
$jdk = [IO.Path]::GetFullPath($JavaHome)
$sdk = [IO.Path]::GetFullPath($AndroidSdk)
$buildTools = Join-Path $sdk "build-tools\$BuildToolsVersion"
$androidJar = Join-Path $sdk "platforms\$AndroidPlatform\android.jar"
$apktool = Join-Path $PSScriptRoot 'tools\apktool.jar'
foreach ($required in @((Join-Path $jdk 'bin\javac.exe'), $androidJar, $apktool,
    (Join-Path $buildTools 'd8.bat'), (Join-Path $buildTools 'zipalign.exe'),
    (Join-Path $buildTools 'apksigner.bat'), (Join-Path $decoded 'AndroidManifest.xml'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing input/tool: $required. See BUILD.md." }
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$env:JAVA_HOME = $jdk
$utf8 = [System.Text.UTF8Encoding]::new($false)
$oldPackage = 'com.inmo.app.googleplay'
$newPackage = 'com.inmo.app.autofoto'

# Every alteration is made to the separate decoded working copy.
$manifestPath = Join-Path $decoded 'AndroidManifest.xml'
[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
$androidNs = 'http://schemas.android.com/apk/res/android'
$apktoolMetadata = [IO.File]::ReadAllText((Join-Path $decoded 'apktool.yml'))
# Apktool 3 stores the original version in apktool.yml, not the decoded manifest.
if ($apktoolMetadata -notmatch '(?m)^versionInfo:\r?\n\s+versionCode: [''"\s]*30455[''"\s]*\r?\n\s+versionName: [''"]?3\.0\.455[''"]?\s*$') {
    throw 'This patch supports INMO Global 3.0.455 / versionCode 30455 only.'
}
if ($manifest.manifest.package -notin @($oldPackage, $newPackage)) {
    throw 'Unexpected input package. Use your own com.inmo.app.googleplay installation.'
}
$manifest.manifest.SetAttribute('package', $newPackage)
$manifest.manifest.application.SetAttribute('label', $androidNs, 'INMO AutoFoto')
$manifest.manifest.application.SetAttribute('name', $androidNs, 'com.inmo.app.MyApplication')
$manifest.manifest.application.SetAttribute('extractNativeLibs', $androidNs, 'true')
$manifest.manifest.RemoveAttribute('requiredSplitTypes', $androidNs)
$manifest.manifest.RemoveAttribute('splitTypes', $androidNs)
$manifest.manifest.SetAttribute('versionName', $androidNs, '3.0.455-autofoto.5')
foreach ($category in @($manifest.SelectNodes('//category'))) {
    if ($category.GetAttribute('name', $androidNs) -eq 'android.intent.category.LAUNCHER') {
        [void]$category.ParentNode.RemoveChild($category)
    }
}
if (-not ($manifest.manifest.application.activity | Where-Object { $_.GetAttribute('name', $androidNs) -eq 'de.local.inmo.autofoto.SettingsActivity' })) {
    $activity = $manifest.CreateElement('activity')
    $activity.SetAttribute('name', $androidNs, 'de.local.inmo.autofoto.SettingsActivity')
    $activity.SetAttribute('exported', $androidNs, 'true')
    $activity.SetAttribute('label', $androidNs, 'INMO AutoFoto')
    $activity.SetAttribute('theme', $androidNs, '@android:style/Theme.Material.Light.NoActionBar')
    [void]$manifest.manifest.application.AppendChild($activity)
} else {
    $activity = $manifest.manifest.application.activity | Where-Object { $_.GetAttribute('name', $androidNs) -eq 'de.local.inmo.autofoto.SettingsActivity' }
}
# Re-add the custom launcher after removing all previous launcher categories.
foreach ($oldFilter in @($activity.SelectNodes('intent-filter'))) { [void]$activity.RemoveChild($oldFilter) }
$filter = $manifest.CreateElement('intent-filter')
$action = $manifest.CreateElement('action')
$action.SetAttribute('name', $androidNs, 'android.intent.action.MAIN')
$category = $manifest.CreateElement('category')
$category.SetAttribute('name', $androidNs, 'android.intent.category.LAUNCHER')
[void]$filter.AppendChild($action)
[void]$filter.AppendChild($category)
[void]$activity.AppendChild($filter)
$manifest.Save($manifestPath)

# Providers, app-scoped permissions and explicit self-references must use the clone's ID.
$replaceFiles = @($manifestPath) + @(Get-ChildItem -LiteralPath $decoded -Directory -Filter 'smali*' | ForEach-Object {
    Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter '*.smali' |
        Select-String -SimpleMatch -Pattern $oldPackage -List | ForEach-Object Path
})
foreach ($path in $replaceFiles) {
    if (-not $path) { continue }
    $content = [IO.File]::ReadAllText($path)
    [IO.File]::WriteAllText($path, $content.Replace($oldPackage, $newPackage), $utf8)
}

$servicePath = Join-Path $decoded 'smali_classes4\com\inmo\app\module_go3device\services\InmoAiService.smali'
$service = [IO.File]::ReadAllText($servicePath)
if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->handleStart')) {
    $needle = '.method private final startAsr()V'
    if (($service.Split(@($needle), [StringSplitOptions]::None).Length - 1) -ne 1) {
        throw 'Expected exactly one startAsr method in INMO 3.0.455.'
    }
    $hook = @'

    invoke-static {p0}, Lde/local/inmo/autofoto/AutoFoto;->handleStart(Landroid/app/Service;)Z
    move-result v0
    if-eqz v0, :autofoto_original_voice
    return-void
    :autofoto_original_voice
'@
    $service = [regex]::Replace($service, '(\.method private final startAsr\(\)V\r?\n    \.locals 7\r?\n)', {
        param($match) $match.Groups[1].Value + $hook + "`n"
    })
    if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->handleStart')) { throw 'Hook not inserted.' }
    [IO.File]::WriteAllText($servicePath, $service, $utf8)
}

# Stop the glasses AI speech path before it opens a TTS stream or emits audio bytes.
# startTTS uses high registers, so p0 must be passed with invoke-static/range.
if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->blockSpeech')) {
    $ttsHook = @'

    invoke-static/range {p0 .. p0}, Lde/local/inmo/autofoto/AutoFoto;->blockSpeech(Landroid/content/Context;)Z
    move-result v0
    if-eqz v0, :autofoto_original_tts
    move-object/from16 v1, p0
    const/4 v0, 0x0
    iput-boolean v0, v1, Lcom/inmo/app/module_go3device/services/InmoAiService;->needSendTTs:Z
    iput-boolean v0, v1, Lcom/inmo/app/module_go3device/services/InmoAiService;->isTTSing:Z
    return-void
    :autofoto_original_tts
'@
    $service = [regex]::Replace($service, '(\.method public final startTTS\(Ljava/lang/String;ZZZ\)V\r?\n    \.locals 21\r?\n)', {
        param($match) $match.Groups[1].Value + $ttsHook + "`n"
    })
    if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->blockSpeech')) { throw 'TTS guard not inserted.' }
}

# Trace only protocol state and text length after the original display send returns.
if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->noteDisplay')) {
    $displayPattern = '(?s)(\.method public final sendAiChatMessage2Ble\(Lcom/inmo/inmolife/module_base/beans/AiChatMessage;Ljava/lang/String;Ljava/lang/String;\)V.*?)(    return-void\r?\n\.end method)'
    $service = [regex]::Replace($service, $displayPattern, {
        param($match) $match.Groups[1].Value + "    invoke-static/range {p0 .. p1}, Lde/local/inmo/autofoto/AutoFoto;->noteDisplay(Landroid/app/Service;Ljava/lang/Object;)V`n`n" + $match.Groups[2].Value
    })
    if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->noteDisplay')) { throw 'Display trace not inserted.' }
}
$service = $service.Replace('invoke-static/range {p1 .. p1}, Lde/local/inmo/autofoto/AutoFoto;->noteDisplay(Ljava/lang/Object;)V', 'invoke-static/range {p0 .. p1}, Lde/local/inmo/autofoto/AutoFoto;->noteDisplay(Landroid/app/Service;Ljava/lang/Object;)V')
if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->onServiceDestroyed')) {
    $service = [regex]::Replace($service, '(\.method public onDestroy\(\)V\r?\n    \.locals 11\r?\n)', {
        param($match) $match.Groups[1].Value + "`n    invoke-static {p0}, Lde/local/inmo/autofoto/AutoFoto;->onServiceDestroyed(Landroid/app/Service;)V`n"
    })
    if (-not $service.Contains('Lde/local/inmo/autofoto/AutoFoto;->onServiceDestroyed')) { throw 'Destroy hook not inserted.' }
}
[IO.File]::WriteAllText($servicePath, $service, $utf8)
$photoListenerPath = Join-Path $decoded 'smali_classes4\com\inmo\app\module_go3device\services\InmoAiService$inmoAiGlassListener$1.smali'
$photoListener = [IO.File]::ReadAllText($photoListenerPath)
$photoHook = @'
    iget-object v0, p0, Lcom/inmo/app/module_go3device/services/InmoAiService$inmoAiGlassListener$1;->this$0:Lcom/inmo/app/module_go3device/services/InmoAiService;
    invoke-static {v0, p2}, Lde/local/inmo/autofoto/AutoFoto;->notePhoto(Landroid/app/Service;[B)V
'@
$photoListener = $photoListener.Replace('    invoke-static {p2}, Lde/local/inmo/autofoto/AutoFoto;->notePhoto([B)V', $photoHook)
if (-not $photoListener.Contains('Lde/local/inmo/autofoto/AutoFoto;->notePhoto')) {
    $photoListener = [regex]::Replace($photoListener, '(\.method public sendPhotoQuestion\(Ljava/lang/String;\[B\)V\r?\n    \.locals 5\r?\n)', {
        param($match) $match.Groups[1].Value + "`n" + $photoHook + "`n"
    })
    if (-not $photoListener.Contains('Lde/local/inmo/autofoto/AutoFoto;->notePhoto')) { throw 'Photo trace not inserted.' }
}
[IO.File]::WriteAllText($photoListenerPath, $photoListener, $utf8)

$managerPath = Join-Path $decoded 'smali_classes4\com\inmo\app\module_go3device\manager\AiChatProbufProcessManager.smali'
$manager = [IO.File]::ReadAllText($managerPath)
if (-not $manager.Contains('Lde/local/inmo/autofoto/AutoFoto;->handleExistingStart')) {
    $managerHook = @'

    invoke-static {}, Lde/local/inmo/autofoto/AutoFoto;->handleExistingStart()Z
    move-result v0
    if-eqz v0, :autofoto_original_start
    return-void
    :autofoto_original_start
'@
    $manager = [regex]::Replace($manager, '(\.method public final startAiService\(\)V\r?\n    \.locals 5\r?\n)', {
        param($match) $match.Groups[1].Value + $managerHook + "`n"
    })
    if (-not $manager.Contains('Lde/local/inmo/autofoto/AutoFoto;->handleExistingStart')) { throw 'Repeated start hook not inserted.' }
    [IO.File]::WriteAllText($managerPath, $manager, $utf8)
}

$protocolPath = Join-Path $decoded 'smali_classes5\com\inmo\app\module_go3device\utils\bt\ProtocolGenerateHelper.smali'
$protocol = [IO.File]::ReadAllText($protocolPath)
if (-not $protocol.Contains('Lde/local/inmo/autofoto/AutoFoto;->protocolVersion')) {
    $protocol = [regex]::Replace($protocol, '(?s)(\.method public final sendPhoneInfo\(\).*?move-result-object v3\r?\n)', {
        param($match) $match.Groups[1].Value + "`n    invoke-static {v3}, Lde/local/inmo/autofoto/AutoFoto;->protocolVersion(Ljava/lang/String;)Ljava/lang/String;`n    move-result-object v3`n"
    })
    if (-not $protocol.Contains('Lde/local/inmo/autofoto/AutoFoto;->protocolVersion')) { throw 'Protocol version normalization not inserted.' }
    [IO.File]::WriteAllText($protocolPath, $protocol, $utf8)
}

$classDir = Join-Path $taskRoot 'autofoto-classes'
$dexDir = Join-Path $taskRoot 'autofoto-dex'
New-Item -ItemType Directory -Force -Path $classDir,$dexDir | Out-Null
$javaFiles = @((Join-Path $PSScriptRoot 'AutoFoto.java'), (Join-Path $PSScriptRoot 'SettingsActivity.java'))
& (Join-Path $jdk 'bin\javac.exe') -encoding UTF-8 --release 8 -classpath $androidJar -d $classDir @javaFiles
if ($LASTEXITCODE -ne 0) { throw 'Java compile failed.' }
$helperJar = Join-Path $taskRoot 'autofoto-helper.jar'
& (Join-Path $jdk 'bin\jar.exe') cf $helperJar -C $classDir .
& (Join-Path $buildTools 'd8.bat') --min-api 26 --lib $androidJar --output $dexDir $helperJar
if ($LASTEXITCODE -ne 0) { throw 'DEX compile failed.' }

$unsigned = Join-Path $taskRoot 'autofoto-unsigned.apk'
& (Join-Path $jdk 'bin\java.exe') -jar $apktool b $decoded -o $unsigned
if ($LASTEXITCODE -ne 0) { throw 'APK rebuild failed.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($unsigned, [IO.Compression.ZipArchiveMode]::Update)
try {
    if ($archive.GetEntry('classes6.dex')) { throw 'Unexpected sixth DEX in original package.' }
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $dexDir 'classes.dex'), 'classes6.dex', [IO.Compression.CompressionLevel]::Optimal)
} finally { $archive.Dispose() }

$aligned = Join-Path $taskRoot 'autofoto-aligned.apk'
& (Join-Path $buildTools 'zipalign.exe') -f -p 4 $unsigned $aligned
if ($LASTEXITCODE -ne 0) { throw 'Alignment failed.' }
$keystore = Join-Path $taskRoot 'autofoto-local-test.p12'
$passwordFile = Join-Path $taskRoot 'keystore-password.txt'
if (-not $env:AUTOFOTO_KEYSTORE_PASSWORD) {
    if (Test-Path -LiteralPath $passwordFile) {
        $env:AUTOFOTO_KEYSTORE_PASSWORD = [IO.File]::ReadAllText($passwordFile).Trim()
    } elseif (Test-Path -LiteralPath $keystore) {
        throw 'Keystore exists without a password file. Set AUTOFOTO_KEYSTORE_PASSWORD to its password.'
    } else {
        $env:AUTOFOTO_KEYSTORE_PASSWORD = [Guid]::NewGuid().ToString('N')
        [IO.File]::WriteAllText($passwordFile, $env:AUTOFOTO_KEYSTORE_PASSWORD, $utf8)
    }
}
if (-not (Test-Path -LiteralPath $keystore)) {
    & (Join-Path $jdk 'bin\keytool.exe') -genkeypair -keystore $keystore -storetype PKCS12 -storepass:env AUTOFOTO_KEYSTORE_PASSWORD -keypass:env AUTOFOTO_KEYSTORE_PASSWORD -alias autofoto -keyalg RSA -keysize 2048 -validity 3650 -dname 'CN=Local INMO AutoFoto Test'
    if ($LASTEXITCODE -ne 0) { throw 'Test signing key creation failed.' }
}
$output = Join-Path $OutputDirectory 'INMO-AutoFoto-Test.apk'
& (Join-Path $buildTools 'apksigner.bat') sign --ks $keystore --ks-pass env:AUTOFOTO_KEYSTORE_PASSWORD --key-pass env:AUTOFOTO_KEYSTORE_PASSWORD --ks-key-alias autofoto --out $output $aligned
if ($LASTEXITCODE -ne 0) { throw 'Signing failed.' }
& (Join-Path $buildTools 'apksigner.bat') verify --verbose $output
if ($LASTEXITCODE -ne 0) { throw 'Signature verification failed.' }
Write-Output "Built: $output"
