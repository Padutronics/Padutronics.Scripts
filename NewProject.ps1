[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [string]$Description,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$ProjectDirectory,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$ProjectName,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$PackagePropertyProduct
)

begin {
    function Format-Json {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
            [string]$Json,

            [Parameter()]
            [ValidateRange(1, 1024)]
            [int]$Indentation = 4
        )

        # If the input JSON text has been created with ConvertTo-Json -Compress then we first need to reconvert it without compression.
        if ($Json -notmatch '\r?\n') {
            $Json = $Json | ConvertFrom-Json | ConvertTo-Json -Depth 100
        }

        $Indent = 0
        $RegularExpressionUnlessQuoted = '(?=([^"]*"[^"]*")*[^"]*$)'

        $Result = $Json -split '\r?\n' | ForEach-Object {
            # If the line contains a ] or } character, we need to decrement the indentation level unless it is inside quotes.
            if ($_ -match "[}\]]$RegularExpressionUnlessQuoted" -and $_ -notmatch "[\{\[]$RegularExpressionUnlessQuoted") {
                $Indent = [Math]::Max($Indent - $Indentation, 0)
            }

            # Replace all colon-space combinations by ": " unless it is inside quotes.
            $Line = (' ' * $Indent) + ($_.TrimStart() -replace ":\s+$RegularExpressionUnlessQuoted", ': ')

            # If the line contains a [ or { character, we need to increment the indentation level unless it is inside quotes.
            if ($_ -match "[\{\[]$RegularExpressionUnlessQuoted" -and $_ -notmatch "[}\]]$RegularExpressionUnlessQuoted") {
                $Indent += $Indentation
            }

            $Line
        }

        return $Result -Join [Environment]::NewLine
    }

    # Constants

    $PackagePropertyProductDefault = 'Padutronics Framework'

    $ProjectFileUrl = 'https://gist.githubusercontent.com/ppdubsky/8fa9c4222ca3043aa5ebd4d51c91a4a4/raw/542581333c4a65b62e5bec183520447f76709436/ClassLibrary.csproj'
    $GitignoreUrl = 'https://gist.githubusercontent.com/ppdubsky/d1c3f082a8a62c7fbff15e1a2b994e4e/raw/3802818f1ce85d73170250339e7bbc75aafc60a8/.gitignore-class-library'
    $EmptyTasksUrl = 'https://gist.githubusercontent.com/ppdubsky/81b3b89b25b466b173929b4521d201a5/raw/7fbf388627afac9a96c01dc757f7b1a6add9d6b7/tasks.json-empty'
    $BuildTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/210fa8919dee67999938a152267b4986/raw/0ad52a453e08145446ae3e69c1c297c7d582db90/tasks.json-build'
    $BumpVersionMajorTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/29905e34c3bec56a3354b8f86636bb67/raw/81c66d61b84e8a47ad284a4cf5806957ad0f549a/tasks.json-bump-version-major'
    $BumpVersionMinorTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/a8d486564d53731dff892b744a506307/raw/5c5b33dce24065fc1e695e28d54c51b2729a4c08/tasks.json-bump-version-minor'
    $BumpVersionPatchTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/3376dd4bb80796f42430fa8e13e20329/raw/8dfb6c1b8201233345baef221ada517a08b713da/tasks.json-bump-version-patch'
    $PublishTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/d2fae75712c806ce157ff3399ccff6cf/raw/1737f6b67a4ec4116aca278de0ca4ecbca3c70e2/tasks.json-publish'

    # Process parameters

    if ($PSBoundParameters.ContainsKey('ProjectDirectory')) {
        $ProjectDirectory = $ProjectDirectory | Resolve-Path
    } else {
        $ProjectDirectory = Get-Location
    }

    if (-not $PSBoundParameters.ContainsKey('ProjectName')) {
        $ProjectName = $ProjectDirectory | Split-Path -Leaf
    }

    if (-not $PSBoundParameters.ContainsKey('PackagePropertyProduct')) {
        $PackagePropertyProduct = $PackagePropertyProductDefault
    }
}

