# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
  This is the main build script definition. Tasks are defined below.

  To override or change any configuration values, modify the settings.ps1 file.
#>


Include settings.ps1

Task Use-QDKEnvironment -alias "qdk" -Description "Selects the qdk conda environment" {
    # ./build.sh -t init -properties "@{PackageDirs=@('qdk');EnvNames=@('qdk')}"
    $script:PackageDirs = @("qdk")
    $script:EnvNames = @("qdk")
}

Task Use-AzureQuantumEnvironment -alias "azurequantum" -Description "Selects the azurequantum conda environment" {
    # ./build.sh -t init -properties "@{PackageDirs=@('azure-quantum');EnvNames=@('azurequantum')}"
    $script:PackageDirs = @("azure-quantum")
    $script:EnvNames = @("azurequantum")
}

Task default -Depends Init, Build, Pack, Test

Task Init -Depends Set-EnvironmentVariables -Description "Loads conda utils and adjusts properties to defaults. Ensures config state is valid" {
    Import-Module (Join-Path $buildPath "conda-utils.psm1")
    
    if ($PackageDirs.Length -eq 0) {
        $script:PackageDirs = Get-ChildItem -Path $rootPath -Recurse -Filter "environment.yml" | Select-Object -ExpandProperty Directory | Split-Path -Leaf
        Write-Host "##[info]No PackageDir. Setting to default '$PackageDirs'"
    }
      
    if ($EnvNames.Length -eq 0) {
        $script:EnvNames = $PackageDirs | ForEach-Object { $_.replace("-", "") }
        Write-Host "##[info]No EnvNames. Setting to default '$EnvNames'"
    }
      
    # Check that input is valid
    if ($EnvNames.length -ne $PackageDirs.length) {
        throw "Cannot run build script: '$EnvNames' and '$PackageDirs' lengths don't match"
    }
}

Task Build -Depends Init {
    if ($Env:ENABLE_PYTHON -eq "false") {
        Write-Host "##vso[task.logissue type=warning;]Skipping installing Python packages. Env:ENABLE_PYTHON was set to 'false'."
    }
    else {
        for ($i = 0; $i -le $PackageDirs.length - 1; $i++) {
            $targetEnv = $EnvNames[$i]
            $targetPackageDir = $PackageDirs[$i]
            Write-Host "##[info]Installing '$targetEnv'"
            Install-Package -EnvName $targetEnv -PackageDir $targetPackageDir -ParentPath $rootPath
        }
    }
}

Task Test -Depends Init {
    if ($Env:ENABLE_PYTHON -eq "false") {
        Write-Host "##vso[task.logissue type=warning;]Skipping testing Python packages. Env:ENABLE_PYTHON was set to 'false'."
    }
    else {
        for ($i = 0; $i -le $PackageDirs.length - 1; $i++) {
            Invoke-Tests -PackageDir $PackageDirs[$i] -EnvName $EnvNames[$i] -ParentPath $rootPath
        }
    }
}

Task Bootstrap -Depends Init -Description "Installs the conda environment." {
    # Enable conda hook
    Assert (Enable-Conda) "Failed to detect conda and enable hook"
    
    foreach ($PackageDir in $PackageDirs) {
        # Check if environment already exists
        $EnvName = $PackageDir.replace("-", "")
        $EnvExists = conda env list | Select-String -Pattern "$EnvName " | Measure-Object | Select-Object -Exp Count
        # if it exists, skip creation
        if ($EnvExists -eq "1") {
            Write-Host "##[info]Skipping creating $EnvName; env already exists."
        }
        else {
            # if it doese not exist, create env
            $EnvPath = Join-Path $rootPath $PackageDir environment.yml
          
            Write-Host "##[info]Build '$EnvPath' Conda environment"
            exec -workingDirectory $rootPath { & conda env create --quiet --file $EnvPath }
        }
    }
}


Task Pack -Depends Init -Description "Create wheels for given packages in given environments, output to directory" {
    if ([String]::IsNullOrEmpty($OutDir)) {
        Write-Host "##[info]No OutDir. Setting to env var $Env:PYTHON_OUTDIR"
        $script:OutDir = $Env:PYTHON_OUTDIR
    }
  
    if ($Env:ENABLE_PYTHON -eq "false") {
        Write-Host "##vso[task.logissue type=warning;]Skipping Creating Python packages. Env:ENABLE_PYTHON was set to 'false'."
    }
    else {
        exec { & python --version }
  
        for ($i = 0; $i -le $PackageDirs.length - 1; $i++) {
            $PackageDir = Join-Path $rootPath $PackageDirs[$i]
            Write-Host "##[info]Packing Python wheel in env '$($EnvNames[$i])' for '$PackageDir' to '$OutDir'..."
            Create-Wheel -EnvName $EnvNames[$i] -Path $PackageDir -OutDir $OutDir
        }
    }
}

###############################################################################
# Helper functions
###############################################################################

function Install-Package() {
    param(
        [string] $EnvName,
        [string] $PackageDir,
        [string] $ParentPath
    )
    $AbsPackageDir = Join-Path $ParentPath $PackageDir
    Write-Host "##[info]Install package $AbsPackageDir in development mode for env $EnvName"

    # Activate env
    exec -workingDirectory $ParentPath { Use-CondaEnv $EnvName }
    # Install package
    exec -workingDirectory $ParentPath { pip install -e $AbsPackageDir }
}


function Invoke-Tests() {
    param(
        [string] $PackageDir,
        [string] $EnvName,
        [string] $ParentPath
    )
    $PkgName = $PackageDir.replace("-", ".")
    $AbsPackageDir = Join-Path $ParentPath $PackageDir
    Write-Host "##[info]Test package $AbsPackageDir and run tests for env $EnvName"
    # Activate env
    exec -workingDirectory $ParentPath { Use-CondaEnv $EnvName }
    # Install testing deps
    exec -workingDirectory $ParentPath { python -m pip install --upgrade pip }
    exec -workingDirectory $ParentPath { pip install pytest pytest-azurepipelines pytest-cov }
    # Run tests
    pytest --cov-report term --cov=$PkgName $AbsPackageDir
}

function Create-Wheel() {
    param(
        [string] $EnvName,
        [string] $Path,
        [string] $OutDir
    );
  
    # Set environment vars to be able to run conda activate
    Write-Host "##[info]Pack wheel for env '$EnvName'"
    # Activate env
    Assert (Enable-Conda) "Failed to detect conda and enable hook"
    # Create package distribution
    exec -workingDirectory $Path { & python setup.py bdist_wheel sdist --formats=gztar }
  
    if (![String]::IsNullOrEmpty($OutDir)) { 
        Write-Host "##[info]Copying wheel to '$OutDir'"
        Copy-Item "dist/*.whl" $OutDir/
        Copy-Item "dist/*.tar.gz" $OutDir/
    }
}
