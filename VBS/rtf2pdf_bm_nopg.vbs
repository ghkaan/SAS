Option Explicit

Dim fso, folder, file, word, doc, pdfs, pdfPath, combinedPdf
Dim app, pdDoc, pdInsert, i

Set fso = CreateObject("Scripting.FileSystemObject")
Set folder = fso.GetFolder(".")
Set pdfs = CreateObject("Scripting.Dictionary")

WScript.Echo "RTF2PDF - Processing RTF files in current folder"

' Convert RTF to PDF using Word
Set word = CreateObject("Word.Application")
word.Visible = False

For Each file In folder.Files
    If LCase(fso.GetExtensionName(file.Name)) = "rtf" And Left(file.Name, 1) <> "~" Then
        pdfPath = fso.BuildPath(folder.Path, fso.GetBaseName(file.Name) & ".pdf")
        If Not fso.FileExists(pdfPath) Then
            Set doc = word.Documents.Open(file.Path, False, True)
            doc.ExportAsFixedFormat pdfPath, 17
            doc.Close False
        End If
        pdfs.Add pdfPath, fso.GetBaseName(file.Name)
    End If
Next

word.Quit

If pdfs.Count = 0 Then
    WScript.Echo "No RTF files found."
    WScript.Quit
End If

combinedPdf = fso.BuildPath(folder.Path, "combined.pdf")

' Combine PDFs
Set app = CreateObject("AcroExch.App")
Set pdDoc = CreateObject("AcroExch.PDDoc")

Dim keys
keys = pdfs.Keys
pdDoc.Open keys(0)

For i = 1 To pdfs.Count - 1
    Set pdInsert = CreateObject("AcroExch.PDDoc")
    pdInsert.Open keys(i)
    pdDoc.InsertPages pdDoc.GetNumPages() - 1, pdInsert, 0, pdInsert.GetNumPages(), False
    pdInsert.Close
Next

' Simple bookmark attempt
On Error Resume Next
Dim jso, pageNum, bmName
Set jso = pdDoc.GetJSObject

If Not jso Is Nothing Then
    For i = pdfs.Count - 1 To 0 Step -1
        bmName = pdfs(keys(i))
        jso.bookmarkRoot.createChild(bmName)
    Next
End If

pdDoc.Save 1, combinedPdf
pdDoc.Close
app.Exit

WScript.Echo "Combined PDF created: " & combinedPdf
WScript.Echo "Note: For reliable bookmarks, consider adding them manually in Acrobat"