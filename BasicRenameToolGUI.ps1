#Your XAML goes here :)
[void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
$inputXML = @"
<Window x:Class="renametoolbasic.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:renametoolbasic"
        mc:Ignorable="d"
        Title="RenameTool 2023" Height="180" Width="300" ResizeMode="CanMinimize">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="2*"/>
            <ColumnDefinition Width="3*"/>
            <ColumnDefinition Width="95*"/>
        </Grid.ColumnDefinitions>
        <Label Content="Current Name:" HorizontalAlignment="Left" Margin="0,10,0,0" VerticalAlignment="Top" FontWeight="Bold" Grid.ColumnSpan="2" Grid.Column="1"/>
        <Label Content="New Name:" HorizontalAlignment="Left" Margin="1,55,0,0" VerticalAlignment="Top" FontWeight="Bold" Grid.ColumnSpan="2" Grid.Column="1"/>
        <TextBox x:Name="CurrentNameTxtBox" Grid.Column="2" HorizontalAlignment="Left" Margin="90,12,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="160" Height="22"/>
        <TextBox x:Name="NewNameTxtBox" Grid.Column="2" HorizontalAlignment="Left" Margin="90,57,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="160" Height="22"/>
        <CheckBox x:Name="RestartCheckBox" Content="Restart Computer?" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="9,111,0,0" Grid.ColumnSpan="2" FontSize="14" Grid.Column="1"/>
        <Button x:Name="RenameButton" Grid.Column="2" Content="Rename" HorizontalAlignment="Left" Margin="169,106,0,0" VerticalAlignment="Top" FontSize="14" RenderTransformOrigin="0.11,0.489" Width="81"/>

    </Grid>
</Window>
"@ 
 
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
 
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try{
    $Form=[Windows.Markup.XamlReader]::Load( $reader )
}
catch{
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}
 
#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
  
$xaml.SelectNodes("//*[@Name]") | %{
    try {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop}
    catch{throw}
    }
 
Function Get-FormVariables{
if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
get-variable WPF*
}
 
#Get-FormVariables
 
#===========================================================================
# Use this space to add code to the various form elements in your GUI
#===========================================================================
 
$WPFRenameButton.Add_Click({
    $currentName = $WPFCurrentNameTxtBox.Text
    $newName = $WPFNewNameTxtBox.Text
    $restartCheck = $WPFRestartCheckBox.IsChecked


    #check for blanks or if the new name is invalid (length or content) - throw error
    if($currentName -eq ""){
        [Microsoft.VisualBasic.Interaction]::MsgBox("Current Name field cannot be blank.", "OKOnly,SystemModal,Critical", "Error")
    }
    elseif($newName -eq ""){
        [Microsoft.VisualBasic.Interaction]::MsgBox("New name field cannot be blank.", "OKOnly,SystemModal,Critical", "Error")
    }
    elseif($currentName -eq $newName){
        [Microsoft.VisualBasic.Interaction]::MsgBox("New name cannot match current name.", "OKOnly,SystemModal,Critical", "Error")
    }
    elseif($newName -notmatch '^[a-zA-Z\d-]+$'){
        [Microsoft.VisualBasic.Interaction]::MsgBox("New name contains invalid characters.", "OKOnly,SystemModal,Critical", "Error")
    }
    elseif($newName.Length -gt 15){
        [Microsoft.VisualBasic.Interaction]::MsgBox("New name is too long. 15 characters max.", "OKOnly,SystemModal,Critical", "Error")
    }
    else{
        try{
            $newName = $newName.ToUpper() #we like uppercas names.
        }
        catch{
            [Microsoft.VisualBasic.Interaction]::MsgBox("New name error. Please try again", "OKOnly,SystemModal,Critical", "Error")
            exit
        }

        #get account information from currently logged in user - edit this to auto-fill seperate elevated access accounts as needed
        $username = Get-WmiObject -Class win32_computersystem | select username
            if($username.username -eq $null){
                $user = (quser) -replace '\s{2,}', ',' | ConvertFrom-Csv
                $user = $user.USERNAME -replace '>',''
                $credentials = "DOMAIN\$($user)"
            }
            else{
                $username = ($username.username -split '\\')[1]
                $credentials = "DOMAIN\$($username)" 
            }

        if($WPFRestartCheckBox.IsChecked){
            #rename and force restart
                Invoke-Expression "Rename-Computer -ComputerName $currentName -NewName $newName -DomainCredential $credentials -Restart" -ErrorVariable renameResult
                if($renameResult -like "*The user name or password is incorrect*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("Incorrect password. Please try again.", "OKOnly,SystemModal,Critical", "Error") 
                }
                elseif($renameResult -like "*The account already exists*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("$newName already exists. Check AD and try again.", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -like "*cannot be resolved with the exception*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("$currentName could not be found. Check your spelling.", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -like "*The RPC server is unavailable*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("$currentName cannot be reached. Are you sure it is on?", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -like "*Cannot validate argument on parameter*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("You need to enter your password.", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -eq ""){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("Something went wrong. Please try again.", "OKOnly,SystemModal,Critical", "Error")
                }
                else{
                    [Microsoft.VisualBasic.Interaction]::MsgBox("Rename was successful!", "OKOnly,SystemModal,Critical", "Error")
                    $WPFCurrentNameTxtBox.Text = ""
                    $WPFNewNameTxtBox.Text = ""
                    $WPFRestartCheckBox.IsChecked = $False
                }
        }
        else{
            #rename and do NOT restart
            Invoke-Expression "Rename-Computer -ComputerName $currentName -NewName $newName -DomainCredential $credentials" -ErrorVariable renameResult
                if($renameResult -like "*The user name or password is incorrect*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("Incorrect password. Please try again.", "OKOnly,SystemModal,Critical", "Error") 
                }
                elseif($renameResult -like "*The account already exists*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("$newName already exists. Check AD and try again.", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -like "*cannot be resolved with the exception*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("$currentName could not be found. Check your spelling.", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -like "*The RPC server is unavailable*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("$currentName cannot be reached. Are you sure it is on?", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -like "*Cannot validate argument on parameter*"){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("You need to enter your password.", "OKOnly,SystemModal,Critical", "Error")
                }
                elseif($renameResult -eq ""){
                    [Microsoft.VisualBasic.Interaction]::MsgBox("Something went wrong. Please try again.", "OKOnly,SystemModal,Critical", "Error")
                }
                else{
                    [Microsoft.VisualBasic.Interaction]::MsgBox("Rename was successful!", "OKOnly,SystemModal,Critical", "Error")
                    $WPFCurrentNameTxtBox.Text = ""
                    $WPFNewNameTxtBox.Text = ""
                    $WPFRestartCheckBox.IsChecked = $False
                }
        }
    }
})
 
    
#Reference 
 
#Adding items to a dropdown/combo box
    #$vmpicklistView.items.Add([pscustomobject]@{'VMName'=($_).Name;Status=$_.Status;Other="Yes"})
     
#Setting the text of a text box to the current PC name    
    #$WPFtextBox.Text = $env:COMPUTERNAME
     
#Adding code to a button, so that when clicked, it pings a system
# $WPFbutton.Add_Click({ Test-connection -count 1 -ComputerName $WPFtextBox.Text
# })
#===========================================================================
# Shows the form
#===========================================================================
#write-host "To show the form, run the following" -ForegroundColor Cyan
#===========================================================================
#user authentication 
#===========================================================================

# Verify the tool is being ran as admin. Remove this to remove the check
$Role = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

If ($Role -eq $False) {

    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Please run as admin!",0, "Error",16) | Out-Null   
}
else{
$Form.ShowDialog() | out-null
}