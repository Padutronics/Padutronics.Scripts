[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$Kind,

    [Parameter()]
    [string]$ProjectDirectory,

    [Parameter()]
    [string]$ProjectName
)

begin {
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
    # Modify version property in project file.
    $ProjectFilePath = "$ProjectDirectory/Source/$ProjectName/$ProjectName.csproj"

    $ProjectFileXml = New-Object xml
    $ProjectFileXml.PreserveWhitespace = $true
    $ProjectFileXml.Load($ProjectFilePath)

    $CurrentPackageVersion = $ProjectFileXml.Project.PropertyGroup.Version

    $VersionNumberMajor, $VersionNumberMinor, $VersionNumberPatch = $CurrentPackageVersion.Split('.')

    switch ($Kind) {
        'Major' {
            $VersionNumberMajor = [int]$VersionNumberMajor + 1;
            $VersionNumberMinor = 0
            $VersionNumberPatch = 0
        }
        'Minor' {
            $VersionNumberMinor = [int]$VersionNumberMinor + 1;
            $VersionNumberPatch = 0
        }
        'Patch' {
            $VersionNumberPatch = [int]$VersionNumberPatch + 1;
        }
    }

    $NewPackageVersion = "$VersionNumberMajor.$VersionNumberMinor.$VersionNumberPatch"

    $ProjectFileXml.Project.PropertyGroup.Version = $NewPackageVersion
    $ProjectFileXml.Save($ProjectFilePath);

    # Commit changes, add git tag for the new version, and rebase main branch to include the new version.
    git add "*$ProjectFileName"
    git commit -m "Bump version to $NewPackageVersion"
    git tag "v$NewPackageVersion"
    git checkout main
    git rebase develop
    git checkout -

    # Write output.
    Write-Host 'Bumped version from ' -NoNewline
    Write-Host $CurrentPackageVersion -ForegroundColor Yellow -NoNewline
    Write-Host ' to ' -NoNewline
    Write-Host $NewPackageVersion -ForegroundColor Green
}