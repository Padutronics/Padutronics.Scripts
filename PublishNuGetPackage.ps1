[CmdletBinding()]
param ()

begin {
    $PadutronicsPushPackageApiKeyName = 'PadutronicsPushPackageApiKey'

    $Configuration = 'Debug'
    $SourceName = 'Padutronics'

    $CurrentDirectory = Get-Location
    $ProjectName = Split-Path $CurrentDirectory -Leaf

    $OutputDirectory = 'bin'
    $ProjectDirectory = "$CurrentDirectory/Source/$ProjectName"
    $ProjectFile = "$ProjectName.csproj"
}

process {
    if (Test-Path env:$PadutronicsPushPackageApiKeyName) {
        $ApiKey = (Get-Item env:$PadutronicsPushPackageApiKeyName).Value

        Push-Location $ProjectDirectory

        $ProjectFileXml = [xml](Get-Content $ProjectFile)
        $PackageVersion = $ProjectFileXml.Project.PropertyGroup.Version

        Write-Host "Publishing version $PackageVersion" -ForegroundColor Magenta

        dotnet pack $ProjectFile --configuration $Configuration --include-source --include-symbols --output "$OutputDirectory/$Configuration"

        dotnet nuget push "$OutputDirectory/$Configuration/$ProjectName.$PackageVersion.symbols.nupkg" --api-key $ApiKey --source $SourceName

        Pop-Location
    } else {
        Write-Host "Environment variable '$PadutronicsPushPackageApiKeyName' is not found" -ForegroundColor Red
    }
}