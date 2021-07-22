properties {
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    [string[]] $PackageDirs = @()
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    [string[]] $EnvNames = @()
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $rootPath = Resolve-Path (Split-Path -parent $PSScriptRoot)
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $buildPath = Resolve-Path (Join-Path $rootPath build)
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    $OutDir = ""
}

Task Set-EnvironmentVariables -Description "Sets up build environment variables" {
    If ($Env:BUILD_BUILDNUMBER -eq $null) { $Env:BUILD_BUILDNUMBER = "0.0.1.0" }
    If ($Env:BUILD_CONFIGURATION -eq $null) { $Env:BUILD_CONFIGURATION = "Debug"}
    If ($Env:BUILD_VERBOSITY -eq $null) { $Env:BUILD_VERBOSITY = "m"}
    If ($Env:ASSEMBLY_VERSION -eq $null) { $Env:ASSEMBLY_VERSION = "$Env:BUILD_BUILDNUMBER"}
    If ($Env:PYTHON_VERSION -eq $null) { $Env:PYTHON_VERSION = "${Env:ASSEMBLY_VERSION}a1" }
    
    If ($Env:DROPS_DIR -eq $null) { $Env:DROPS_DIR =  [IO.Path]::GetFullPath((Join-Path $rootPath "drops")) }
    
    If ($Env:PYTHON_OUTDIR -eq $null) { $Env:PYTHON_OUTDIR =  (Join-Path $Env:DROPS_DIR "wheels") }
    If (-not (Test-Path -Path $Env:PYTHON_OUTDIR)) { [IO.Directory]::CreateDirectory($Env:PYTHON_OUTDIR) }
    
    If ($Env:ENABLE_PYTHON -eq $null) { $Env:ENABLE_PYTHON =  "true" }    
}