[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [string]$Description,

    [Parameter()]
    [string]$RepositoryPath,

    [Parameter()]
    [string]$ProjectName,

    [Parameter()]
    [string]$PackagePropertyProduct = 'Padutronics Framework'
)

begin {
    $ErrorActionPreference = 'Stop'

    # Load external scripts.
    . $PSScriptRoot/Functions/FormatJson.ps1

    # Declare constants.
    $GitHubTokenName = 'GH_TOKEN'

    $ProjectFileUrl = 'https://gist.githubusercontent.com/ppdubsky/8fa9c4222ca3043aa5ebd4d51c91a4a4/raw/542581333c4a65b62e5bec183520447f76709436/ClassLibrary.csproj'
    $GitignoreUrl = 'https://gist.githubusercontent.com/ppdubsky/d1c3f082a8a62c7fbff15e1a2b994e4e/raw/3802818f1ce85d73170250339e7bbc75aafc60a8/.gitignore-class-library'
    $EmptyTasksUrl = 'https://gist.githubusercontent.com/ppdubsky/81b3b89b25b466b173929b4521d201a5/raw/7fbf388627afac9a96c01dc757f7b1a6add9d6b7/tasks.json-empty'
    $BuildTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/210fa8919dee67999938a152267b4986/raw/0ad52a453e08145446ae3e69c1c297c7d582db90/tasks.json-build'
    $BumpVersionMajorTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/29905e34c3bec56a3354b8f86636bb67/raw/81c66d61b84e8a47ad284a4cf5806957ad0f549a/tasks.json-bump-version-major'
    $BumpVersionMinorTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/a8d486564d53731dff892b744a506307/raw/5c5b33dce24065fc1e695e28d54c51b2729a4c08/tasks.json-bump-version-minor'
    $BumpVersionPatchTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/3376dd4bb80796f42430fa8e13e20329/raw/8dfb6c1b8201233345baef221ada517a08b713da/tasks.json-bump-version-patch'
    $PublishTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/d2fae75712c806ce157ff3399ccff6cf/raw/1737f6b67a4ec4116aca278de0ca4ecbca3c70e2/tasks.json-publish'

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
    if (Test-Path -Path "Env:$GitHubTokenName") {
        Push-Location -Path $RepositoryPath

        # Add .gitignore.
        New-Item -ItemType 'File' -Path '.' -Name '.gitignore'

        git init
        git add .gitignore
        git commit -m 'Add .gitignore'

        # Create a project.
        $ProjectFilePath = "$RepositoryPath/Source/$ProjectName/$ProjectName.csproj"

        New-Item -ItemType 'Directory' -Path '.' -Name 'Source'
        New-Item -ItemType 'Directory' -Path 'Source' -Name $ProjectName

        Invoke-WebRequest -Uri $ProjectFileUrl -OutFile $ProjectFilePath

        $ProjectFileXml = New-Object -TypeName 'xml'
        $ProjectFileXml.PreserveWhitespace = $true
        $ProjectFileXml.Load($ProjectFilePath)

        $CurrentYear = Get-Date -Format 'yyyy'

        $PackagePropertyDescription = $Description
        $PackagePropertyCopyright = "Copyright © Padutronics $CurrentYear"
        $PackagePropertyPackageProjectUrl = "https://github.com/Padutronics/$ProjectName"
        $PackagePropertyRepositoryUrl = "https://github.com/Padutronics/$ProjectName"

        $ProjectFileXml.Project.PropertyGroup.Product = $PackagePropertyProduct
        $ProjectFileXml.Project.PropertyGroup.Description = $PackagePropertyDescription
        $ProjectFileXml.Project.PropertyGroup.Copyright = $PackagePropertyCopyright
        $ProjectFileXml.Project.PropertyGroup.PackageProjectUrl = $PackagePropertyPackageProjectUrl
        $ProjectFileXml.Project.PropertyGroup.RepositoryUrl = $PackagePropertyRepositoryUrl

        $ProjectFileXml.Save($ProjectFilePath)

        Invoke-WebRequest -Uri $GitignoreUrl -OutFile '.gitignore'

        New-Item -ItemType 'Directory' -Path '.' -Name '.vscode'
        New-Item -ItemType 'File' -Path '.vscode' -Name 'tasks.json'

        Invoke-WebRequest -Uri $EmptyTasksUrl -OutFile '.vscode/tasks.json'

        $TasksJson = Get-Content -Path '.vscode/tasks.json' | ConvertFrom-Json

        $BuildTaskJson = Invoke-WebRequest -Uri $BuildTaskUrl | ConvertFrom-Json
        $BuildTaskJson.args[1] = "$`{workspaceFolder`}/Source/$ProjectName/$ProjectName.csproj"

        $TasksJson.tasks += $BuildTaskJson

        ConvertTo-Json $TasksJson -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

        git add .
        git commit -m "Add project $ProjectName"
        git tag v0.0.0

        # Add Visual Studio Code tasks.
        $BumpVersionMajorTaskJson = Invoke-WebRequest -Uri $BumpVersionMajorTaskUrl | ConvertFrom-Json

        $TasksJson.tasks += $BumpVersionMajorTaskJson

        $BumpVersionMinorTaskJson = Invoke-WebRequest -Uri $BumpVersionMinorTaskUrl | ConvertFrom-Json

        $TasksJson.tasks += $BumpVersionMinorTaskJson

        $BumpVersionPatchTaskJson = Invoke-WebRequest -Uri $BumpVersionPatchTaskUrl | ConvertFrom-Json

        $TasksJson.tasks += $BumpVersionPatchTaskJson

        ConvertTo-Json $TasksJson -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

        git add .
        git commit -m 'Add Visual Studio Code tasks for bumping version'

        $PublishTaskJson = Invoke-WebRequest -Uri $PublishTaskUrl | ConvertFrom-Json

        $TasksJson.tasks += $PublishTaskJson

        ConvertTo-Json $TasksJson -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

        git add .
        git commit -m 'Add Visual Studio Code task for publishing NuGet package'

        # Create a GitHub project.
        gh repo create Padutronics/$ProjectName --public

        git remote add origin git@github.com:Padutronics/$ProjectName.git

        # Setup git branches.
        git branch develop main
        git push --set-upstream origin main
        git push --set-upstream origin develop
        git push --tags

        git checkout develop

        Pop-Location
    }
    else {
        Write-Host -Object "Environment variable '$GitHubTokenName' is not found" -ForegroundColor Red
    }
}