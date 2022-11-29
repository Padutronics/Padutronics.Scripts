[CmdletBinding()]
param (
    [Parameter()]
    [string]$RepositoryPath,

    [Parameter()]
    [string]$ProjectName
)

begin {
    $ErrorActionPreference = 'Stop'

    # Load external scripts.
    . $PSScriptRoot/Functions/FormatJson.ps1

    # Declare constants.
    $ProjectTemplatePath = "$PSScriptRoot/Templates/Projects/NUnit/Project.csproj"
    $TestTaskTemplatePath = "$PSScriptRoot/Templates/VisualStudioCode/Tasks/test.json"

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
    Push-Location -Path $RepositoryPath

    # Create a project.
    $ProjectFilePath = "$RepositoryPath/Tests/$ProjectName.Tests/$ProjectName.Tests.csproj"

    New-Item -ItemType 'Directory' -Path '.' -Name 'Tests'
    New-Item -ItemType 'Directory' -Path 'Tests' -Name "$ProjectName.Tests"

    Get-Content -Path $ProjectTemplatePath -Raw | Set-Content -Path $ProjectFilePath -NoNewline

    $ProjectFileXml = New-Object -TypeName 'xml'
    $ProjectFileXml.PreserveWhitespace = $true
    $ProjectFileXml.Load($ProjectFilePath)

    $ProjectFileXml.Project.ItemGroup[1].ProjectReference.Include = "../../Source/$ProjectName/$ProjectName.csproj"

    $ProjectFileXml.Save($ProjectFilePath)

    $Json = Get-Content -Path '.vscode/tasks.json' -Raw | ConvertFrom-Json

    $TestTask = Get-Content -Path $TestTaskTemplatePath -Raw | ConvertFrom-Json
    $TestTask.args[1] = "$`{workspaceFolder`}/Tests/$ProjectName.Tests/$ProjectName.Tests.csproj"

    $Json.tasks += $TestTask

    ConvertTo-Json $Json -Depth 100 | Format-Json | Set-Content -Path '.vscode/tasks.json' -NoNewline

    git add .vscode/tasks.json
    git add Tests/$ProjectName`.Tests/$ProjectName`.Tests.csproj
    git commit -m "Add project $ProjectName.Tests"

    Pop-Location
}