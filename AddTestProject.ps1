[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$ProjectDirectory,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$ProjectName
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

    $ProjectFileUrl = 'https://gist.githubusercontent.com/ppdubsky/6867337bc7af2c0f9445cf300db92de9/raw/3a445d501a41d8b586be7a3ab4d9de1d176bca2b/NUnit.csproj'
    $TestTaskUrl = 'https://gist.githubusercontent.com/ppdubsky/0a1665117d7d17f4539dfe4f883c8ffc/raw/ecc6e5d7d0ab9fcc16128e889f6d065e8c4975c9/tasks.json-test'

    # Process parameters

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
    Push-Location $ProjectDirectory

    # Create a project

    $ProjectFilePath = "${ProjectDirectory}/Tests/${ProjectName}.Tests/${ProjectName}.Tests.csproj"

    New-Item -ItemType 'Directory' -Path . -Name Tests
    New-Item -ItemType 'Directory' -Path Tests -Name "${ProjectName}.Tests"

    Invoke-WebRequest -Uri $ProjectFileUrl -OutFile $ProjectFilePath

    $ProjectFileXml = New-Object xml
    $ProjectFileXml.PreserveWhitespace = $true
    $ProjectFileXml.Load($ProjectFilePath)

    $ProjectFileXml.Project.ItemGroup[1].ProjectReference.Include = "../../Source/${ProjectName}/${ProjectName}.csproj"

    $ProjectFileXml.Save($ProjectFilePath);$Json = Get-Content .vscode/tasks.json | ConvertFrom-Json

    $TestTask = Invoke-WebRequest -Uri $TestTaskUrl | ConvertFrom-Json
    $TestTask.args[1] = "$`{workspaceFolder`}/Tests/${ProjectName}.Tests/${ProjectName}.Tests.csproj"

    $Json.tasks += $TestTask

    ConvertTo-Json $Json -Depth 100 | Format-Json | Set-Content .vscode/tasks.json -NoNewline

    git add .vscode/tasks.json
    git add Tests/$ProjectName`.Tests/$ProjectName`.Tests.csproj
    git commit -m "Add project ${ProjectName}.Tests"

    Pop-Location
}