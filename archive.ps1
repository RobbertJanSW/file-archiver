

# INIT

$global:inheritableObjKeys = @("fileFilter","archivePath","timespan","retention","zip")

$global:pathsDone = New-Object System.Collections.ArrayList($null)

function archive($archiveObj, $defaults = $null) {

  if ($archiveObj.skip) {
    $global:pathsDone.Add($archiveObj.Path) | Out-Null
    return
  }

  write-host "Running $($archiveObj.Path)" -ForeGroundColor Red
  if ($archiveObj.folders) {
	# Subfolders are defined - first process the defined subfolders!
    $archiveObj.folders.folder | % {
	  write-host "Moving run lower to defined subfolders" -ForeGroundColor Red
      archive $_ $archiveObj
    }
    write-host "DONE lower to defined subfolders" -ForeGroundColor Red
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
	write-host $defaults
	write-host $defaults
	write-host $defaults
	write-host $defaults.GetType()
	$r = 'Path'
	write-host "$($defaults.$r)"
	pause 99
    $global:inheritableObjKeys | % {
		$key = $_
		if (((-Not ($archiveObj.$key)) -And $defaults.$key)) {
		  write-host "ADOPTING DEFAULT for $key" -ForeGroundColor Red
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
  write-host "ARCHIVE DATE LIMIT: $archiveLimitDate"
  
  get-childitem $path -filter $fileFilter | sort LastWriteTime  | % {
    $_.LastWriteTime
    Get-Date $_.LastWriteTime -Format "yyyyMM"
    if ($_.LastWriteTime -lt $archiveLimitDate) {
	  $archiveDateString = Get-Date $_.LastWriteTime -Format $archiveDateFormat
	  $archiveFullPath = "$($archiveObj.archivePath)\\$($archiveDateString)-archive.zip"
	  $error.Clear()
      & "C:\Program Files (x86)\7-Zip\7z.exe" a $archiveFullPath $_.FullName
	  if ($error) { throw "Error occured - 3267" }
	  $_.LastWriteTime
	  $_.FullName
	  Remove-Item $_.FullName
    } else {
      write-host $_.LastWriteTime -ForeGroundColor Red
    }
  }

  # Register this path as processed so we won't process it again later (in case of recursion)
  $global:pathsDone.Add($path) | Out-Null

}




$myPath = $PSScriptRoot
[xml]$global:config = gc "$($myPath)\\archive-config.xml"

$config.folders.folder | % {
  archive $_
}
