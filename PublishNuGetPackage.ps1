[CmdletBinding()]
param (
    [Parameter()]
    [string]$ProjectDirectory,

    [Parameter()]
    [string]$ProjectName,

    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [string]$Source = 'Padutronics'
)

begin {
    $ErrorActionPreference = "Stop"

    # Declare constants.
    $ApiKeyEnvironmentVariableName = 'PadutronicsPushPackageApiKey'

    # Process parameters.
    if ($PSBoundParameters.ContainsKey('ProjectDirectory')) {
        $ProjectDirectory = $ProjectDirectory | Resolve-Path
    } else {
        $ProjectDirectory = Get-Location
    }

    if (-not $PSBoundParameters.ContainsKey('ProjectName')) {
        $ProjectName = $ProjectDirectory | Split-Path -Leaf
    }
}

process {
    # Check that environment variable that container API key is present.
    if (Test-Path env:$ApiKeyEnvironmentVariableName) {
        $ApiKey = (Get-Item env:$ApiKeyEnvironmentVariableName).Value

        # Get current version from the project file.
        $ProjectFileName = "$ProjectName.csproj"
        $ProjectFilePath = "$ProjectDirectory/Source/$ProjectName/$ProjectFileName"
        $ProjectOutputDirectory = "$ProjectDirectory/Source/$ProjectName/bin/$Configuration"

        $ProjectFileXml = [xml](Get-Content $ProjectFilePath)
        $PackageVersion = $ProjectFileXml.Project.PropertyGroup.Version

        # Pack a NuGet package and publish it.
        Write-Host "Publishing version $PackageVersion" -ForegroundColor Magenta

        switch ($Configuration) {
            'Debug' {
                $IncludeSourceOption = '--include-source'
                $IncludeSymbolsOption = '--include-symbols'
                $PackageName = "$ProjectName.$PackageVersion.symbols.nupkg"
            }
            'Release' {
                $IncludeSourceOption = ''
                $IncludeSymbolsOption = ''
                $PackageName = "$ProjectName.$PackageVersion.nupkg"
            }
        }

        dotnet pack $ProjectFilePath --configuration $Configuration --output $ProjectOutputDirectory $IncludeSourceOption $IncludeSymbolsOption
        dotnet nuget push "$ProjectOutputDirectory/$PackageName" --api-key $ApiKey --source $Source
    } else {
        Write-Host "Environment variable '$ApiKeyEnvironmentVariableName' is not found" -ForegroundColor Red
    }
}