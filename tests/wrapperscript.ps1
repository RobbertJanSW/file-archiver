$module = "C:\Program Files (x86)\WindowsPowerShell\Modules\Pester"
takeown /F $module /A /R | Out-Null
icacls $module /reset | Out-Null
icacls $module /grant Administrators:'F' /inheritance:d /T | Out-Null
Remove-Item -Path $Module -Recurse -Force -Confirm:$false

Install-Module -Name Pester -Force -SkipPublisherCheck

Invoke-Pester .\tests\pester.ps1 -EnableExit
