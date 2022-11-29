[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateSet('Major', 'Minor', 'Patch')]
    [string]$Kind,

    [Parameter()]
    [string]$RepositoryPath,

    [Parameter()]
    [string]$ProjectName,

    [Parameter()]
    [string]$BumpBranch = 'develop'
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
    # Check that version bump is allowed for the current git branch.
    $CurrentBranch = git branch --show-current
    if ($CurrentBranch -Eq $BumpBranch) {
        # Check whether there are uncommitted changes on the current branch.
        $HasUncommittedChanges = git status --porcelain
        if (-not $HasUncommittedChanges) {
            Push-Location -Path $RepositoryPath

            # Modify version property in project file.
            $ProjectFileName = "$ProjectName.csproj"
            $ProjectFilePath = "$RepositoryPath/Source/$ProjectName/$ProjectFileName"

            $ProjectFileXml = New-Object -TypeName 'xml'
            $ProjectFileXml.PreserveWhitespace = $true
            $ProjectFileXml.Load($ProjectFilePath)

            $CurrentPackageVersion = $ProjectFileXml.Project.PropertyGroup.Version

            $VersionNumberMajor, $VersionNumberMinor, $VersionNumberPatch = $CurrentPackageVersion.Split('.')

            switch ($Kind) {
                'Major' {
                    $VersionNumberMajor = [int]$VersionNumberMajor + 1
                    $VersionNumberMinor = 0
                    $VersionNumberPatch = 0
                }
                'Minor' {
                    $VersionNumberMinor = [int]$VersionNumberMinor + 1
                    $VersionNumberPatch = 0
                }
                'Patch' {
                    $VersionNumberPatch = [int]$VersionNumberPatch + 1
                }
            }

            $NewPackageVersion = "$VersionNumberMajor.$VersionNumberMinor.$VersionNumberPatch"

            $ProjectFileXml.Project.PropertyGroup.Version = $NewPackageVersion
            $ProjectFileXml.Save($ProjectFilePath)

            # Commit changes, add git tag for the new version, and rebase main branch to include the new version.
            git add "*$ProjectFileName"
            git commit -m "Bump version to $NewPackageVersion"

            git tag "v$NewPackageVersion"

            git checkout main
            git rebase $BumpBranch
            git checkout $BumpBranch

            # Write output.
            Write-Host -Object 'Bumped version from ' -NoNewline
            Write-Host -Object $CurrentPackageVersion -ForegroundColor Yellow -NoNewline
            Write-Host -Object ' to ' -NoNewline
            Write-Host -Object $NewPackageVersion -ForegroundColor Green

            Pop-Location
        }
        else {
            Write-Host -Object 'There are uncommitted changes on the current branch' -ForegroundColor Red
        }
    }
    else {
        Write-Host -Object 'Bumping version is allowed only on ' -ForegroundColor Red -NoNewline
        Write-Host -Object $BumpBranch -ForegroundColor Magenta -NoNewline
        Write-Host -Object ' branch and current branch is ' -ForegroundColor Red -NoNewline
        Write-Host -Object $CurrentBranch -ForegroundColor Magenta
    }
}