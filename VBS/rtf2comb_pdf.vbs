' This script converts separate RTF files into PDF format and combine into a single PDF file with bookmarks, performing the following actions:
' 1. Retrieves all RTF files in the current folder.
' 2. Convert each RTF file to PDF format
' 3. Creates "combined.pdf".
' 4. Inserts all source PDF files into "combined.pdf".
' 5. Generates bookmarks for each section based on original filenames (without extensions).
' 6. Generate pdf_page_reference.txt with page numbers for each bookmark: if links in PDF bookmarks do not work then last step should be performed manually - 
'    user should go through all pages listed in this file and link to appropriate bookmark in Adobe Acrobat PRO or Nirto PRO.
' v1.0, 17Nov2025, Anton Kamyshev

Option Explicit

Dim fso, folder, file, word, doc, pdfs, pdfPath, combinedPdf
Dim app, pdDoc, pdInsert, i

Set fso = CreateObject("Scripting.FileSystemObject")
Set folder = fso.GetFolder(".")
Set pdfs = CreateObject("Scripting.Dictionary")
Const BMType = 1
' BMType=1 - use JScript links (works in Adobe Acrobat PRO, Nitro PRO etc)
' BMType=2 - use legacy method - do not work in Adobe Acrobat PRO, Nitro PRO etc, but can work in Adove Reader

WScript.Echo "RTF2PDF - Processing RTF files in current folder." & vbCrLf & "Press Ok to continue."

' Convert RTF to PDF using Word
Set word = CreateObject("Word.Application")
word.Visible = False

For Each file In folder.Files
    If LCase(fso.GetExtensionName(file.Name)) = "rtf" And Left(file.Name, 1) <> "~" And file.Name <> "combined.rtf" Then
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

' Combine PDFs
combinedPdf = fso.BuildPath(folder.Path, "combined.pdf")
Set app = CreateObject("AcroExch.App")
Set pdDoc = CreateObject("AcroExch.PDDoc")

Dim keys
keys = pdfs.Keys

' Open the first PDF to start combining
pdDoc.Open keys(0)

' Combine remaining PDFs starting from the second one (index 1)
For i = 1 To pdfs.Count - 1
    Set pdInsert = CreateObject("AcroExch.PDDoc")
    If pdInsert.Open(keys(i)) Then
        pdDoc.InsertPages pdDoc.GetNumPages() - 1, pdInsert, 0, pdInsert.GetNumPages(), False
        pdInsert.Close
    End If
Next

' Save combined PDF and close original PDF file we used to combine all PDFs
pdDoc.Save 1, combinedPdf
pdDoc.Close

' Get page numbers for bookmarks and create pdf_page_reference.txt
Dim ts, pageOffset, pageOffsets, numPages, bmName
Set ts = fso.CreateTextFile(fso.BuildPath(folder.Path, "pdf_page_reference.txt"), True)
Set pageOffsets = CreateObject("Scripting.Dictionary")

ts.WriteLine "Page Reference for " & combinedPdf
ts.WriteLine "Generated: " & Now
ts.WriteLine ""
ts.WriteLine "Section starting pages:"
ts.WriteLine ""

pageOffset = 0

' Calculate page offsets for each PDF section
For i = 0 To pdfs.Count - 1
    bmName = pdfs(keys(i))
    pageOffsets.Add i, pageOffset
    ts.WriteLine "Page " & (pageOffset + 1) & ": " & bmName
    
    ' Get number of pages in this PDF
    Set pdInsert = CreateObject("AcroExch.PDDoc")
    If pdInsert.Open(keys(i)) Then
        numPages = pdInsert.GetNumPages()
        pdInsert.Close
        pageOffset = pageOffset + numPages
    Else
        ' If we can't open the PDF, estimate 1 page
        pageOffset = pageOffset + 1
    End If
Next

ts.WriteLine ""
ts.WriteLine "Total pages in combined PDF: " & pageOffset
ts.Close

' Bookmark creation with proper destinations
pdDoc.Open combinedPdf
On Error Resume Next
Dim jso, bm
Set jso = pdDoc.GetJSObject

If Not jso Is Nothing Then
    ' Create bookmarks in reverse order
    For i = pdfs.Count - 1 To 0 Step -1
        bmName = pdfs(keys(i))
        pageOffset = pageOffsets(i)
        
        If BMType = 1 Then
            ' Create bookmark using this.pageNum
            jso.bookmarkRoot.createChild bmName, "this.pageNum = "&pageOffset&";"
        Else
            ' Create bookmark using bm.Destination
            Set bm = jso.bookmarkRoot.createChild(bmName)
            If Not bm Is Nothing Then
                ' Set destination using pageNumToDest
                bm.destination = jso.pageNumToDest(pageOffset)
                'WScript.Echo "Bookmark created: " & bmName & " -> Page " & (pageOffset + 1)
            Else
                WScript.Echo "Failed to create bookmark: " & bmName
            End If
        End If
    Next
Else
    WScript.Echo "JavaScript object not available - cannot create bookmarks"
End If

' Save updated combined PDF
pdDoc.Save 1, combinedPdf
pdDoc.Close
app.Exit

WScript.Echo "Combined PDF created: " & combinedPdf & vbCrLf & _
             "Page reference saved to: pdf_page_reference.txt" & vbCrLf & _
             "PDF files combined: " & pdfs.Count & vbCrLf