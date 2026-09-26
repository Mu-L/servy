<#
.SYNOPSIS
    Provides dynamic tool path resolution utilities for Servy build and release scripts.

.DESCRIPTION
    Dot-sourced configuration script defining helper functions for locating build tools,
    compilers, and signing utilities across system environments and fallback paths.
#>

function Resolve-Tool {
    <#
        .SYNOPSIS
            Resolves the full path of a required executable or tool.

        .DESCRIPTION
            Checks for the tool path in the following order of priority:
            1. Environment variable (SERVY_TOOL_<Name>)
            2. System PATH (via Get-Command)
            3. Provided fallback paths

        .PARAMETER Name
            The name of the tool to resolve (e.g., 'signtool', 'iscc').

        .PARAMETER Fallbacks
            An array of file paths to check if the tool is not found in the environment or PATH.

        .EXAMPLE
            Resolve-Tool -Name "SignTool" -Fallbacks @("C:\Program Files (x86)\...\signtool.exe")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [string[]]$Fallbacks
    )

    # 1. Check dynamic Environment Variable
    # Use Get-Item because $env:SERVY_TOOL_$Name is not valid syntax.
    $envVarName = "SERVY_TOOL_$Name"
    $envPath = (Get-Item -LiteralPath "env:$envVarName" -ErrorAction SilentlyContinue).Value
    if ($envPath -and (Test-Path -LiteralPath $envPath -PathType Leaf)) {
        Write-Verbose "Resolved '$Name' to '$envPath' via environment variable $envVarName."
        return $envPath
    }
    if ($envPath) {
        Write-Warning "$envVarName is set to '$envPath' but the file does not exist; ignoring."
    }

    # 2. Check System PATH (Application only - avoid alias/function/script shadowing)
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
        Write-Verbose "Resolved '$Name' to '$($cmd.Source)' via PATH."
        return $cmd.Source   # Source is the canonical path property for Application commands
    }

    # 3. Check Fallbacks
    if ($Fallbacks) {
        foreach ($p in $Fallbacks) {
            if (Test-Path -LiteralPath $p -PathType Leaf) {
                Write-Verbose "Resolved '$Name' to '$p' via fallback path."
                return $p
            }
        }
    }

    $searched = if ($Fallbacks) { " Searched PATH and: $($Fallbacks -join '; ')." } else { " Searched PATH." }
    throw "Required tool '$Name' not found.$searched Install it or set the '$envVarName' environment variable."
}
