Public Sub OpenPatchAnalysisReporter_WithEmail()
    On Error GoTo ErrHandler

    Dim copilotUrl As String
    Dim edgePath As String
    Dim mail As Object
    Dim promptText As String
    Dim tempPath As String
    Dim fso As Object
    Dim ts As Object

    copilotUrl = "https://m365.cloud.microsoft/chat/agent-url-goes-here"

    edgePath = GetEdgePath()
    Set mail = GetSelectedMailOnly()

    If mail Is Nothing Then
        MsgBox "No email selected. Click an email first, then try again.", vbExclamation, "Patch Analysis Reporter"
        Exit Sub
    End If

    promptText = "Analyze this email for Windows patch known issues, Server OS risk, Epic/healthcare application impact, and recommended next steps." & vbCrLf & vbCrLf & _
                 "Subject: " & GetSafeText(mail, "Subject") & vbCrLf & _
                 "From: " & GetSafeText(mail, "SenderName") & vbCrLf & _
                 "Received: " & GetSafeText(mail, "ReceivedTime") & vbCrLf & vbCrLf & _
                 "Email Body:" & vbCrLf & _
                 Left(GetSafeText(mail, "Body"), 15000)

    tempPath = Environ$("TEMP") & "\PatchAnalysisReporter_EmailPrompt.txt"

    Set fso = CreateObject("Scripting.FileSystemObject")
    Set ts = fso.CreateTextFile(tempPath, True, True)
    ts.Write promptText
    ts.Close

    shell "notepad.exe """ & tempPath & """", vbNormalFocus
    shell """" & edgePath & """ --app=""" & copilotUrl & """", vbNormalFocus

    Exit Sub

ErrHandler:
    MsgBox "Error: " & Err.Description, vbCritical, "Patch Analysis Reporter"
End Sub

Private Function GetSelectedMailOnly() As Object
    On Error GoTo FailSafe

    Dim exp As Object
    Dim sel As Object
    Dim item As Object

    Set exp = Application.ActiveExplorer
    If exp Is Nothing Then GoTo FailSafe

    Set sel = exp.Selection
    If sel Is Nothing Then GoTo FailSafe
    If sel.Count = 0 Then GoTo FailSafe

    Set item = sel.item(1)

    If TypeName(item) = "MailItem" Then
        Set GetSelectedMailOnly = item
        Exit Function
    End If

FailSafe:
    Set GetSelectedMailOnly = Nothing
End Function

Private Function GetSafeText(ByVal obj As Object, ByVal propName As String) As String
    On Error GoTo FailSafe

    GetSafeText = CStr(CallByName(obj, propName, VbGet))
    Exit Function

FailSafe:
    GetSafeText = ""
End Function

Private Function GetEdgePath() As String
    If Dir("C:\Program Files\Microsoft\Edge\Application\msedge.exe") <> "" Then
        GetEdgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    ElseIf Dir("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") <> "" Then
        GetEdgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    Else
        Err.Raise vbObjectError + 1000, "Patch Analysis Reporter", "Microsoft Edge was not found."
    End If
End Function