process {
    Push-Location $ProjectDirectory

    # Add .gitignore

    New-Item -Path . -Name '.gitignore'

    git init
    git add .gitignore
    git commit -m 'Add .gitignore'

    # Create a project

    $ProjectFilePath = "${ProjectDirectory}/Source/${ProjectName}/${ProjectName}.csproj"

    New-Item -ItemType 'Directory' -Path . -Name Source
    New-Item -ItemType 'Directory' -Path Source -Name ${ProjectName}

    Invoke-WebRequest -Uri $ProjectFileUrl -OutFile $ProjectFilePath

    $ProjectFileXml = New-Object xml
    $ProjectFileXml.PreserveWhitespace = $true
    $ProjectFileXml.Load($ProjectFilePath)

    $CurrentYear = Get-Date -Format yyyy

    $PackagePropertyDescription = $Description
    $PackagePropertyCopyright = "Copyright © Padutronics ${CurrentYear}"
    $PackagePropertyPackageProjectUrl = "https://github.com/Padutronics/${ProjectName}"
    $PackagePropertyRepositoryUrl = "https://github.com/Padutronics/${ProjectName}"

    $ProjectFileXml.Project.PropertyGroup.Product = $PackagePropertyProduct
    $ProjectFileXml.Project.PropertyGroup.Description = $PackagePropertyDescription
    $ProjectFileXml.Project.PropertyGroup.Copyright = $PackagePropertyCopyright
    $ProjectFileXml.Project.PropertyGroup.PackageProjectUrl = $PackagePropertyPackageProjectUrl
    $ProjectFileXml.Project.PropertyGroup.RepositoryUrl = $PackagePropertyRepositoryUrl

    $ProjectFileXml.Save($ProjectFilePath);

    Invoke-WebRequest -Uri $GitignoreUrl -OutFile .gitignore

    New-Item -ItemType 'Directory' -Path . -Name .vscode
    New-Item -ItemType 'File' -Path .vscode -Name tasks.json

    Invoke-WebRequest -Uri $EmptyTasksUrl -OutFile .vscode/tasks.json

    $Json = Get-Content .vscode/tasks.json | ConvertFrom-Json

    $BuildTask = Invoke-WebRequest -Uri $BuildTaskUrl | ConvertFrom-Json
    $BuildTask.args[1] = "$`{workspaceFolder`}/Source/${ProjectName}/${ProjectName}.csproj"

    $Json.tasks += $BuildTask

    ConvertTo-Json $Json -Depth 100 | Format-Json | Set-Content .vscode/tasks.json -NoNewline

    git add .
    git commit -m "Add project ${ProjectName}"
    git tag v0.0.0

    # Add Visual Studio Code tasks

    $BumpVersionMajorTask = Invoke-WebRequest -Uri $BumpVersionMajorTaskUrl | ConvertFrom-Json

    $Json.tasks += $BumpVersionMajorTask

    $BumpVersionMinorTask = Invoke-WebRequest -Uri $BumpVersionMinorTaskUrl | ConvertFrom-Json

    $Json.tasks += $BumpVersionMinorTask

    $BumpVersionPatchTask = Invoke-WebRequest -Uri $BumpVersionPatchTaskUrl | ConvertFrom-Json

    $Json.tasks += $BumpVersionPatchTask

    ConvertTo-Json $Json -Depth 100 | Format-Json | Set-Content .vscode/tasks.json -NoNewline

    git add .
    git commit -m 'Add Visual Studio Code tasks for bumping version'

    $PublishTask = Invoke-WebRequest -Uri $PublishTaskUrl | ConvertFrom-Json

    $Json.tasks += $PublishTask

    ConvertTo-Json $Json -Depth 100 | Format-Json | Set-Content .vscode/tasks.json -NoNewline

    git add .
    git commit -m 'Add Visual Studio Code task for publishing NuGet package'

    # Create GitHub project

    gh repo create Padutronics/$ProjectName --public

    git remote add origin git@github.com:Padutronics/$ProjectName.git

    # Setup git branches

    git branch develop main
    git push --set-upstream origin main
    git push --set-upstream origin develop
    git push --tags

    Pop-Location
}