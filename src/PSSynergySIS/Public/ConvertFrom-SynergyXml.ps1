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
function ConvertFrom-SynergyXml {
    param (
        [xml]$xml
    )
    $nodes = $xml | Select-Xml "/REV_REPORT/REV_DATA_DEF/REV_LABEL_GROUP/*"

    For ($i = 0; $i -lt $nodes.Count; $i++) {
        if ($i -eq 0) { Continue } #Skip first column.
        # If in any previous column, give it a generic header name
        if ($nodes[0..($i - 1)].Node.Label -contains $nodes[$i].Node.Label) {
            $nodes[$i].Node.Label = $nodes[$i].Node.LocalName
        }
    }

    $headers = foreach ($node in $nodes) {
        [PSCustomObject]@{
            LocalName = $node.Node.LocalName
            Label     = $node.Node.Label
            Order     = [int]$node.Node.ORDER
        }
    }

    # $dataNodes = $xml | Select-Xml "/REV_REPORT/REV_DATA_ROOT/*[contains(local-name(),'FB')]"
    $dataNodes = $xml | Select-Xml "/REV_REPORT/REV_DATA_ROOT/*[not(self::REV_TIME)][not(self::REV_DATE)]" | Select-Object -ExpandProperty Node

    $a = [System.Collections.ArrayList]@()
    foreach ($dataNode in $dataNodes) {
        $members = $dataNode | Get-Member -MemberType Property
        $obj = [PSCustomObject]@{}
        foreach ($member in $members) {
            if ($dataNode.LocalName -eq 'ROW') {
                [string]$NewLabel = $member.Name -replace '^.*?_'
                $obj | Add-Member -MemberType NoteProperty -Name $NewLabel -Value $dataNode.($member.Name)
            } else {
                $header = $headers | Where-Object LocalName -EQ $member.Name
                # [string]$NewLabel = $header.Label ?? $member.Name
                $header | ForEach-Object {
                    $obj | Add-Member -MemberType NoteProperty -Name $_.Label -Value $dataNode.($member.Name)
                }
            }
            # $NewLabel ??= $member.Name
        }
        $null = $a.Add($obj)
    }


    # foreach ($i in $dataNodes) {
    #     $dat = $i
    #     $x = [PSCustomObject]@{ }
    #     foreach ($h in $headers) {
    #         $x | Add-Member -MemberType NoteProperty -Name $h.Label -Value $dat.($h.LocalName)
    #     }
    #     $null = $a.Add($x)
    # }
    return $a
}