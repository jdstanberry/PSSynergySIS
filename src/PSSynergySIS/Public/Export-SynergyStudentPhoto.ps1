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
        $Credential = ( Get-Credential ),

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

    #$GradeFilter
    Write-Progress -Activity "Running Report STU417"
    $students = Get-SynergyData -ReportID STU417 -SynergyUri $Synergyuri -WebSession $WebSession -Credential $Credential -School $School
    $data = $students | Where-Object Photo -NE ''
    $data = $data | Where-Object Photo -NE 'Photo'
    $data = $data | Select-Object *, @{Name = "PermID"; Expression = { $_.'Perm ID' } }, @{Name = "PhotoUri"; Expression = { "https://" + $Synergyuri + "/" + [String]$_.Photo.Remove(($_.Photo.Length) - 20, 11) } }
    $data = $data | Select-Object *, @{Name = "FileName"; Expression = { $_.PermID + ".PNG" } }
    $data | ForEach-Object  -Begin { $i = 0; $i++ } -Process {
        $ProgressPreference = 'silentlyContinue'
        Invoke-WebRequest -Uri ($_.PhotoUri) -OutFile ("$Path" + "\" + ($_.FileName))
        $ProgressPreference = 'Continue'
        Write-Progress -Activity "Downloading Student Photos" -PercentComplete ( $i/($data.Count)*100) -CurrentOperation ("Photo $i of " + ($data.Count))
        $i++
    }

    $data | Select-Object -Property PermID, FileName | Export-Csv -Path "$Path\idlink.csv" -NoTypeInformation
    $data | Select-Object -Property @{Name = "Barcode"; Expression = { "P " + ($_PermID) } }, FileName | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File "$Path\idlink.txt"
    switch ($MakeArchive) {
        'basic' { $data[0..5000].FileName, 'idlink.csv' | Compress-Archive -DestinationPath "$Path\basic" -Force }

        'Follett' { $data[0..5000].FileName, 'idlink.txt' | Compress-Archive -DestinationPath "$Path\Follett" -Force }
        Default { }
    }
    Return $data[0..5000].FileName
}