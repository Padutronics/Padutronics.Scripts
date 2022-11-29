[CmdletBinding()]
param (
    [Parameter()]
    [string]$RepositoryPath,

    [Parameter()]
    [string]$ProjectName,

    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [string]$Source = 'Padutronics',

    [Parameter()]
    [string]$ApiKeyEnvironmentVariableName = 'PadutronicsPushPackageApiKey'
)

begin {
    $ErrorActionPreference = 'Stop'

    # Process parameters.
    if ($PSBoundParameters.ContainsKey('RepositoryPath')) {
        $RepositoryPath = $RepositoryPath | Resolve-Path
    }
    else {
        $RepositoryPath = Get-Location
    }

    if (-not $PSBoundParameters.ContainsKey('ProjectName')) {
        $ProjectName = $RepositoryPath | Split-Path -Leaf
    }
}

process {
    # Check that environment variable that container API key is present.
    if (Test-Path env:$ApiKeyEnvironmentVariableName) {
        $ApiKey = (Get-Item env:$ApiKeyEnvironmentVariableName).Value

        Push-Location $RepositoryPath

        # Get current version from the project file.
        $ProjectFileName = "$ProjectName.csproj"
        $ProjectFilePath = "$RepositoryPath/Source/$ProjectName/$ProjectFileName"
        $ProjectOutputDirectory = "$RepositoryPath/Source/$ProjectName/bin/$Configuration"

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

        Pop-Location
    }
    else {
        Write-Host "Environment variable '$ApiKeyEnvironmentVariableName' is not found" -ForegroundColor Red
    }
}