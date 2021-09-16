function Set-SynergyConfig {
    param (
        [string]$ServerUri,

        [pscredential]$Credential
    )

    $config = @{}
    if ($ServerUri){
        $config.Add("ServerUri",$ServerUri)
    }
    if ($Credential){
        $config.Add("Credential",$Credential)
    }

    $config | Export-Configuration
}