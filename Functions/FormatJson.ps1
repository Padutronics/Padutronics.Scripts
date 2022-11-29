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
    if ($Json -NotMatch '\r?\n') {
        $Json = $Json | ConvertFrom-Json | ConvertTo-Json -Depth 100
    }

    $Indent = 0
    $RegularExpressionUnlessQuoted = '(?=([^"]*"[^"]*")*[^"]*$)'

    $Lines = $Json -Split '\r?\n' | ForEach-Object {
        # If the line contains a ] or } character, we need to decrement the indentation level unless it is inside quotes.
        if ($_ -Match "[}\]]$RegularExpressionUnlessQuoted" -And $_ -NotMatch "[\{\[]$RegularExpressionUnlessQuoted") {
            $Indent = [Math]::Max($Indent - $Indentation, 0)
        }

        # Replace all colon-space combinations by ": " unless it is inside quotes.
        $Line = (' ' * $Indent) + ($_.TrimStart() -Replace ":\s+$RegularExpressionUnlessQuoted", ': ')

        # If the line contains a [ or { character, we need to increment the indentation level unless it is inside quotes.
        if ($_ -Match "[\{\[]$RegularExpressionUnlessQuoted" -And $_ -NotMatch "[}\]]$RegularExpressionUnlessQuoted") {
            $Indent += $Indentation
        }

        $Line
    }

    return $Lines -Join [Environment]::NewLine
}