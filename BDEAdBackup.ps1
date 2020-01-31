if (!(test-Path -Path 'C:\Windows\Temp\BDEAdBackup.log'))
{
cscript \\servershare\bdeBackup\BDEAdBackup.vbs
}

else
{
write-host "BitlockerKey already backed up."
}

exit