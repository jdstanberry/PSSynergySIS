<#
.Synopsis
Exports student photos to a directory or archive for import into a differnt system.
.DESCRIPTION
Executes STU417 Student ID Cards and fetchs all student photos from Synergy.  Outputs a list of created files to pipe to another command.
.PARAMETER Path
Path to where images are saved.  Defaults to local path.
.PARAMETER SynergyUri
URL of Synergy server.  No need for http://
.EXAMPLE
Export-SynergyStudentPhotos -Path -SynergyUri "schoool.apscc.org"
This command will ask for username and password and then export all photos to the current directory.
.EXAMPLE
Export-SynergyStudentPhotos -Path Images -SynergyUri "school.apscc.org" -Credential (Get-Credential)
This command will export all photos to the Images sub directory.
.EXAMPLE
Export-SynergyStudentPhotos -SynergyUri "school.apscc.org" | Compress-Archive -DestinationPath "images.zip"
Pipe the list of images to another command.
#>
function Export-SynergyStudentPhoto {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param (
        # Path
        [String]
        $Path = ".",

        # Credential
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        #WebRequestSession
        [Microsoft.PowerShell.Commands.WebRequestSession]
        $WebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new(),

        # SynergyUri
        [string]
        $SynergyUri,

        # MakeArchive
        [ValidateSet("none", "basic", "eTrition", "Follett")]
        [String]
        $MakeArchive = "none",

        # School
        $School
    )

    $config = Get-SynergyConfig -BoundParameters $PSBoundParameters

    Write-Progress -Activity "Running Report STU417"
    $students = Get-SynergyData -ReportID STU417 -WebSession $WebSession
    $data = $students.Content | Where-Object Photo -NE ''
    $data = $data | Where-Object Photo -NE 'Photo'
    $data = $data | ForEach-Object {
        $photoPath = (( $_.Photo -split '_' ) | Select-Object -Index 0, 2) -join '_'
        [PSCustomObject]@{
            PermID   = $_.'Perm ID'
            PhotoUri = $config.ServerUri + "/" + $photoPath
            FileName = $_.'Perm ID' + ".PNG"
            Barcode  = "P " + $_.'Perm ID'
            ID       = $_.'Perm ID'
        }
    }

    # $data = $data | Select-Object *, @{Name = "PermID"; Expression = { $_.'Perm ID' } }, @{Name = "PhotoUri"; Expression = { $config.ServerUri + "/" + [String]$_.Photo.Remove(($_.Photo.Length) - 20, 11) } }
    # $data = $data | Select-Object *, @{Name = "FileName"; Expression = { $_.PermID + ".PNG" } }
    $data | ForEach-Object  -Begin { $i = 0; $i++ } -Process {
        $ProgressPreference = 'silentlyContinue'
        Invoke-WebRequest -Uri ($_.PhotoUri) -OutFile ("$Path" + "\" + ($_.FileName)) -WebSession $WebSession
        $ProgressPreference = 'Continue'
        Write-Progress -Activity "Downloading Student Photos" -Status ("Photo $i of " + ($data.Count)) -PercentComplete ( $i / ($data.Count) * 100) -CurrentOperation ("Photo $i of " + ($data.Count))
        $i++
    }

    $data | Select-Object -Property PermID, FileName | Export-Csv -Path "$Path\idlink.csv" -NoTypeInformation
    $data | Select-Object -Property PermID, FileName | Export-Csv -Path "$Path\etrition.csv" -NoTypeInformation -NoHeader
    $data | Select-Object -Property Barcode, FileName | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File "$Path\idlink.txt"

    switch ($MakeArchive) {
        'basic' { $data[0..5000].FileName, 'idlink.csv', 'idlink.txt', 'etrition.csv' | Compress-Archive -DestinationPath "$Path\basic" -Force }

        'Follett' { $data[0..5000].FileName, 'idlink.txt', 'etrition.csv' | Compress-Archive -DestinationPath "$Path\Follett" -Force }
        Default { }
    }

    Return $data[0..5000].FileName
}