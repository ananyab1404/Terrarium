$ErrorActionPreference = 'Stop'

Write-Host '== Distributed Scheduler prerequisite setup ==' -ForegroundColor Cyan

function Test-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-ToSessionPathIfExists {
    param([Parameter(Mandatory = $true)][string]$PathToAdd)
    if (Test-Path $PathToAdd) {
        if (-not ($env:Path -split ';' | Where-Object { $_ -eq $PathToAdd })) {
            $env:Path = "$PathToAdd;$env:Path"
            Write-Host "Added to current session PATH: $PathToAdd" -ForegroundColor Yellow
        }
    }
}

# Refresh common install locations for current shell
Add-ToSessionPathIfExists 'C:\Program Files\Amazon\AWSCLIV2'
Add-ToSessionPathIfExists 'C:\Program Files\Erlang OTP\bin'
Add-ToSessionPathIfExists 'C:\Program Files\Elixir\bin'
Add-ToSessionPathIfExists 'C:\tools\elixir\bin'

# Install Erlang OTP via winget if missing
if (-not (Test-Command 'erl')) {
    Write-Host 'Installing Erlang OTP via winget...' -ForegroundColor Cyan
    winget install --id Erlang.ErlangOTP --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
}

# Install AWS CLI via winget if missing
if (-not (Test-Command 'aws')) {
    Write-Host 'Installing AWS CLI v2 via winget...' -ForegroundColor Cyan
    winget install --id Amazon.AWSCLI --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
}

# Elixir is usually easiest through chocolatey on Windows (often requires admin)
if (-not (Test-Command 'elixir')) {
    Write-Host 'Elixir not found.' -ForegroundColor Yellow
    Write-Host 'Attempting Chocolatey install (may require elevated PowerShell)...' -ForegroundColor Yellow
    try {
        choco install elixir -y --no-progress
    }
    catch {
        Write-Host 'Chocolatey install failed in non-elevated shell.' -ForegroundColor Red
        Write-Host 'Re-run this script in an Administrator PowerShell to install Elixir.' -ForegroundColor Red
    }
}

# Re-add common paths after installation attempts
Add-ToSessionPathIfExists 'C:\Program Files\Amazon\AWSCLIV2'
Add-ToSessionPathIfExists 'C:\Program Files\Erlang OTP\bin'
Add-ToSessionPathIfExists 'C:\Program Files\Elixir\bin'
Add-ToSessionPathIfExists 'C:\tools\elixir\bin'

Write-Host "\n== Verification ==" -ForegroundColor Cyan
$tools = @('erl', 'elixir', 'mix', 'aws')
foreach ($tool in $tools) {
    if (Test-Command $tool) {
        Write-Host ("{0}: FOUND" -f $tool) -ForegroundColor Green
    }
    else {
        Write-Host ("{0}: MISSING" -f $tool) -ForegroundColor Red
    }
}

if (Test-Command 'erl') { erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell }
if (Test-Command 'elixir') { elixir --version }
if (Test-Command 'aws') { aws --version }

Write-Host "\nDone. If Elixir is still missing, run this script as Administrator." -ForegroundColor Cyan
