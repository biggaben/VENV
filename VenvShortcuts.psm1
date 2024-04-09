# Declare global variables
$global:Version = ""
$global:PythonExePath = ""

# Example: Assuming Python is in your PATH environment variable
function Get-PythonInfo {
    try {
        $global:Version = (python --version).Split(' ')[1] 
        $global:PythonExePath = (Get-Command python).Path
    } catch { 
        $global:Version = "Python not found"
        $global:PythonExePath = "Python executable not found"
    }
}

function Invoke-VenvCommand {
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [string]$Action=$null,
        
        [Parameter(Position=1, Mandatory=$false)]
        [string]$Name=$null,

        [Parameter(Position=2, Mandatory=$false)]
        [string]$Version=$null,

        [Parameter(Position=3, Mandatory=$false)]
        [string]$PythonExePath=$null
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

    $VenvsBasePath = Join-Path -Path $env:USERPROFILE -ChildPath "Venvs"

    if (-not $Action -or $Action -eq "") {
        Write-Host "No action specified. Available actions are: create, remove, list, activate, deactivate"
    } else {
        switch ($Action) {
            'create' {
                $VenvPath = Join-Path -Path $VenvsBasePath -ChildPath $Name
                New-VenvEnvironment $VenvPath $Version $PythonExePath
            }
            'remove' {
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
        [string]$Version = $null,
        
        [Parameter(Position=2, Mandatory=$false)]
        [string]$PythonExePath = $null
    )
    # Print the results

    if (-not $Version -match '^\d+\.\d+\.\d+$') {
        Write-Host "Failed to parse Python version correctly. Received output: $Version"
    }
    # Function logic here
    Write-Host "Creating virtual environment at: $VenvPath"
    if ($Version -eq "Python not found" -or $PythonExePath -eq "Python executable not found") {
        Write-Host "Error: Unable to locate Python installation."
        return
    }

    $jsonPath = Join-Path -Path $PSScriptRoot -ChildPath "PythonVersions.json"

    [System.Collections.Generic.List[object]]$versionsList = New-Object System.Collections.Generic.List[object]
    if (Test-Path $jsonPath) {
        $content = Get-Content $jsonPath | ConvertFrom-Json
        foreach ($entry in $content) {
            $versionsList.Add($entry)
        }
    }

    if ($Version -and -not $PythonExePath) {
        $matchingVersions = $versionsList | Where-Object { $_.Version -like "$Version.*" }

        if ($matchingVersions.Count -eq 1) {
            # If exactly one version matches, use it
            $PythonExePath = $matchingVersions[0].Path
        } elseif ($matchingVersions.Count -gt 1) {
            # If multiple versions match, list them and ask the user to choose
            Write-Host "Multiple matching Python versions found:"
            $index = 1
            foreach ($version in $matchingVersions) {
                Write-Host "$($index): Python $($version.Version) at $($version.Path)"
                $index++
            }
        
            $selection = Read-Host "Enter the number of the version you want to use"
            $selectedVersion = $matchingVersions[$selection - 1]
        
            if ($null -ne $selectedVersion) {
                $PythonExePath = $selectedVersion.Path
            } else {
                Write-Host "Invalid selection. Operation canceled."
                return
            }
        } else {
            # No versions found that match the pattern; ask if user wants to manually specify a path or get a download link
            $providePathResponse = Read-Host "No versions matching '$($Version)' found. Would you like to provide a path manually? (Y/N)"
            if ($providePathResponse -eq 'Y' -or $providePathResponse -eq 'y') {
                $PythonExePath = Read-Host "Please specify the path to python.exe"
                # Validate the provided path...
                $validationPassed = $false
                do {
                    if (Test-Path $PythonExePath -PathType Leaf) {
                        # Capture the version directly from the Python command
                        try {
                            $outputVersion = & $PythonExePath --version 2>&1
                            if ($outputVersion -match 'Python (\d+\.\d+\.\d+)') {
                                $foundVersion = $matches[1]
                                # If a specific minor version was requested (e.g., 3.8), but not a micro version (e.g., 3.8.1),
                                # then only compare the major and minor parts
                                $versionParts = $Version -split '\.'
                                $foundVersionParts = $foundVersion -split '\.'
                                
                                $versionToCompare = if ($versionParts.Count -eq 2) { "$($versionParts[0]).$($versionParts[1])" } else { $Version }
                                $foundVersionToCompare = if ($versionParts.Count -eq 2) { "$($foundVersionParts[0]).$($foundVersionParts[1])" } else { $foundVersion }

                                if ($versionToCompare -eq $foundVersionToCompare) {
                                    $validationPassed = $true
                                } else {
                                    Write-Host "The Python executable at $PythonExePath does not match the requested version $Version. Found version: $foundVersion"
                                }
                            } else {
                                Write-Host "Unable to determine the Python version from the provided executable: $PythonExePath"
                            }
                        } catch {
                            Write-Host "An error occurred while trying to verify the Python version: $_"
                        }
                    } else {
                        Write-Host "The provided path does not point to a valid file: $PythonExePath"
                    }
                    
                    if (-not $validationPassed) {
                        $PythonExePath = Read-Host "Please specify a valid path to python.exe (or press Enter to cancel)"
                        if (-not $PythonExePath) {
                            Write-Host "Operation canceled by the user."
                            return
                        }
                    }
                } while (-not $validationPassed)
            } else {
                $searchUrl = "https://www.python.org/search/?q=$($Version)&submit="
                Write-Host "You can download Python from: $searchUrl"
            }
            return
        }
    }

    if ($PythonExePath) {
        $versionsList.Add([PSCustomObject]@{Version=$Version; Path=$PythonExePath})
        $versionsList | ConvertTo-Json | Set-Content $jsonPath -Force
    }

    if (-not $PythonExePath) {
        Write-Host "Python executable path was not provided; created the virtual environment with default configuration."
        & $global:PythonExePath -m venv $VenvPath
    } else {
        Write-Host "Created the virtual environment at $($VenvPath) using Python $($Version) at $($PythonExePath)."
        & $PythonExePath -m venv $VenvPath
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
        Write-Host "Virtual environment removed successfully at '$VenvPath'."
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

function Get-Help {
    param([string]$VenvsHelpFile)
    if (Test-Path $VenvsHelpFile) {
        Get-Content $VenvsHelpFile
    } else {
        Write-Host "Help file not found."
    }
}