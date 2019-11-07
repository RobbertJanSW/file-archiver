describe 'Requirements' {
        it 'should detect 7Zip' {
		((Test-Path 'C:\Program Files (x86)\7-Zip\7z.exe') -Or ((iex '7z.exe -h').count -gt 0)) | Should -Be $true
        }
        it 'should detect test config XML' {
		Test-Path '.\tests\fixtures\archive-config.xml' | Should -Be $true
        }
}
describe 'Testrun' {
        it 'should succeed' {
		$error.Clear()
		iex '.\file-archiver\archive.ps1 -configFile .\tests\fixtures\archive-config.xml'
		$error | Should -Be $Null
        }
        it 'should archive files in .\testfolder' {
		(Get-ChildItem .\tests\fixtures\testfolder).Count | Should -Be 2
        }
        it 'should archive files in .\testfolder\folder1' {
		(Get-ChildItem .\tests\fixtures\testfolder\folder1).Count | Should -Be 0
        }
        it 'should NOT archive files in .\testfolder\folder2' {
		(Get-ChildItem .\tests\fixtures\testfolder\folder2).Count | Should -Be 1
        }
        it 'should archive files in .\testfolder2' {
		(Get-ChildItem .\tests\fixtures\testfolder2).Count | Should -Be 2
        }
        it 'should archive files in .\testfolder2\subfolder3 to test-archive4\subfolder3\*.zip' {
		(Get-ChildItem .\tests\fixtures\testfolder2\subfolder3).Count | Should -Be 0
		(Get-ChildItem -Filter *.zip .\test-archive4\subfolder3).Count | Should -Be 1
        }
        it 'should archive ONLY *.txt files in .\testfolder4' {
		(Get-ChildItem .\tests\fixtures\testfolder4).Count | Should -Be 3
		(Get-ChildItem -Filter *.txt .\tests\fixtures\testfolder4).Count | Should -Be 0
        }
        it 'should archive ONLY *.log files in .\testfolder3' {
		(Get-ChildItem .\tests\fixtures\testfolder3).Count | Should -Be 2
		(Get-ChildItem -Filter *.log .\tests\fixtures\testfolder3).Count | Should -Be 0
        }
        it 'should NOT archive files in .\testfolder2\subfolder4' {
		(Get-ChildItem .\tests\fixtures\testfolder2\subfolder4).Count | Should -Be 1
        }
        it 'should NOT archive files in .\ (testfolder root)' {
		(Get-ChildItem .\tests\fixtures).Count | Should -Be 6
        }
        it 'should archive the .txt file in .\testfolder4\subfolder5\subfolder6 to test-archive5\subfolder5\subfolder6\*.zip' {
		(Get-ChildItem .\tests\fixtures\testfolder4\subfolder5\subfolder6).Count | Should -Be 0
		(Get-ChildItem -Filter *.zip .\test-archive5\subfolder5\subfolder6).Count | Should -Be 1
        }
        it 'should create the default logfile' {
		(Get-ChildItem .\file-archiver\*-archiver-log.txt).Count | Should -Be 1
        }
}
describe 'Testrun with alternate logfile location' {
        it 'should succeed' {
		$error.Clear()
		iex '.\file-archiver\archive.ps1 -configFile .\tests\fixtures\archive-config.xml -logFilePath .\tests -logFileName logfile.log'
		$error | Should -Be $Null
        }
        it 'should create the defined alternate logfile' {
		(Get-ChildItem .\tests\logfile.log).Count | Should -Be 1
        }
}
