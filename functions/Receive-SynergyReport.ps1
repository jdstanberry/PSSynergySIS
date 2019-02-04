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
function Receive-SynergyReport {
    [CmdletBinding()]
    [Alias()]
    [OutputType([Array])]
    Param
    (

        #Synergy JobID
        [string]
        $JobId,

        # Credential
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential = ( Get-Credential ),

        #WebRequestSession
        [Microsoft.PowerShell.Commands.WebRequestSession]
        $WebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new(),

        # Uri
        [System.Uri]
        [Alias("SynergyUri")]
        $Uri,

        #ReportFileName
        [string]$ReportFileName = "Main",

        #OutputFormat
        [ValidateSet("CSV", "XML", "PDF", "TIFF", "EXCEL", 'TXT', "HTML", "RTF")]
        [string]$outputFormat = "CSV",

        #OutFile
        [String]$OutFile,

        #PassThru
        [System.Management.Automation.SwitchParameter]
        $PassThru

    )
    $username = $Credential.UserName
    $password = $Credential.GetNetworkCredential().Password
    $CookieContainer = $WebSession.Cookies
    $uri = $Uri.AbsoluteUri + "service/RTCommunication.asmx"
    $proxy = New-WebServiceProxy -Uri $uri
    $proxy.CookieContainer = $CookieContainer


    ### STEP 2 use returned JobID to check report processing status ###
    $paramReportStatus = "<ReportStatus><JOBID>$jobId</JOBID></ReportStatus>"

    $status = "WAITING"
    Do {
        [xml]$statusXML = $proxy.ProcessWebServiceRequest($username, $password , "Revelation.Reports", "ReportStatus", $paramReportStatus )
        $status = $statusXML.REPORTSTATUS.STATE
        $message = $statusXML.REPORTSTATUS.MESSAGE
        Write-Progress -Activity "Running Synergy Report..." -Status $status -CurrentOperation $message -PercentComplete 50
    }While (@("Waiting", "InProgress") -contains $status )

    ### STEP 3 Retrieve Completed Report ###
    Write-Progress -Activity "Running Synergy Report..." -Status "Recieving Report" -PercentComplete 75
    # $FilesList = $statusXML.REPORTSTATUS.RESULT_FILE_GROUP.RESULT_FILE
    Write-Verbose $statusXML.InnerXml

    # Currently returning the CVS results of one file only.  May revise to return zip file of multiple files #
    #Write-Information ([string]::Join(", ", $FilesList.'#text'))

    switch ($outputFormat) {
        {$_ -in 'PDF', 'TIFF', 'EXCEL', 'XML', 'TXT'} {$encodeB64 = 'Y'; Write-Warning "file is Base64 encoded"}
        {$_ -in 'HTML', 'RTF', 'CSV'} {$encodeB64 = 'N'}
        Default {$encodeB64 = 'N'}
    }


    $paramReportResult = "<ReportResult><JOBID>$jobId</JOBID><FILE>$ReportFileName</FILE><EncodeBase64>$encodeB64</EncodeBase64></ReportResult>"
    $v = "Sending:" + $paramReportResult
    Write-Verbose $v


    [xml]$resultXML = $proxy.ProcessWebServiceRequest($username, $password, "Revelation.Reports", "ReportResult", $paramReportResult )
    $result = $resultXML.REPORTRESULT.RESULT.InnerText

    switch ($outputFormat) {
        'CSV' {
            # Synergy sometimes returns CSV files with duplicate headers
            $lineone = ($result -split '\n')[0] | ForEach-Object {$_ -replace '"', ''}
            [array]$Headers = $lineone -split ","
            For ($i = 0; $i -lt $Headers.Count; $i++) {
                if ($i -eq 0) { Continue } #Skip first column.
                # If in any previous column, give it a generic header name
                if ($Headers[0..($i - 1)] -contains $Headers[$i]) {
                    $Headers[$i] = "Header$i"
                }
            }
            $fixed = $result | ConvertFrom-Csv -Header $Headers
            $data = $fixed | Select-Object -Skip 1
        }
        {$_ -in 'HTML', 'RTF'}
        {$data = $result }
        {$_ -in 'PDF', 'TIFF', 'EXCEL', 'TXT'} {
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
            $data = $x
        }
        Default {
            $result = $resultXML.REPORTRESULT.RESULT.InnerText
            $data = $result
        }
    }

    Write-Progress -Activity "Running Synergy Report..." -Completed -Status "All done." -PercentComplete 100
    return $data

}