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

    if (-Not $PSBoundParameters.ContainsKey('ProjectName')) {
        $ProjectName = $RepositoryPath | Split-Path -Leaf
    }
}

process {
    # Check that environment variable that container API key is present.
    if (Test-Path -Path $Env:ApiKeyEnvironmentVariableName) {
        $ApiKey = (Get-Item -Path $Env:ApiKeyEnvironmentVariableName).Value

        Push-Location -Path $RepositoryPath

        # Get current version from the project file.
        $ProjectFileName = "$ProjectName.csproj"
        $ProjectFilePath = "$RepositoryPath/Source/$ProjectName/$ProjectFileName"
        $ProjectOutputDirectory = "$RepositoryPath/Source/$ProjectName/bin/$Configuration"

        $ProjectFileXml = [xml](Get-Content -Path $ProjectFilePath)
        $PackageVersion = $ProjectFileXml.Project.PropertyGroup.Version

        # Pack a NuGet package and publish it.
        Write-Host -Object "Publishing version $PackageVersion" -ForegroundColor Magenta

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
        Write-Host -Object "Environment variable '$ApiKeyEnvironmentVariableName' is not found" -ForegroundColor Red
    }
}