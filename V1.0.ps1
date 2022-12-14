$o = new-object -comobject outlook.application
$1 = "C:\Program Files\Google\Chrome\Application\chrome.exe"
Set-Alias -Name chrome -Value $1
$path = "PATH"
$XL = New-Object -ComObject Excel.Application
$XL.Visible = $false                                         # Show application window
$xlFixedFormat = [Microsoft.Office.Interop.Excel.XlFileFormat]::xlOpenXMLWorkbook

 
 Add-Type -AssemblyName System.Windows.Forms|out-null
 $MSWord = New-Object -COMObject word.application 
 $a =$MSWord.EmailOptions.EmailSignature.NewMessageSignature
 $b =$MSWord.EmailOptions.EmailSignature.ReplyMessageSignature

 if(($a -ne '') -or ($b -ne '')){$result = [System.Windows.Forms.MessageBox]::Show("Outlook Signature not empty. The script can do this for you.`nIt will be restored after conversion.`nWould you like that?",'WARNING',[System.Windows.MessageBoxButton]::OKCancel ,[System.Windows.MessageBoxImage]::Warning )
 if ($result -eq 'OK'){
 $MSWord.EmailOptions.EmailSignature.NewMessageSignature=''
 $MSWord.EmailOptions.EmailSignature.ReplyMessageSignature=''
 }}

$input = 'INPUT_CSV\New.csv'  
$output_excel = 'OUTPUT_EXCEL\New.xlsx' 

cd $path
function att_inc
    {
        $attname = $msgDirectory + '\Converted\' + $msgBaseName + '\' + $_.FileName.substring(0,$_.Filename.Lastindexof('.')) + '-' + $counter + $_.FileName.substring($_.Filename.Lastindexof('.'))
        main
    }


$output = @()


gc test.csv|Select -skip 1|%{$_|Add-Member -MemberType NoteProperty -Name 'BaseName' -Value $_.substring($_.Lastindexof('\')+1).substring(0, $_.substring($_.Lastindexof('\')+1).Lastindexof('.'));
$_|Add-Member -MemberType NoteProperty -Name 'FileName' -Value $_.substring($_.Lastindexof('\')+1);
$_|Add-Member -MemberType NoteProperty -Name 'FullName' -Value $_;
$_|Add-Member -MemberType NoteProperty -Name 'Folder' -Value $_.substring(0, $_.Lastindexof('\'));
$_|Add-Member -MemberType ScriptProperty -Name 'Attachments' -Value {if($msg.Attachments.Count -eq 0){'NO'}elseif($msg.Attachments.Count -ge 1){'Yes'}};
$_|Add-Member -MemberType ScriptProperty -Name 'New Loc' -Value {if($msg.Attachments.Count -eq 0){$msgDirectory + '\Converted\'}elseif($msg.Attachments.Count -ge 1){$msgDirectory + '\Converted\' + $msgBaseName + '\'}};

$output += $_|Select FullName, FileName, "New Loc",  Attachments

$msgBaseName = $_.BaseName
$msgFullname = $_.FullName
$msgDirectory = $_.Folder
$msgName = $_.Filename
$msg = $o.CreateItemFromTemplate($msgFullname)
if($msg.Attachments.Count -eq 0){
if((test-path ($msgDirectory + '\Converted\')) -eq $false){New-Item -ItemType Directory -Path $msgDirectory -Name '\Converted\'|Out-Null}
$htmlname = $msgDirectory + '\Converted\' + ($msgName -replace '.msg', '.html')
$pdfname = $msgDirectory + '\Converted\' + ($msgName -replace '.msg', '.pdf')
$msg.SaveAs($htmlname, 5)
chrome --headless --disable-gpu --print-to-pdf=$pdfname  $htmlname --print-to-pdf-no-header
start-sleep -Milliseconds 500
Remove-Item -Path $htmlname
Remove-Item -Path ($msgDirectory + '\Converted\' + ($msgBaseName + '_files')) -Recurse -Force
}
else
{
if((test-path ($msgDirectory + '\Converted\')) -eq $false){New-Item -ItemType Directory -Path $msgDirectory -Name '\Converted\'|Out-Null}
if((test-path ($msgDirectory + '\Converted\' + $msgBaseName)) -eq $false){New-Item -ItemType Directory -Path ($msgDirectory + '\Converted\') -Name $msgBaseName|out-null}
$htmlname = $msgDirectory + '\Converted\' + $msgBaseName + '\' + ($msgName -replace '.msg', '.html')
$pdfname =  $msgDirectory + '\Converted\' + $msgBaseName + '\' + ($msgName -replace '.msg', '.pdf')
$msg.SaveAs($htmlname, 5)

 $msg.Attachments|%{
    $counter = 0  
    $attname = $msgDirectory + "\Converted\" +$msgBaseName + '\' + $_.FileName      
            function main {
                if((test-path $attname) -eq $false){
                $_.SaveAsFile($attname)
                } 
                    else {
                        $counter++
                        att_inc
                         }
                         }
            main
}
chrome --headless --disable-gpu --print-to-pdf=$pdfname  $htmlname --print-to-pdf-no-header
Start-Sleep -Milliseconds 500
Remove-Item -Path $htmlname
Remove-Item -Path ($msgDirectory + '\Converted\' + $msgBaseName + '\' + ($msgBaseName + '_files')) -Recurse -Force
}
}

$output|Export-Csv -path $input -NoTypeInformation

$xlBook = $XL.Workbooks.Open($input)                                   # Open workbook

# Needs option "Trust Access to the VBA Project object model" (registry value AccessVBOM) set and macros enabled!
$xlModule = $xlBook.VBProject.VBComponents.Add(1)  # New 1=Module, 2=Class, 3=MSForm
$xlModule.CodeModule.AddFromString(@"
Sub Test()

For Each Cell In Range(Range("B2"), Range("C2").End(xlDown))
If Not IsEmpty(Cell) Then
ActiveSheet.Hyperlinks.Add Anchor:=Cell, Address:=Cell.Formula
End If
Next

End Sub
"@
)
$XL.Run('Test')                 # Call Test Macro

$XL.DisplayAlerts = $false                         
$xlBook.SaveAs($output_excel, $xlFixedFormat )
$xlBook.Close()
$XL.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject([System.__ComObject]$XL)|out-null
[GC]::Collect()


ri $input

[System.Windows.Forms.MessageBox]::Show("Press OK to Continue")|out-null
 $MSWord.EmailOptions.EmailSignature.NewMessageSignature=$a
 $MSWord.EmailOptions.EmailSignature.ReplyMessageSignature=$b

 ii $output_excel
