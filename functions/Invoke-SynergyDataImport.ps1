<#
.Synopsis
   Command to Send XML to Synergy Web Service for SIS Data Import
.DESCRIPTION
   Uses Synergy Web Services to send data for import.
#>
function Invoke-SynergyDataImport {
    [CmdletBinding()]
    [Alias()]
    Param
    (

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

        # DataImportXML
        [xml]
        $DataImportXML,

        # WebServiceHandle
        [string]
        $Handle = 'K12.IntegrationInfo.SISDataImport',

        # MethodName
        [string]
        $MethodName = 'ImportData'


    )
    $username = $Credential.UserName
    $password = $Credential.GetNetworkCredential().Password
    $uri = $Uri.AbsoluteUri + "/service/RTCommunication.asmx/ProcessWebServiceRequest"


    [xml]$reXML = $DataImportXML

    ### STEP 1  Request ###
    $paramReportExecute = $reXML.OuterXml

    $Body = @{
        userID = $username
        password = $password
        webServiceHandleName = $Handle
        methodName = $MethodName
        paramStr = $paramReportExecute
    }
    $Params = @{
        Uri = $Uri
        Method = 'post'
        Body = $Body
        WebSession = $WebSession
    }

    #[xml]$requestXml = $proxy.ProcessWebServiceRequest($username, $password, $Handle, $MethodName, "$paramReportExecute")
    $requestResponse = Invoke-WebRequest @Params
    $requestXml = [xml](([xml]$requestResponse.Content).DocumentElement.InnerText)
    $data = $requestXml.InnerXml

    Write-Progress -Activity "Sending Synergy Data..." -Status "Sending Request" -PercentComplete 25
    Write-Progress -Activity "Running Synergy Report..." -Completed -Status "All done." -PercentComplete 100
    return $data

}