param(
  [Parameter(Mandatory=$false)]
	  [string]$configFile = "$PSScriptRoot\\archive-config.xml",
  [Parameter(Mandatory=$false)]
	  [string]$logFilePath = $PSScriptRoot,
  [Parameter(Mandatory=$false)]
	  [string]$logFileName = "$(Get-Date -Format 'yyyy-MM-dd-HH')-archiver-log.txt"
)

##########################
# INIT
##########################
$ErrorActionPreference = "Stop"
$global:inheritableObjKeys = @("fileFilter","archivePath","timespan","retention","zip")
$global:pathsDone = New-Object System.Collections.ArrayList($null)
$global:filesArchiving = New-Object System.Collections.ArrayList($null)
if (Test-Path "C:\Program Files (x86)\7-Zip\7z.exe") {
  $global:sevenzipBinary = "C:\Program Files (x86)\7-Zip\7z.exe"
} else {
  $global:sevenzipBinary = "7z.exe"
}

##########################
# Functions
##########################
function log($msg) {
  add-content -Path $("$logFilePath\\$logFileName") -Value $msg
}

function verifyContent($archiveFullPath, $fileItems) {
  # Extract all files from archive to temp location
  & "$global:sevenzipBinary" e "$($archiveFullPath)" -oC:\temp\tempfilearchiverdump
  $fileItems | % {
    $fileItem = $_
    $inArchiveCRC = ($(& "$global:sevenzipBinary" h "C:\temp\tempfilearchiverdump\$($fileItem.Name)" | findstr 'CRC') -split ' ')[-1]
    if ($error -ne $null) { throw $error; exit 78 }
    $onDiskCRCMatch = ($(& "$global:sevenzipBinary" h "$($fileItem.FullName)" | findstr $inArchiveCRC)).count
    if ($error -ne $null) { throw $error; exit 79 }
    if ($onDiskCRCMatch -ne 3) { throw "ERROR in CRC check between file $($fileItem.Name) in $archiveFullPath and $($fileItem.FullName)" }
  }
  remove-item C:\temp\tempfilearchiverdump\*.* -Force
}

function archive($archiveObj, $defaults = $null) {

  if ($archiveObj.skip) {
	log "Skipping $($archiveObj.Path) by config"
    $global:pathsDone.Add((Get-Item $archiveObj.Path).FullName.ToLower()) | Out-Null
    return
  }

  log "Processing folder $($archiveObj.Path)"
  if ($archiveObj.folders) {
	# Subfolders are defined - first process the defined subfolders!
    $archiveObj.folders.folder | % {
	  log "Proceeding processing lower into defined subfolders"
      archive $_ $archiveObj
    }
    log "DONE processing lower subfolders"
  }

  $path = $archiveObj.Path.ToLower()

  # Should we process this path recursive?
  $originalPath = $archiveObj.Path
  if ($archiveObj.recurse) {
    # Loop over folders and run archiving for each folder
	get-childitem $path | ?{ $_.PSIsContainer } | % {
	  if (-Not ($global:pathsDone.Contains($_.FullName.ToLower()))) {
	    # Tricking the path into a XML object thingy:
	    $archiveObjCopy = $archiveObj.Clone()
		  $archiveObjCopy.Path = $_.FullName
		  if (-Not $archiveObjCopy.rootPath) {
		    $xmlSubElt = $global:config.CreateElement('rootPath')
		    $xmlSubText = $global:config.CreateTextNode($archiveObj.Path)
		    $xmlSubElt.AppendChild($xmlSubText) | Out-Null
		    $archiveObjCopy.AppendChild($xmlSubElt) | Out-Null
		  }
	    archive $archiveObjCopy
	  }
	}
  }
  # Restoring this XML object:
  $archiveObj.Path = $originalPath

  if ($defaults -ne $null) {
    $global:inheritableObjKeys | % {
		$key = $_
		if (((-Not ($archiveObj.$key)) -And $defaults.$key)) {
		  log "Adopting default setting for $key"
		  $xmlSubElt = $global:config.CreateElement($key)
		  $xmlSubText = $global:config.CreateTextNode($defaults.$key)
		  $xmlSubElt.AppendChild($xmlSubText) | Out-Null
		  $archiveObj.AppendChild($xmlSubElt) | Out-Null
		}
	}
  }

  $path = $archiveObj.path.ToLower()
  $fileFilter = $archiveObj.fileFilter
  $retention = $archiveObj.retention

  $today = Get-Date
  if ($archiveObj.timespan -eq 'month') {
	# Monthly archives
    $timespanDays = (($today.AddMonths($retention)) - $today).Days
	$archiveDateFormat = "yyyy-MM"
  }
  $archiveLimitDate = ($today).AddDays(-1 * $timespanDays)
  log "Archiving date limit by retention is: $archiveLimitDate"

  $filesArchiving = New-Object System.Collections.ArrayList($null)
  $currentArchiveCaching = $null
  get-childitem $path -filter $fileFilter | ?{ -Not $_.PSIsContainer } | % {
    if ($_.LastWriteTime -le $archiveLimitDate) {
	  $archiveDateString = Get-Date $_.LastWriteTime -Format $archiveDateFormat
	  if ($archiveObj.rootPath) {
	    # Running recursive in subfolder
	    $subfolder = ($archiveObj.Path -split [regex]::Escape("$($archiveObj.rootPath)`\"))[1]
	    $subfolder = "$subfolder`\"
	  }
	  $archiveFullPath = "$($archiveObj.archivePath)`\$($subfolder)$($archiveDateString)-archive.zip"
	  $error.Clear()
	  log "Archiving file $($_.FullName) with LastWriteTime $($_.LastWriteTime) to archive $($archiveFullPath)"
	  
	  if (($filesArchiving.Count -gt 99) -Or (($currentArchiveCaching -ne $Null) -And ($currentArchiveCaching -ne $archiveFullPath))) {
	   $filesString = "$($filesArchiving | % { $_.FullName })"
	   & "$global:sevenzipBinary" a $archiveFullPath "$($filesString)" | Out-Null
        if ($error -ne $null) { throw $error; exit 77 }
        verifyContent $archiveFullPath $filesArchiving
	    if ($error) { throw "Error occured - 3267" }
	    $filesArchiving | % { Remove-Item $_.FullName }
		$filesArchiving.Clear()
	  }
	  $filesArchiving.Add($_)
      $currentArchiveCaching = $archiveFullPath
    }
  }

if ($filesArchiving.Count -ne 0) {
	   $filesString = "$($filesArchiving | % { $_.FullName })"
	   & "$global:sevenzipBinary" a $archiveFullPath "$($filesString)" | Out-Null
        if ($error -ne $null) { throw $error; exit 77 }
        verifyContent $archiveFullPath $filesArchiving
	    if ($error) { throw "Error occured - 3267" }
	    $filesArchiving | % { Remove-Item $_.FullName }
		$filesArchiving.Clear()
}

  # Register this path as processed so we won't process it again later (in case of recursion)
  $global:pathsDone.Add($path) | Out-Null

}



##########################
# Main
##########################
log "Starting at $(Get-Date)"
log "Commandline: $($MyInvocation.Line)"

[xml]$global:config = gc $configFile

$config.folders.folder | % {
  archive $_
}

log "Done at $(Get-Date)"
