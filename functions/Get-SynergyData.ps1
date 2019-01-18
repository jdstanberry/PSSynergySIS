<#
.Synopsis
   Command to Run a Synergy Report
.DESCRIPTION
   Uses Synergy Web Services to run a synergy CSV report and return the results as an array.
.PARAMETER ReportID
    The ReportID of a Built-in Synergy report such as STU408 or a User-defined report such as U-STC-STAFF
.PARAMETER Credential
    Powershell Credential such as from Get-Credential.  Use a Synergy username and password.
.PARAMETER CookieContainer
    Optional.  Pass a CookieContainer object to use with multiple Get-SynergyReport commands.
.PARAMETER Uri
    The Uri of the Synergy server.
.PARAMETER School
    Optional. School Name or SIS number (probably 100)
.PARAMETER SchoolYear
    Optional.  Four digit school year.
.PARAMETER ReportFileName
    Optional Name of file to return if report has more than one.  Defaults to "Main".
.PARAMETER ReportOptions
    Optional.  Hashtable of key/value pair for options specific to a particualar report.
    For example $Options = @{AsOfDate="8/3/2016"; TeacherID="Badge Num"; TeacherUserName="Abbreviated Name" }; Get-SynergyReport -ReportOptions $Options ...
.EXAMPLE
   Get-SynergyReport -ReportID STU408 -Credential (Get-Credential)
.EXAMPLE
   $cred = Get-Credential; $cc = New-Object System.Net.CookieContainer; $rpt1 = Get-SynergyReport -ReportID U-GSDS5 -Credential $cred -CookieContainer $cc; $rpt2 = Get-SynergyReport -ReportID U-GSDS4 -Credential $cred -CookieContainer $cc
   A CookieContainer (AKA a Session Cookie) can be passed as a parameter to allow running multiple reports using the same web services session.  Synergy will not allow multiple sessions from the same user within 3 seconds of each other.  All requests using the same cookie container are treated as a single login.
.EXAMPLE
   $params = @{ SynergyUri = "https://synergy.school.org";Credential= Get-Credential;CookieContainer=New-Object System.Net.CookieContainer; }; Get-SynergyReport -ReportID STU408 @params
#>
function Get-SynergyData {
    [CmdletBinding()]
    [Alias()]
    [OutputType([Array])]
    Param
    (
        # Report ID e.g. STU408
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]
        $ReportID = "STU804",

        # Credential
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential = ( Get-Credential ),

        # CookieContainer
        [System.Net.CookieContainer]
        $CookieContainer = [System.Net.CookieContainer]::new(),

        #WebRequestSession
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
        [hashtable]$ReportOptions = @{},

        #OutputFormat
        [ValidateSet("CSV", "XML")]
        [string]$outputFormat = "CSV",

        #OutFile
        [String]$OutFile,

        #PassThru
        [System.Management.Automation.SwitchParameter]
        $PassThru,

        #itemsType
        [string]
        $itemsType

    )


    $SynergyParams = @{
        'ReportID'        = $ReportID ;
        'Credential'      = $Credential ;
        'CookieContainer' = $CookieContainer ;
        'WebSession'      = $WebSession ;
        'Uri'             = $Uri ;
        'SchoolYear'      = $SchoolYear ;
        'School'          = $School ;
        'ReportFileName'  = $ReportFileName ;
        'ReportOptions'   = $ReportOptions ;
        'OutputFormat'    = $outputFormat ;
        'OutFile'         = $OutFile ;
    }

    #Call Invoke-SynergyReport to return WebRequestResponseObject
    $result = Invoke-SynergyReport @SynergyParams
    $resultXML = [xml](([xml]$result.Content).DocumentElement.InnerText)

    $data = Get-ReportXMLResult -outputFormat $outputFormat -resultXML $resultXML
    $dataCount = (@($data)).Count

    Write-Information "Synergy Report $ReportID returned $dataCount records of type $itemsType"

    return $data

}