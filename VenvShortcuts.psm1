function Global:Venv-Command {
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [string]$Action=$null,
        
        [Parameter(Position=1, Mandatory=$false)]
        [string]$Name=$null
    )

    $VenvsBasePath = Join-Path -Path "D:\" -ChildPath "VENVs"

    # Check if Action is provided; if not, display available options
    if (-not $Action -or $Action -eq "") {
        Write-Host "No action specified. Available actions are: create, delete, list, activate, deactivate"
    }else{
        switch ($Action) {
            'create' {
                $VenvPath = Join-Path -Path $VenvsBasePath -ChildPath $Name
                Venv-Create $VenvPath
            }
            'delete' {
                $VenvPath = Join-Path -Path $VenvsBasePath -ChildPath $Name
                Venv-Delete $VenvPath
            }
            'activate' {
                $VenvPath = Join-Path -Path $VenvsBasePath -ChildPath $Name
                Venv-Activate $VenvPath
            }
            'deactivate' {
                Venv-Deactivate
            }
            'list' {
                Venv-List $VenvsBasePath
            }
            default {
                Write-Host "Invalid command. Use 'create', 'delete', 'activate', 'deactivate', or 'list'."
            }
        }
    }
}

function Global:Venv-List {
    param([string]$VenvsBasePath)
    if (Test-Path $VenvsBasePath) {
        $venvs = Get-ChildItem -Path $VenvsBasePath -Directory | Select-Object -ExpandProperty Name
        if ($venvs) {
            Write-Host "Existing virtual environments:"
            $venvs | ForEach-Object { Write-Host $_ }
        } else {
            Write-Host "No virtual environments found."
        }
    } else {
        Write-Host "The VENVs directory does not exist."
    }
}

# Keep the existing functions (Venv-Create, Venv-Delete, Venv-Activate, Venv-Deactivate) unchanged.

Set-Alias -Name 'venv' -Value 'Venv-Command'

function Global:Venv-Create {
    param([string]$VenvPath)
    python -m venv $VenvPath
    if ($?) {
        Write-Host "Virtual environment created successfully at '$VenvPath'."
    } else {
        Write-Host "Failed to create virtual environment at '$VenvPath'."
    }
}

function Global:Venv-Delete {
    param([string]$VenvPath)
    if (Test-Path $VenvPath) {
        Remove-Item -Recurse -Force $VenvPath
        Write-Host "Virtual environment deleted successfully at '$VenvPath'."
    } else {
        Write-Host "Virtual environment at '$VenvPath' does not exist."
    }
}

function Global:Venv-Activate {
    param([string]$VenvPath)
    $scriptPath = Join-Path -Path $VenvPath -ChildPath "Scripts\Activate.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath
        Write-Host "Virtual environment activated at '$VenvPath'."
    } else {
        Write-Host "Virtual environment at '$VenvPath' not found or does not contain an activation script."
    }
}

function Global:Venv-Deactivate {
    Remove-Item env:VIRTUAL_ENV -ErrorAction SilentlyContinue
    $env:PATH = ($env:PATH -split ';' | Where-Object { $_ -notmatch 'VENVs' }) -join ';'
    Write-Host "Attempted to deactivate any active virtual environment."
    Write-Host "Please close and reopen your PowerShell session to ensure all environment variables are reset."
}

Set-Alias -Name 'venv' -Value 'Venv-Command'
