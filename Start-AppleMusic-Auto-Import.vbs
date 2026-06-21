Option Explicit

Dim shell, fso, scriptDir, ps1, cmd, i
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = fso.BuildPath(scriptDir, "AppleMusic-Auto-Enrich-Import.ps1")

If Not fso.FileExists(ps1) Then
    MsgBox "Cannot find AppleMusic-Auto-Enrich-Import.ps1 in this folder.", vbCritical, "Apple Music Auto Import"
    WScript.Quit 1
End If

cmd = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File " & Q(ps1)

For i = 0 To WScript.Arguments.Count - 1
    cmd = cmd & " " & Q(WScript.Arguments.Item(i))
Next

shell.Run cmd, 1, False

Function Q(value)
    Q = Chr(34) & CStr(value) & Chr(34)
End Function
