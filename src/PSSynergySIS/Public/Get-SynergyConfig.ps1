function Get-SynergyConfig {
    [CmdletBinding()]
    param (
        $BoundParameters
    )
    $config = Import-Configuration

    if ( !$config.ServerUri){
        Write-Warning "No default Server specified.  Set with Set-SynergyConfig"
    }

    #By checking against PSBoundParameters we can allow the Cmdlet to override the stored parameters in a central place.
    $passedUri = $BoundParameters.Uri ?? $null
    $passedCred = $BoundParameters.Credential ?? $null

    $finalUri =  $passedUri ?? $config.ServerUri
    $config.ServerUri = $finalUri ?? (Read-Host -Prompt "Enter the Uri of the Synergy server")

    $finalCred = $passedCred ?? $config.Credential ?? (Get-Credential -Message "Enter Synergy User credentials")
    $config.Credential = $finalCred

    return $config
}