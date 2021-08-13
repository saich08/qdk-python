#!/usr/bin/env pwsh

pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& '$(Join-Path $pwd build build.ps1)' $args"
exit $LASTEXITCODE