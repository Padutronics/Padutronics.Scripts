[CmdletBinding()]
param (
    [Parameter()]
    [string]$RepositoryPath,

    [Parameter()]
    [string]$ProjectName
)

begin {
    $ErrorActionPreference = 'Stop'

    . $PSScriptRoot/Functions/FormatJson.ps1

    # Constants

    $ProjectFileUrl = 'https://gist.githubusercontent.com/ppdubsky/6867337bc7af2c0f9445cf300db92de9/raw/3a445d501a41d8b586be7a3ab4d9de1d176bca2b/NUnit.csproj'
    $TestTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/0a1665117d7d17f4539dfe4f883c8ffc/raw/ecc6e5d7d0ab9fcc16128e889f6d065e8c4975c9/tasks.json-test'

    # Process parameters

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
    Push-Location -Path $RepositoryPath

    # Create a project

    $ProjectFilePath = "$RepositoryPath/Tests/$ProjectName.Tests/$ProjectName.Tests.csproj"

    New-Item -ItemType 'Directory' -Path '.' -Name 'Tests'
    New-Item -ItemType 'Directory' -Path 'Tests' -Name "$ProjectName.Tests"

    Invoke-WebRequest -Uri $ProjectFileUrl -OutFile $ProjectFilePath

    $ProjectFileXml = New-Object -TypeName 'xml'
    $ProjectFileXml.PreserveWhitespace = $true
    $ProjectFileXml.Load($ProjectFilePath)

    $ProjectFileXml.Project.ItemGroup[1].ProjectReference.Include = "../../Source/$ProjectName/$ProjectName.csproj"

    $ProjectFileXml.Save($ProjectFilePath)

    $Json = Get-Content -Path '.vscode/tasks.json' | ConvertFrom-Json

    $TestTask = Invoke-WebRequest -Uri $TestTaskUrl | ConvertFrom-Json
    $TestTask.args[1] = "$`{workspaceFolder`}/Tests/$ProjectName.Tests/$ProjectName.Tests.csproj"

    $Json.tasks += $TestTask

    ConvertTo-Json $Json -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

    git add .vscode/tasks.json
    git add Tests/$ProjectName`.Tests/$ProjectName`.Tests.csproj
    git commit -m "Add project $ProjectName.Tests"

    Pop-Location
}