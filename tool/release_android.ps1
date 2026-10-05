<#
.SYNOPSIS
  릴리스 APK와 앱 안 업데이트용 update.json을 만들고, -Publish면 GitHub 릴리스로 올린다.

.DESCRIPTION
  앱(lib/data/app_update.dart)은 최신 릴리스의 'update.json' 자산을
  https://github.com/jeiel85/my-farm-flutter/releases/latest/download/update.json 으로 읽는다.
  값은 손으로 적지 않고 빌드한 APK에서 aapt2로 뽑아(versionCode·versionName·minSdk) pubspec.yaml과 대조한다.

  서명 키는 저장소 밖(.keystore/, 커밋 금지)에 있으므로 이 스크립트는 로컬에서만 돈다.
  -Publish는 HEAD가 origin/main과 같을 때만 태그(vX.Y.Z)를 만들어 올린다.

.EXAMPLE
  pwsh tool/release_android.ps1            # build/release/에 APK와 update.json만 만든다
  pwsh tool/release_android.ps1 -Publish   # 위 산출물로 GitHub 릴리스를 만든다
#>
param(
  [switch]$Publish,
  # 이미 빌드한 APK를 다시 쓰려면 지정한다.
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repo = 'jeiel85/my-farm-flutter'
$packageName = 'com.jeiel85.myfarm'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$versionLine = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$'
if (-not $versionLine) { throw 'pubspec.yaml에서 version: X.Y.Z+N 을 찾지 못했습니다.' }
$versionName = $versionLine.Matches[0].Groups[1].Value
$versionCode = [int]$versionLine.Matches[0].Groups[2].Value
$tag = "v$versionName"

if (-not $SkipBuild) {
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build apk --release 실패' }
}
$builtApk = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path $builtApk)) { throw "APK가 없습니다: $builtApk" }

# 최신 build-tools의 aapt2로 APK 안의 실제 값을 읽는다.
$sdk = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android/Sdk')) |
  Where-Object { $_ -and (Test-Path (Join-Path $_ 'build-tools')) } | Select-Object -First 1
if (-not $sdk) { throw 'Android SDK(build-tools)를 찾지 못했습니다. ANDROID_HOME을 설정하세요.' }
$aapt2 = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory |
  Sort-Object { [version]($_.Name -replace '[^\d.].*$', '') } -Descending |
  ForEach-Object { Get-ChildItem $_.FullName -Filter 'aapt2*' -File } | Select-Object -First 1
if (-not $aapt2) { throw 'aapt2를 찾지 못했습니다.' }
$badging = & $aapt2.FullName dump badging $builtApk
if ($LASTEXITCODE -ne 0) { throw 'aapt2 dump badging 실패' }
$pkg = ($badging | Select-String "^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'").Matches[0].Groups
$minSdk = [int]($badging | Select-String "^(?:sdkVersion|minSdkVersion):'(\d+)'").Matches[0].Groups[1].Value
if ($pkg[1].Value -ne $packageName) { throw "패키지 이름이 다릅니다: $($pkg[1].Value)" }
if ([int]$pkg[2].Value -ne $versionCode -or $pkg[3].Value -ne $versionName) {
  throw "APK($($pkg[3].Value)+$($pkg[2].Value))와 pubspec($versionName+$versionCode)이 다릅니다. 다시 빌드하세요."
}

$outDir = Join-Path $root 'build/release'
New-Item -ItemType Directory -Force $outDir | Out-Null
$apkName = "my-farm-$tag.apk"
$apk = Join-Path $outDir $apkName
Copy-Item $builtApk $apk -Force
$size = (Get-Item $apk).Length
$sha256 = (Get-FileHash $apk -Algorithm SHA256).Hash.ToLowerInvariant()

# 앱의 UpdateManifest.parse와 같은 일곱 키. 하나라도 빠지면 앱이 전체를 버린다.
$manifest = [ordered]@{
  versionCode     = $versionCode
  versionName     = $versionName
  apkUrl          = "https://github.com/$repo/releases/download/$tag/$apkName"
  apkSizeBytes    = $size
  sha256          = $sha256
  minSdk          = $minSdk
  releaseNotesUrl = "https://github.com/$repo/releases/tag/$tag"
}
$manifestPath = Join-Path $outDir 'update.json'
$manifest | ConvertTo-Json | Set-Content $manifestPath -Encoding utf8NoBOM
Write-Host "APK:  $apk ($size bytes)"
Write-Host "SHA-256: $sha256"
Write-Host "update.json: $manifestPath"

if (-not $Publish) { return }

git fetch origin main --quiet
$head = git rev-parse HEAD
if ($head -ne (git rev-parse origin/main)) { throw 'HEAD가 origin/main과 다릅니다. main을 최신으로 맞춘 뒤 릴리스하세요.' }
if (git status --porcelain --untracked-files=no) { throw '커밋하지 않은 변경이 있습니다.' }

# 릴리스 노트는 CHANGELOG.md의 해당 버전 절을 그대로 쓴다.
$changelog = Get-Content CHANGELOG.md -Raw -Encoding utf8
$section = [regex]::Match($changelog, "(?ms)^## $([regex]::Escape($versionName))\b[^\n]*\n(.*?)(?=^## |\z)")
if (-not $section.Success) { throw "CHANGELOG.md에 $versionName 절이 없습니다." }
$notes = Join-Path $outDir 'release-notes.md'
$section.Groups[1].Value.Trim() | Set-Content $notes -Encoding utf8NoBOM

gh release create $tag $apk $manifestPath --repo $repo --target $head --title $tag --notes-file $notes
if ($LASTEXITCODE -ne 0) { throw 'gh release create 실패' }

# 올라간 자산의 크기가 0이 아닌지, 앱이 읽는 고정 주소가 이 릴리스를 가리키는지 확인한다.
$assets = gh release view $tag --repo $repo --json assets | ConvertFrom-Json
foreach ($name in @($apkName, 'update.json')) {
  $asset = $assets.assets | Where-Object name -eq $name
  if (-not $asset -or $asset.size -le 0) { throw "릴리스 자산이 비어 있습니다: $name" }
}
$latest = Invoke-RestMethod "https://github.com/$repo/releases/latest/download/update.json"
if ($latest.versionCode -ne $versionCode) { throw "latest/download/update.json이 $($latest.versionCode)를 가리킵니다." }
Write-Host "Published $tag"
