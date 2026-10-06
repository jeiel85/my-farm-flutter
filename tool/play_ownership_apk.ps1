<#
.SYNOPSIS
  Play Console(Android developer verification) 패키지명 소유 증명용 APK를 만든다.

.DESCRIPTION
  Play Console이 패키지명 등록 중에 소유 증명을 요구하면, 화면에 나온 스니펫을 파일로 저장해 이 스크립트에 넘긴다.
  스니펫을 android/app/src/main/assets/에 넣고 배포용과 같은 키로 서명한 릴리스 APK를 만든 뒤,
  build/play-ownership/에 복사하고 스니펫 파일은 지운다(배포하는 앱에는 들어가지 않는다).

  서명 정보는 release_android.ps1과 같다(.keystore/release-signing.properties 또는 환경변수, 커밋 금지).
  Play Console에는 이 APK만 올리면 되고, 사용자에게 배포하는 APK와는 별개다.

.EXAMPLE
  pwsh tool/play_ownership_apk.ps1 -Snippet C:\Users\me\Downloads\adi-registration.properties
  pwsh tool/play_ownership_apk.ps1 -Snippet .\snippet.txt -FileName adi-registration.properties
#>
param(
  # Play Console이 준 스니펫(내용 그대로 저장한 파일).
  [Parameter(Mandatory)] [string]$Snippet,
  # APK assets/ 안의 파일 이름. Play Console 안내에 적힌 이름과 같아야 한다.
  [string]$FileName = 'adi-registration.properties'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path $Snippet)) { throw "스니펫 파일이 없습니다: $Snippet" }
$assetsDir = Join-Path $root 'android/app/src/main/assets'
$createdDir = -not (Test-Path $assetsDir)
$target = Join-Path $assetsDir $FileName
if (Test-Path $target) { throw "이미 $target 이 있습니다. 확인 후 지우고 다시 실행하세요." }

New-Item -ItemType Directory -Force $assetsDir | Out-Null
Copy-Item $Snippet $target
try {
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build apk --release 실패' }
  $outDir = Join-Path $root 'build/play-ownership'
  New-Item -ItemType Directory -Force $outDir | Out-Null
  $out = Join-Path $outDir 'my-farm-ownership.apk'
  $built = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
  Move-Item $built $out -Force
  # 표준 출력 위치에 증명용 APK가 남으면 release_android.ps1 -SkipBuild가 그것을 배포할 수 있다.
  Remove-Item "$built.sha1" -Force -ErrorAction SilentlyContinue
  Write-Host "소유 증명용 APK: $out"
  Write-Host 'Play Console의 Android developer verification 페이지에서 이 APK를 올리세요.'
} finally {
  # 배포용 빌드에 스니펫이 섞이지 않게 항상 지운다.
  Remove-Item $target -Force
  if ($createdDir -and -not (Get-ChildItem $assetsDir -Force)) { Remove-Item $assetsDir -Force }
}
