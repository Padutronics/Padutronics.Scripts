[CmdletBinding()]
param (
    [Parameter()]
    [string]$ProjectDirectory,

    [Parameter()]
    [string]$ProjectName
)

begin {
    $ErrorActionPreference = "Stop"

    # Declare constants.
    $ApiKeyEnvironmentVariableName = 'PadutronicsPushPackageApiKey'
    $Configuration = 'Debug'
    $SourceName = 'Padutronics'

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

        dotnet pack $ProjectFilePath --configuration $Configuration --include-source --include-symbols --output $ProjectOutputDirectory
        dotnet nuget push "$ProjectOutputDirectory/$ProjectName.$PackageVersion.symbols.nupkg" --api-key $ApiKey --source $SourceName
    } else {
        Write-Host "Environment variable '$ApiKeyEnvironmentVariableName' is not found" -ForegroundColor Red
    }
}