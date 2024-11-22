#!/usr/env pwsh

$errorActionPreference = "Stop"
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', "Internal PS variable"
)]
$PSNativeCommandUseErrorActionPreference = $true

# include
. "$env:HOME/.apollox/scripts/utils/stackTrace.ps1"
. "$env:HOME/.apollox/scripts/utils/execHostCommand.ps1"
. "$env:HOME/.apollox/scripts/utils/network.ps1"

function _get_GpuVendor() {
    param(
        [Parameter(Mandatory=$true)]
        [string] $model,
        [boolean] $rcPrefix=$false
    )

    $_modelLower = $model.ToLower()

    if ($_modelLower.Contains("am62")) {
        return $rcPrefix ? "-am62" : "-am62"
    } elseif ($_modelLower.Contains("beagleplay")) {
        return $rcPrefix ? "-am62" : "-am62"
    } elseif ($_modelLower.Contains("imx8")) {
        return $rcPrefix ? "-imx8" : "-vivante"
    } else {
        # generic non gpu specific
        return ""
    }
}

Write-Host "⚒️ :: INITIALIZING WORKSPACE :: ⚒️"
Write-Host ""

# check if we have a target device set
if (!(Test-Path $env:HOME/.tcd/target.json)) {
    Write-Host -ForegroundColor Red "❌ :: No target device set :: ❌"
    Write-Host ""
    exit 404
}

# check if the workspace is valid
if (!(Test-Path ./.conf/.template) -or !(Get-Content ./.conf/metadata.json | ConvertFrom-Json).templateName) {
    Write-Host -ForegroundColor Red "❌ :: This folder does not have a valid Torizon project Workspace :: ❌"
    Write-Host ""
    exit 400
} else {
    # wsl share ports should be run by the tcd env setup
    # mimic the vs code auto run tasks
    Write-Host "🔧 :: Running Local Registry :: 🔧"
    Write-Host ""
    $env:TASKS_USE_PWSH_INSTEAD_BASH=$true
    ./.vscode/tasks.ps1 run run-docker-registry

    Write-Host ""
    Write-Host "🔧 :: Running Binfmt :: 🔧"
    ./.vscode/tasks.ps1 run run-torizon-binfmt

    Write-Host ""
    Write-Host "🔧 :: Running Check dependency :: 🔧"
    ./.vscode/tasks.ps1 run check-deps

    # set the target device to the settings.json
    $_settings =
        Get-Content ./.vscode/settings.json -Raw `
            | ConvertFrom-Json -Depth 100
    $_target =
        Get-Content $env:HOME/.tcd/target.json -Raw `
            | ConvertFrom-Json -Depth 100

    $_rcPrefix = $_settings.torizon.gpuPrefixRC;
    if ($null -eq $_rcPrefix) {
        $_rcPrefix = $false
    }

    $_hostName = $_target.Hostname
    $_settings.torizon_psswd = $_target.__pass__
    $_settings.torizon_ip = $_target.Ip
    $_settings.torizon_ssh_port = "$($_target.SshPort)"
    $_settings.torizon_login = $_target.Login
    $_settings.host_ip = GetHostIp
    $_settings.torizon_arch = $_target.Arch
    $_settings.torizon_gpu = _get_GpuVendor -model $_target.Model -rcPrefix $_rcPrefix

    # dump the object back to the file
    $_settings | ConvertTo-Json -Depth 100 `
        | Set-Content ./.vscode/settings.json

    Write-Host ""
    Write-Host `
        -ForegroundColor Green `
        "✅ :: Project initialized to work with $_hostName :: ✅"
    Write-Host ""
}
