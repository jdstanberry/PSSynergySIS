<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    C:\PS>
    Example of how to use this cmdlet
.EXAMPLE
    C:\PS>
    Another example of how to use this cmdlet
.PARAMETER InputObject
    Specifies the object to be processed.  You can also pipe the objects to this command.
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    PSSynergySIS
#>
function Get-ReportXMLResult {
    Param
    (
        $outputFormat,
        $resultXML

    )

    $result = $resultXML.REPORTRESULT.RESULT.InnerText

    switch ($outputFormat) {
        'CSV' {
            # Synergy sometimes returns CSV files with duplicate headers
            $lineone = ($result -split '\n')[0] | ForEach-Object { $_ -replace '"', '' }
            [array]$Headers = $lineone -split ","
            For ($i = 0; $i -lt $Headers.Count; $i++) {
                if ($i -eq 0) { Continue } #Skip first column.
                # If in any previous column, give it a generic header name
                if ($Headers[0..($i - 1)] -contains $Headers[$i]) {
                    $Headers[$i] = "Header$i"
                }
            }
            $fixed = $result | ConvertFrom-Csv -Header $Headers
            # $data = $fixed | Select-Object -Skip 1
            $data = $fixed | Select-Object -Skip 1 | Where-Object { $_.PSObject.Properties.Value -ne '' }
        }
        { $_ -in 'HTML', 'RTF' }
        { $data = $result }
        { $_ -in 'PDF', 'TIFF', 'EXCEL', 'TXT' } {
            $enc0 = [System.Text.Encoding]::ASCII
            $encU = [System.Text.Encoding]::Unicode
            $b = [System.Convert]::FromBase64String($result)
            $f = $enc0.GetString( [System.Text.Encoding]::Convert($encU, $enc0, $b))
            $data = $f.Substring(1)
        }
        'XML' {
            $enc0 = [System.Text.Encoding]::ASCII
            $encU = [System.Text.Encoding]::Unicode

            $b = [System.Convert]::FromBase64String($result)
            $f = $enc0.GetString( [System.Text.Encoding]::Convert($encU, $enc0, $b))
            [xml]$x = $f.Substring(1)
            # $rdr = $x.REV_REPORT.REV_DATA_ROOT.ChildNodes.Where({$_.name -notlike "REV*"})
            # $labels =  $x.REV_REPORT.REV_DATA_DEF
            # $data = $rdr | ConvertTo-Csv | ConvertFrom-Csv
            $data = $x
        }
        Default {
            $data = $result
        }
    }

    #Write-Progress -Activity "Running Synergy Report..." -Completed -Status "All done." -PercentComplete 100
    return $data

}