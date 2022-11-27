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
    $PadutronicsPushPackageApiKeyName = 'PadutronicsPushPackageApiKey'
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
    if (Test-Path env:$PadutronicsPushPackageApiKeyName) {
        $ApiKey = (Get-Item env:$PadutronicsPushPackageApiKeyName).Value

        $ProjectFileName = "$ProjectName.csproj"
        $ProjectFilePath = "$ProjectDirectory/Source/$ProjectName/$ProjectFileName"
        $ProjectOutputDirectory = "$ProjectDirectory/Source/$ProjectName/bin/$Configuration"

        $ProjectFileXml = [xml](Get-Content $ProjectFilePath)
        $PackageVersion = $ProjectFileXml.Project.PropertyGroup.Version

        Write-Host "Publishing version $PackageVersion" -ForegroundColor Magenta

        dotnet pack $ProjectFilePath --configuration $Configuration --include-source --include-symbols --output $ProjectOutputDirectory
        dotnet nuget push "$ProjectOutputDirectory/$ProjectName.$PackageVersion.symbols.nupkg" --api-key $ApiKey --source $SourceName
    } else {
        Write-Host "Environment variable '$PadutronicsPushPackageApiKeyName' is not found" -ForegroundColor Red
    }
}