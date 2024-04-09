# Declare global variables
$global:GlobPyVersion = ""
$global:GlobPythonExePath = ""
$global:VenvsBasePath = "I:\Venvs"
$global:jsonPath = Join-Path -Path $PSScriptRoot -ChildPath "PythonVersions.json"

# Example: Assuming Python is in your PATH environment variable
function Get-PythonInfo {
    $global:GlobPyVersion = (python --version).Split(' ')[1] 
    $global:GlobPythonExePath = (Get-Command python).Path
}

function Invoke-VenvCommand {
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [string]$Action=$null,
        
        [Parameter(Position=1, Mandatory=$false)]
        [string]$Name=$null,

        [Parameter(Position=2, Mandatory=$false)]
        [string]$Version=$null
    )
    # Update global variables
    Get-PythonInfo

    if($Action -eq "c"){
        $Action = "create"
    } elseif($Action -eq "r"){
        $Action = "remove"
    } elseif($Action -eq "a"){
        $Action = "activate"
    } elseif($Action -eq "d"){
        $Action = "deactivate"
    } elseif($Action -eq "l"){
        $Action = "list"
    } elseif($Action -eq "h"){
        $Action = "help"
    }else{
        Write-Host "Invalid command. Use 'create' (c), 'remove' (r), 'activate' (a), 'deactivate' (d), or 'list' (l)."
        return
    }

    if (-not $Action -or $Action -eq "") {
        Write-Host "No action specified. Available actions are: create, remove, list, activate, deactivate"
    } else {
        switch ($Action) {
            'create' {
                New-VenvEnvironment $Name $Version 
            }
            'remove' {
                Remove-VenvEnvironment $Name
            }
            'activate' {
                Enable-VenvActivation $Name
            }
            'deactivate' {
                Disable-VenvActivation
            }
            'list' {
                Get-VenvList
            }
            'help' {
                Get-Help -VenvsHelpFile "$PSScriptRoot\README.txt"
            }
            default {
                Write-Host "Invalid command. Use 'create', 'remove', 'activate', 'deactivate', or 'list'."
            }
        }
    }
}

function Get-VenvList {
    $venvs = Get-ChildItem -Path $global:VenvsBasePath -Directory | Select-Object -ExpandProperty Name
    if ($venvs) {
        Write-Host "Existing virtual environments:"
        $venvs | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No virtual environments found."
    }
}

function New-VenvEnvironment {
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Position=1, Mandatory=$false)]
        [string]$Version = $null
    )

    if ($null -eq $Version) {
        # Use the default Python interpreter to create the virtual environment
        python -m venv "$global:VenvsBasePath\$Name"
        Write-Host "Virtual environment created at: $global:VenvsBasePath\$Name"
    } else {
        $PythonExePath = $null
        $jsonPath = Join-Path -Path $PSScriptRoot -ChildPath "PythonVersions.json"
        
        if (Test-Path $jsonPath) {
            $content = Get-Content $jsonPath | ConvertFrom-Json
            $storedMatch = $content | Where-Object { $_.Version -eq $Version } | Select-Object -First 1
            if ($storedMatch) {
                $PythonExePath = $storedMatch.Path
            } else {
                Write-Host "Python version entered has not been stored yet."
                $userResponse = Read-Host "Do you want to enter a path to a Python v.$Version executable? (y/N)"
                
                if ($userResponse -eq "y") {
                    $PythonExePath = Read-Host "Enter the path to the Python v.$Version executable"
                    
                    if (-not (Test-Path -PathType Leaf $PythonExePath)) {
                        Write-Host "The path entered does not exist."
                        return
                    }
                    
                    if (-not ($PythonExePath -match "python\.exe$")) {
                        Write-Host "The path entered does not point to a Python executable."
                        return
                    }
                    
                    $pythonVersionOutput = & $PythonExePath --version
                    if ($pythonVersionOutput -match 'Python (\d+\.\d+\.\d+)' -and $matches[1] -ne $Version) {
                        Write-Host "The Python version ($matches[1]) does not match the version specified ($Version)."
                        return
                    }
                    
                    # This part was moved inside the block where user confirms to enter a path
                    $newEntry = [PSCustomObject]@{
                        Version = $Version
                        Path = $PythonExePath
                    }
                    $content += $newEntry
                    $content | ConvertTo-Json | Set-Content $jsonPath
                } else {
                    Write-Host "You can download Python from here and try again: https://www.python.org/search/?q=$Version&submit="
                    return
                }
            }
            
            # Ensure this command executes regardless of whether a stored match was found or user provided a new path
            & $PythonExePath -m venv "$global:VenvsBasePath\$Name"
            Write-Host "Virtual environment created successfully at '$global:VenvsBasePath\$Name'."
        } else {
            Write-Host "JSON file missing. Please create a file named 'PythonVersions.json' in ${PSScriptRoot}:"
        }
    }
}


function Enable-VenvActivation {
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Name
    )

    $VenvPath = Join-Path -Path $global:VenvsBasePath -ChildPath $Name
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

function Remove-VenvEnvironment {
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Name=$null

    $VenvPath = Join-Path -Path $global:VenvsBasePath -ChildPath $Name
    if (Test-Path $VenvPath) {
        Remove-Item -Path $VenvPath -Recurse -Force
        Write-Host "Virtual environment '$Name' removed."
    } else {
        Write-Host "Virtual environment '$Name' not found."
    }
}

function Get-Help {
    param([string]$VenvsHelpFile)
    if (Test-Path $VenvsHelpFile) {
        Get-Content $VenvsHelpFile
    } else {
        Write-Host "Help file not found."
    }
}