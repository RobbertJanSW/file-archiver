##########################
# INIT
##########################
$global:inheritableObjKeys = @("fileFilter","archivePath","timespan","retention","zip")
$global:pathsDone = New-Object System.Collections.ArrayList($null)

##########################
# Functions
##########################
function log($msg) {
  $myPath = $PSScriptRoot
  $log = "$myPath\log.txt"
  
  add-content -Path $log -Value $msg
}

function verifyContent($archiveFullPath, $fileItem) {
  $inArchiveCRC = ($(& "C:\Program Files (x86)\7-Zip\7z.exe" l -slt "$($archiveFullPath)" "$($fileItem.Name)" | findstr 'CRC') -split ' ')[-1]
  $onDiskCRCMatch = ($(& "C:\Program Files (x86)\7-Zip\7z.exe" h "$($fileItem.FullName)" | findstr $inArchiveCRC)).count
  if ($onDiskCRCMatch -ne 3) { throw "ERROR IN CRC!! $inArchiveCRC" }

}

function archive($archiveObj, $defaults = $null) {

  if ($archiveObj.skip) {
    $global:pathsDone.Add($archiveObj.Path) | Out-Null
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

  # Should we process this path recursive?
  $originalPath = $archiveObj.path
  if ($archiveObj.recursive) {
    # Loop over folders and run archiving for each folder
	get-childitem $path -Recurse | ?{ $_.PSIsContainer } | % {
	  if (-Not ($global:pathsDone.Contains($_.FullName.ToLower()))) {
	    # Tricking the path into a XML object thingy:
		$archiveObj.path = $_.FullName
	    archive $archiveObj
	  }
	}
  }
  # Restoring this XML object:
  $archiveObj.path = $originalPath

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

  get-childitem $path -filter $fileFilter | sort LastWriteTime  | % {
    if ($_.LastWriteTime -lt $archiveLimitDate) {
	  $archiveDateString = Get-Date $_.LastWriteTime -Format $archiveDateFormat
	  $archiveFullPath = "$($archiveObj.archivePath)`\$($archiveDateString)-archive.zip"
	  $error.Clear()
      & "C:\Program Files (x86)\7-Zip\7z.exe" a $archiveFullPath $_.FullName
      verifyContent $archiveFullPath $_
	  if ($error) { throw "Error occured - 3267" }
	  $_.LastWriteTime
	  $_.FullName
	  Remove-Item $_.FullName
    }
  }

  # Register this path as processed so we won't process it again later (in case of recursion)
  $global:pathsDone.Add($path) | Out-Null

}



##########################
# Main
##########################
log "Starting at $(Get-Date)"

$myPath = $PSScriptRoot
[xml]$global:config = gc "$($myPath)\\archive-config.xml"

$config.folders.folder | % {
  archive $_
}

log "Done at $(Get-Date)"
