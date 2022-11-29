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

    $ProjectTemplatePath = "$PSScriptRoot/Templates/Projects/ClassLibrary/Project.csproj"
    $GitIgnoreTemplatePath = "$PSScriptRoot/Templates/Projects/ClassLibrary/.gitignore"
    $EmptyTaskTemplatePath = "$PSScriptRoot/Templates/VisualStudioCode/Tasks/empty.json"
    $BuildTaskTemplatePath = "$PSScriptRoot/Templates/VisualStudioCode/Tasks/build.json"
    $BumpVersionMajorTaskTemplatePath = "$PSScriptRoot/Templates/VisualStudioCode/Tasks/bump-version-major.json"
    $BumpVersionMinorTaskTemplatePath = "$PSScriptRoot/Templates/VisualStudioCode/Tasks/bump-version-minor.json"
    $BumpVersionPatchTaskTemplatePath = "$PSScriptRoot/Templates/VisualStudioCode/Tasks/bump-version-patch.json"
    $PublishTaskTemplatePath = "$PSScriptRoot/Templates/VisualStudioCode/Tasks/publish.json"

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

        Get-Content -Path $ProjectTemplatePath -Raw | Set-Content -Path $ProjectFilePath -NoNewline

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

        Get-Content -Path $GitIgnoreTemplatePath -Raw | Set-Content -Path '.gitignore' -NoNewline

        New-Item -ItemType 'Directory' -Path '.' -Name '.vscode'
        New-Item -ItemType 'File' -Path '.vscode' -Name 'tasks.json'

        Get-Content -Path $EmptyTaskTemplatePath -Raw | Set-Content -Path '.vscode/tasks.json'

        $TasksJson = Get-Content -Path '.vscode/tasks.json' -Raw | ConvertFrom-Json

        $BuildTaskJson = Get-Content -Path $BuildTaskTemplatePath -Raw | ConvertFrom-Json
        $BuildTaskJson.args[1] = "$`{workspaceFolder`}/Source/$ProjectName/$ProjectName.csproj"

        $TasksJson.tasks += $BuildTaskJson

        ConvertTo-Json $TasksJson -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

        git add .
        git commit -m "Add project $ProjectName"
        git tag v0.0.0

        # Add Visual Studio Code tasks.
        $BumpVersionMajorTaskJson = Get-Content -Path $BumpVersionMajorTaskTemplatePath -Raw | ConvertFrom-Json

        $TasksJson.tasks += $BumpVersionMajorTaskJson

        $BumpVersionMinorTaskJson = Get-Content -Path $BumpVersionMinorTaskTemplatePath -Raw | ConvertFrom-Json

        $TasksJson.tasks += $BumpVersionMinorTaskJson

        $BumpVersionPatchTaskJson = Get-Content -Path $BumpVersionPatchTaskTemplatePath -Raw | ConvertFrom-Json

        $TasksJson.tasks += $BumpVersionPatchTaskJson

        ConvertTo-Json $TasksJson -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

        git add .
        git commit -m 'Add Visual Studio Code tasks for bumping version'

        $PublishTaskJson = Get-Content -Path $PublishTaskTemplatePath -Raw | ConvertFrom-Json

        $TasksJson.tasks += $PublishTaskJson

        ConvertTo-Json $TasksJson -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

        git add .
        git commit -m 'Add Visual Studio Code task for publishing NuGet package'

        # Create a GitHub project.
        #gh repo create Padutronics/$ProjectName --public

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