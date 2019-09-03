<#
.Synopsis
   This cmdlet will take a Powershell array object and convert it to an XML file formatted for Synergy Generic Conversion.
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function New-SynergyDataImport {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Import Object
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        $ImportObject,

        # InputFormat
        [ValidateSet("StudentData", "StudentBus", "GridCodes")]
        [string]$InputFormat,

        # OverwriteFlag
        $OverwriteFlag,

        # SchoolCode
        $SchoolCode,

        # SchoolYear
        $SchoolYear
    )

    switch ($InputFormat) {
        'StudentData' {
            [xml]$ImportXML =
            @"
 <ROOT OVERWRITE_STUDENT="$overwriteFlag" DEBUG="1" >
 $( $ImportObject | ForEach-Object { '<STUDENT LAST_NAME="{0}" FIRST_NAME="{1}" SIS_NUMBER="{2}" E_MAIL="{3}" />' -f $_.LastName, $_.FirstName, $_.SISID, $_.Email }
 )
 </ROOT>
"@
            Return $ImportXML

        }
        'StudentBus' {
            [xml]$xmlData =
            @"
<?xml version="1.0" encoding="UTF-8"?><ROOT>
$($ImportObject | ForEach-Object { '<STUDENT_SCHOOL_YEAR SIS_NUMBER="{0}" SCHOOL_CODE="{1}" SCHOOL_YEAR="{2}" BUS_TO_SCHOOL="{3}" />' -f $_.'Perm ID', $SchoolCode, $SchoolYear, [System.Security.SecurityElement]::Escape($_.BusRoute) }
)
</ROOT>
"@
            Return $xmlData



        }
        'GridCodes' {
            [xml]$xmlData =
            @"
<ROOT>
$( $importObject | ForEach-Object {
'<STREET GRID_CODE="{0}" ELEMENTARY="{1}" SCHOOL_YEAR="{2}" CITY="{3}" STATE"{4}" STREET_NAME="{5}" STREET_LOW_ADDRESS={6} STREET_HIGH_ADDRESS="{7}" STREET_INC_ADDRESS="{8} STREET_ODD_EVEN="{9} STREET_DIRECTION="{10}" STREET_TYPE="{11}" ZIP5="{12} />' `
    -f $_.gc, $_.e, $_.sy, $_.city, $_.state, $_.st, $_.low, $_.high
})</ROOT>
"@
            Return $xmlData
        }
    }
}