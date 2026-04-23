#!/usr/bin/env pwsh
# 从 jiangnan823/opencode 的 releases 拉取最新 Windows x64 二进制
# 用法: powershell.exe -ExecutionPolicy Bypass -File sg-opencode-update.ps1

$ErrorActionPreference = "Stop"

$Repo = "jiangnan823/opencode"
$Asset = "opencode-windows-x64.zip"

Write-Host "→ 查询最新 release..."
$Tag = gh release view --repo $Repo --json tagName -q .tagName
if (-not $Tag) {
    Write-Host "✗ 查询 release 失败。确认 gh 已登录。" -ForegroundColor Red
    exit 1
}
Write-Host "  latest: $Tag"

# 定位 opencode.exe
$BinPath = $null
$cmd = Get-Command opencode -ErrorAction SilentlyContinue
if ($cmd) {
    $BinPath = $cmd.Source
}
if (-not $BinPath) {
    $BinPath = Join-Path $env:USERPROFILE ".opencode\bin\opencode.exe"
}
$BinDir = Split-Path $BinPath -Parent

$Current = "none"
if (Test-Path $BinPath) {
    try {
        $ver = & $BinPath --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $ver) { $Current = "v$($ver.Trim())" }
    } catch {}
}
Write-Host "  current: $Current"
Write-Host "  location: $BinPath"

if ($Current -eq $Tag) {
    Write-Host "✓ 已是最新"
    exit 0
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("opencode-update-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    Write-Host "→ 下载 $Asset..."
    gh release download $Tag --repo $Repo --pattern $Asset --dir $Tmp
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ 下载失败" -ForegroundColor Red
        exit 1
    }

    Write-Host "→ 解压..."
    $ZipPath = Join-Path $Tmp $Asset
    Expand-Archive -Path $ZipPath -DestinationPath $Tmp -Force

    $NewExe = Join-Path $Tmp "opencode.exe"
    if (-not (Test-Path $NewExe)) {
        Write-Host "✗ 解压结果里未找到 opencode.exe" -ForegroundColor Red
        Get-ChildItem $Tmp | Format-Table
        exit 1
    }

    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }

    if (Test-Path $BinPath) {
        $Backup = "$BinPath.bak." + (Get-Date -Format "yyyyMMdd-HHmmss")
        Write-Host "→ 备份当前版本 → $Backup"
        Move-Item $BinPath $Backup -Force
    }

    Write-Host "→ 安装新版本..."
    Move-Item $NewExe $BinPath -Force

    Write-Host "✓ 已更新到 $Tag" -ForegroundColor Green
    & $BinPath --version
} finally {
    Remove-Item $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
