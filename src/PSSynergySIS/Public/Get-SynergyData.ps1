<#
.Synopsis
   Command to Run a Synergy Report and return an object
.DESCRIPTION
   Uses Synergy Web Services to run a synergy CSV report and return the results as an array contained in a results object.
.PARAMETER ReportID
    The ReportID of a Built-in Synergy report such as STU408 or a User-defined report such as U-STC-STAFF
.PARAMETER Credential
    Powershell Credential such as from Get-Credential.  Use a Synergy username and password.
.PARAMETER WebSession
    Optional.  Pass a WebRequestSession object to use with multiple Get-SynergyReport commands.
.PARAMETER Uri
    The Uri of the Synergy server.
.PARAMETER School
    Optional. School Name or SIS number (probably 100)
.PARAMETER SchoolYear
    Optional.  Four digit school year.
.PARAMETER ReportFileName
    Optional Name of file to return if report has more than one.  Defaults to "Main".
.PARAMETER Name
    Optional a title to use to identity the report results
.PARAMETER ReportOptions
    Optional.  Hashtable of key/value pair for options specific to a particualar report.
    For example $Options = @{AsOfDate="8/3/2016"; TeacherID="Badge Num"; TeacherUserName="Abbreviated Name" }; Get-SynergyReport -ReportOptions $Options ...
.EXAMPLE
   Get-SynergyReportMulti -ReportID STU408 -Credential (Get-Credential)
.EXAMPLE
   $cred = Get-Credential; $ws = New-Object Microsoft.PowerShell.Commands.WebRequestSession; $rpt1 = Get-SynergyReport -ReportID U-GSDS5 -Credential $cred -WebSession $ws; $rpt2 = Get-SynergyReport -ReportID U-GSDS4 -Credential $cred -WebSession $ws
   A WebRequestSession (with Session Cookie) can be passed as a parameter to allow running multiple reports using the same web services session.  Synergy will not allow multiple sessions from the same user within 3 seconds of each other.  All requests using the same WebSession are treated as a single login.
.EXAMPLE
   $params = @{ Uri = "https://synergy.school.org";Credential= Get-Credential }; Get-SynergyReport -ReportID STU408 @params
#>
function Get-SynergyData {
    [CmdletBinding()]
    [Alias()]
    [OutputType([Array])]
    Param
    (
        # Report ID e.g. STU408
        [Parameter(Mandatory,
            ValueFromPipelineByPropertyName = $true)]
        [String]
        $ReportID,

        # Credential
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential = ( Get-Credential ),

        # WebRequestSession
        [Microsoft.PowerShell.Commands.WebRequestSession]
        $WebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new(),

        # Uri
        [System.Uri]
        [Alias("SynergyUri")]
        $Uri,

        # SchoolYear
        [string]$SchoolYear,

        # School
        [string]$School,

        #ReportFileName
        [string]$ReportFileName = "Main",

        #ReportOptions
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [hashtable]
        $ReportOptions = @{ },

        #OutputFormat
        [ValidateSet("CSV", "XML")]
        [string]$outputFormat = "XML",

        #PassThru
        [System.Management.Automation.SwitchParameter]
        $PassThru,

        #Name for the returned data, eg the type of items returned: students, classes, etc.
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        [Alias("ItemsType")]
        $Name,

        # Returns Data as a hash table
        [System.Management.Automation.SwitchParameter]
        $AsHashTable

    )
    begin {

        $SynergyParams = @{
            'Credential'     = $Credential
            'WebSession'     = $WebSession
            'Uri'            = $Uri
            'SchoolYear'     = $SchoolYear
            'School'         = $School
            'ReportFileName' = $ReportFileName
            'OutputFormat'   = $outputFormat
            'OutFile'        = $OutFile
        }
        $finalHash = [ordered]@{ LastRun = Get-Date }

        $TypeData = @{
            TypeName                  = 'My.SynergyResponse'
            DefaultDisplayPropertySet = 'Name', 'ReportID', 'LastRun', 'ItemCount'
        }
        Update-TypeData @TypeData -Force
    }

    process {
        $ReportItem = $ReportID

        #Call Invoke-SynergyReport to return WebRequestResponseObject
        $result = Invoke-SynergyReport @SynergyParams -ReportID $ReportItem -ReportOptions $ReportOptions
        # $resultXML = [xml](([xml]$result.Content).DocumentElement.InnerText)
        $resultXML = [xml]$result.string.'#text'

        $data = Get-ReportXMLResult -outputFormat $outputFormat -resultXML $resultXML
        $dataCount = (@($data)).Count

        if (!$Name) { $Name = $ReportItem }
        Write-Information "Synergy Report $ReportItem returned $dataCount records of type $Name"

        if ($AsHashTable) {
            $finalHash.Add($Name, $data)
        } else {
            return [PSCustomObject]@{
                PSTypeName = 'My.SynergyResponse'
                Name       = $Name
                ReportID   = $ReportItem
                LastRun    = Get-Date -DisplayHint DateTime
                ItemCount  = @($data).Count
                Content    = $data
            }
        }

    }

    end {
        if ($AsHashTable) {
            return $finalHash
        }
    }
}