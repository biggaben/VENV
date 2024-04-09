function Global:Venv-Create {
    param(
        [string]$VenvPath,
        [string]$Version,
        [string]$PythonExePath
    )

    $jsonPath = Join-Path -Path "C:\Users\David\PowerShellProfile\Modules\VENV" -ChildPath "PythonVersions.json"

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
