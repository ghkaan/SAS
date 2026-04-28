' This script combines separate RTF files into a single RTF file with bookmarks, performing the following actions:
' 1. Retrieves all RTF files in the current folder.
' 2. Creates "combined.rtf".
' 3. Inserts all source RTF files into "combined.rtf".
' 4. Generates bookmarks for each section based on original filenames (without extensions). These can be accessed using Ctrl+G.
' v1.0, 09Nov2025, Anton Kamyshev

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

WScript.Echo "Combine RTF files in current folder." & vbCrLf & "Press Ok to continue."

currentFolder = shell.CurrentDirectory
Set outputFile = fso.CreateTextFile("combined.rtf", True)

' Write RTF header
outputFile.Write "{\rtf1\ansi\deff0" & vbCrLf

fileCount = 0
For Each file In fso.GetFolder(currentFolder).Files
    If LCase(fso.GetExtensionName(file.Name)) = "rtf" And Left(file.Name, 1) <> "~" And file.Name <> "combined.rtf" Then
        If file.Size > 0 Then
            On Error Resume Next
            Set inputFile = fso.OpenTextFile(file.Path, 1)
            fileContent = inputFile.ReadAll
            inputFile.Close
            
            If Err.Number = 0 Then
                ' Extract content between the first { and last }
                startPos = InStr(fileContent, "{\rtf1")
                If startPos > 0 Then
                    contentStart = InStr(startPos + 1, fileContent, "{")
                    contentEnd = InStrRev(fileContent, "}")
                    
                    If contentStart > 0 And contentEnd > contentStart Then
                        docContent = Mid(fileContent, contentStart, contentEnd - contentStart)
                        
                        ' Clean bookmark name - remove invalid characters
                        'bookmarkName = "BM_" & Replace(Replace(Replace(file.Name, ".rtf", ""), " ", "_"), ".", "_")
                        bookmarkName = Replace(Replace(Replace(file.Name, ".rtf", ""), " ", "_"), ".", "_")
                        
                        ' Replace only the specific IDX bookmark and remove all others
                        docContent = ReplaceSpecificBookmark(docContent, bookmarkName)
                        
                        ' Force page break before each file (except the first one)
                        If fileCount > 0 Then
                            outputFile.Write "\sect\sectd" & vbCrLf & vbCrLf
                        End If
                        
                        ' Write the content
                        outputFile.Write docContent & vbCrLf & vbCrLf
                        
                        fileCount = fileCount + 1
                        'WScript.Echo "Processed: " & file.Name & " (bookmark: " & bookmarkName & ")"
                    Else
                        WScript.Echo "Skipped - invalid RTF structure: " & file.Name
                    End If
                Else
                    WScript.Echo "Skipped - not a valid RTF file: " & file.Name
                End If
            Else
                WScript.Echo "Error reading file: " & file.Name
            End If
            On Error Goto 0
        Else
            WScript.Echo "Skipped - empty file: " & file.Name
        End If
    End If
Next

' Write RTF footer
outputFile.Write "}" & vbCrLf
outputFile.Close

WScript.Echo "Successfully combined " & fileCount & " files into combined.rtf with bookmarks"

' Function to replace only the specific IDX bookmark and remove all others
Function ReplaceSpecificBookmark(content, bookmarkName)
    ' First, remove all bookmarks except the specific IDX one we want to replace
    content = RemoveAllBookmarksExceptIDX(content)
    
    ' Now replace the specific IDX bookmark with the correct bookmark name
    content = Replace(content, "{\*\bkmkstart IDX}", "{\*\bkmkstart " & bookmarkName & "}")
    content = Replace(content, "{\*\bkmkend IDX}", "{\*\bkmkend " & bookmarkName & "}")
    
    ReplaceSpecificBookmark = content
End Function

' Function to remove all bookmarks except the specific IDX bookmark
Function RemoveAllBookmarksExceptIDX(content)
    ' Remove all bkmkstart tags except {\*\bkmkstart IDX}
    pos = 1
    Do While True
        startPos = InStr(pos, content, "{\*\bkmkstart")
        If startPos = 0 Then Exit Do
        
        endPos = InStr(startPos, content, "}")
        If endPos = 0 Then Exit Do
        
        bookmarkTag = Mid(content, startPos, endPos - startPos + 1)
        
        ' Only keep {\*\bkmkstart IDX}, remove all others
        If bookmarkTag <> "{\*\bkmkstart IDX}" Then
            content = Left(content, startPos - 1) & Mid(content, endPos + 1)
        Else
            pos = endPos + 1
        End If
    Loop
    
    ' Remove all bkmkend tags except {\*\bkmkend IDX}
    pos = 1
    Do While True
        startPos = InStr(pos, content, "{\*\bkmkend")
        If startPos = 0 Then Exit Do
        
        endPos = InStr(startPos, content, "}")
        If endPos = 0 Then Exit Do
        
        bookmarkTag = Mid(content, startPos, endPos - startPos + 1)
        
        ' Only keep {\*\bkmkend IDX}, remove all others
        If bookmarkTag <> "{\*\bkmkend IDX}" Then
            content = Left(content, startPos - 1) & Mid(content, endPos + 1)
        Else
            pos = endPos + 1
        End If
    Loop
    
    RemoveAllBookmarksExceptIDX = content
End Function