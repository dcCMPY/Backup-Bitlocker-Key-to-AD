' DESCRIPTION:
' This script will backup bitlocker recovery information to active directory for drives which are already encrypted.

' DEVELOPED BY:
' Himanshu Singh (himanshu.singh@microsoft.com)
' Microsoft Corporation

' DATE:		20/08/2013
' VERSION: 	1.0

' DISCLAIMER: 
' This script is provided "as-is". You bear the risk of using it. No express warranties, guarantees or conditions are provided. 
' The script is not supported under any Microsoft standard support program or service.

Option Explicit

' Define global constants

Private Const wmiSec 		= "winmgmts:{impersonationLevel=impersonate,authenticationLevel=pktPrivacy}!//./root/cimv2"
Private Const VolEnc 		= "/Security/MicrosoftVolumeEncryption"

' Define global variables

Dim EncryptedVols, objFSO, objFile

' Initialize Logging

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.CreateTextFile("C:\WINDOWS\TEMP\BDEAdBackup.log", True)

objFile.WriteLine "Starting Script" & vbNewLine

' Get all the encrypted volumes and then attempt to backup recovery information to AD-DS

Set EncryptedVols = GetEncryptedVolumes
BackupADDS EncryptedVols
objFile.WriteLine vbNewLine & "Script Ended."
'This function gets a list of all the volumes encrypted using bitlocker

Private Function GetEncryptedVolumes()
	Set GetEncryptedVolumes = GetObject(wmiSec & VolEnc & ":Win32_EncryptableVolume").Instances_
	If Err <> 0 Then 
		objFile.WriteLine "Unable to connect to Win32_VolumeEncryption WMI Class" & vbNewLine & _
			"Bitlocker may not be enabled on this machine." & VbCrLf & _
			"Error Returned:" & vbNewLine & err.number & vbTab & err.description
		wscript.quit
	End If
	Err.clear
End Function

Private Function BackupADDS(ByVal EncryptedVols)
		Dim evol, vLockStat, vProtectID
		objFile.WriteLine "Starting To backup recovery infromation to AD-DS for bitlocker enabled volume(s)"
		For Each evol In EncryptedVols
			objFile.WriteLine "Processing Volume: " & evol.DriveLetter
			'See if the volume is locked or not. If the Volume is Locked, we cannot backup information to AD-DS.
			objFile.WriteLine "Checking if the volume is unlocked."
			Dim VolLockStat : VolLockStat = evol.GetLockStatus(vLockStat)
			Select Case vLockStat
				Case 0
					objFile.WriteLine "Volume is unlocked, getting the protector ID for numerical password."
					Dim GetProtect: GetProtect = evol.GetKeyProtectors(3, vProtectID)
					If GetProtect <> 0 Then
						objFile.WriteLine "Error getting ID for numerical password protector of volume " & evol.DriveLetter & ", " & GetProtect
						objFile.WriteLine "Error Returned: " & Err.Number & ", " & Err.Description
					Else
						
						objFile.WriteLine "Backing up information to AD-DS."
						Dim BkpStat : BkpStat = evol.BackupRecoveryInformationToActiveDirectory(vProtectID(0))				
						
						If BkpStat <> 0 Then
							objFile.WriteLine "Backup to AD-DS failed for volume " & evol.DriveLetter 
							objFile.WriteLine "Error Returned: " & Err.Number & ", " & Err.Description
						Else
							objFile.WriteLine "Backup to AD-DS successful for volume " & evol.DriveLetter
						End If
					
					End If
					
				Case 1		'try to disable the key protectors so that we can access the drive
					objFile.WriteLine "Volume is locked, cannot backup recovery information to AD-DS."
			End Select
		Next 
		Err.clear
End Function