function Get-PythonVersion {
    
}

function Global:Invoke-VenvCommand {
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [string]$Action=$null,
        
        [Parameter(Position=1, Mandatory=$false)]
        [string]$Name=$null,

        [Parameter(Position=2, Mandatory=$false)]
        [string]$Version=$(& python -V 2>&1).Split(' ')[-1],

        [Parameter(Position=3, Mandatory=$false)]
        [string]$PythonExePath=$null
    )

    $VenvsBasePath = Join-Path -Path $env:USERPROFILE -ChildPath "venvs"

    # Check if Action is provided; if not, display available options
    if (-not $Action -or $Action -eq "") {
        Write-Host "No action specified. Available actions are: create, delete, list, activate, deactivate"
    }else{
        switch ($Action) {
            'create' {
                $VenvPath = Join-Path -Path $VenvsBasePath -ChildPath $Name
                New-VenvEnvironment $VenvPath $Version $PythonExePath
            }
            'delete' {
                $VenvPath = Join-Path -Path $VenvsBasePath -ChildPath $Name
                Remove-VenvEnvironment $VenvPath
            }
            'activate' {
                $VenvPath = Join-Path -Path $VenvsBasePath -ChildPath $Name
                Enable-VenvActivation $VenvPath
            }
            'deactivate' {
                Disable-VenvActivation
            }
            'list' {
                Get-VenvList $VenvsBasePath
            }
            default {
                Write-Host "Invalid command. Use 'create', 'delete', 'activate', 'deactivate', or 'list'."
            }
        }
    }
}

function Get-VenvList {
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

Set-Alias -Name 'venv' -Value 'Invoke-VenvCommand'

function New-VenvEnvironment {
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$VenvPath,

        [Parameter(Position=1, Mandatory=$false)]
        [string]$Version=$null,

        [Parameter(Position=2, Mandatory=$false)]
        [string]$PythonExePath=$null
    )

    $jsonPath = Join-Path -Path $PSScriptRoot -ChildPath "PythonVersions.json"

    # Load existing versions from JSON or initialize an empty list
    $versionsList = @()
    if (Test-Path $jsonPath) {
        $versionsList = Get-Content $jsonPath | ConvertFrom-Json
    }

    if ($Version -and -not $PythonExePath) {
        $existingEntry = $versionsList | Where-Object { $_.Version -eq $Version }
        if ($existingEntry) {
            $PythonExePath = $existingEntry.Path
        } else {           
            do {
                $PythonExePath = Read-Host "Specify the path to python.exe"
                if (Test-Path $PythonExePath -PathType Leaf) {
                    # Check Python version
                    $output = & $PythonExePath -V 2>&1
                    $correctVersion = $output -match $Version
                    
                    if (-not $correctVersion) {
                        Write-Host "The Python executable at $PythonExePath does not match the requested version $Version."
                    }
                } else {
                    Write-Host "Path is invalid. Please enter a valid path."
                }
            } while (-not $correctVersion)

            $versionsList += [PSCustomObject]@{Version=$Version; Path=$PythonExePath}
            $versionsList | ConvertTo-Json | Set-Content $jsonPath
        }
    }

    if ($PythonExePath) {
        & $PythonExePath -m venv $VenvPath
    } else {
        python -m venv $VenvPath
    }

    if ($?) {
        Write-Host "Virtual environment created successfully at '$VenvPath'."
    } else {
        Write-Host "Failed to create virtual environment at '$VenvPath'."
    }
}


function Remove-VenvEnvironment {
    param([string]$VenvPath)
    if (Test-Path $VenvPath) {
        Remove-Item -Recurse -Force $VenvPath
        Write-Host "Virtual environment deleted successfully at '$VenvPath'."
    } else {
        Write-Host "Virtual environment at '$VenvPath' does not exist."
    }
}

function Enable-VenvActivation {
    param([string]$VenvPath)
    $scriptPath = Join-Path -Path $VenvPath -ChildPath "Scripts\Activate.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath
        Write-Host "Virtual environment activated at '$VenvPath'."
    } else {
        Write-Host "Virtual environment at '$VenvPath' not found or does not contain an activation script."
    }
}

function Disable-VenvActivation {
    Remove-Item env:VIRTUAL_ENV -ErrorAction SilentlyContinue
    $env:PATH = ($env:PATH -split ';' | Where-Object { $_ -notmatch 'venvs' }) -join ';'
    Write-Host "Attempted to deactivate any active virtual environment."
    Write-Host "Please close and reopen your PowerShell session to ensure all environment variables are reset."
}