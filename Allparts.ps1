# Part 1	
# Stop the three services
Stop-Service SCSTermCCS
Stop-Service SCSTermCNSv2
Stop-Service SCSTermMCP

# Function to make application window active:
function Set-WindowStyle {
param(
    [Parameter()]
    [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
    $Style = 'SHOW',
    [Parameter()]
    $MainWindowHandle = (Get-Process -Id $pid).MainWindowHandle
)
    $WindowStates = @{
        FORCEMINIMIZE   = 11; HIDE            = 0
        MAXIMIZE        = 3;  MINIMIZE        = 6
        RESTORE         = 9;  SHOW            = 5
        SHOWDEFAULT     = 10; SHOWMAXIMIZED   = 3
        SHOWMINIMIZED   = 2;  SHOWMINNOACTIVE = 7
        SHOWNA          = 8;  SHOWNOACTIVATE  = 4
        SHOWNORMAL      = 1
    }
    Write-Verbose ("Set Window Style {1} on handle {0}" -f $MainWindowHandle, $($WindowStates[$style]))

    $Win32ShowWindowAsync = Add-Type –memberDefinition @” 
    [DllImport("user32.dll")] 
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
“@ -name “Win32ShowWindowAsync” -namespace Win32Functions –passThru

    $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[$Style]) | Out-Null
}

# Call the process you want the function to run on (i.e. Prowin32 - The message server application):
(Get-Process -Name Prowin32).MainWindowHandle | foreach { Set-WindowStyle MAXIMIZE $_ }

# Give application time to load (5 seconds)
Start-Sleep -s 5

# Press escape 3 times
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")

#Part2

$Username = 'USER'
$Password = 'PASSWORD'
$pass = ConvertTo-SecureString -AsPlainText $Password -Force
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $Username,$pass
# The above requests a username/password then encrypts these credentials into the variable $Cred ready to be called.

Try
{
Invoke-Command -ComputerName "RDSERVER" -credential $cred -ErrorAction Stop -ScriptBlock {Invoke-Expression -Command:"cmd.exe /c 'C:\Users\albacore\Desktop\Server_Reboot.bat'"}
# The above command passes the encrypted credentials to the RDSERVER and runs the .bat file stored on the desktop of the albacore profile
# The .bat file will close the databases wait for a second and then force a restart of the server.
}

Catch 
{
    write-Host "error"
    # If fails this errors and stops the action above.
}

Start-Sleep -s 30
# Powershell will wait for 30 seconds and then continue

while ($alive -ne 1){
# This means that while the variable $alive is not equal to 1 then do the following:

    $alive = 0
    # Sets the $alive variable as 0 initially
    
    $pingCommand = "$socket = new-object System.Net.Sockets.TcpClient(10.0.51.3)"
    $res = invoke-expression $pingCommand
    # This says ping the IP of the RDSERVER
    
    if($res -match("reply from"))
    {
    # If when pinging the IP of the server you get a 'reply from' then we set the $alive variable to 1 (stopping the while loop), and start the below service on the remote computer (RDSERVER)
        $alive = 1
        Invoke-Command -Computer RDSERVER -ScriptBlock {Start-Service "AdminService for OpenEdge 10.2B"}
        
    }
    
    return $alive
    # Returns $alive variables number to the while command to see if it passes teh test or must loop again.
}

Start-Service SCSTermCCS
Start-Service SCSTermCNSv2
Start-Service SCSTermMCP

$run = "M:\progress\bin\prowin32.exe"
# Defines the location of the message server application 
$myarg = '-basekey ini -ininame scsclient -pf mltshed.pf -p msgsrv2.r -param ,0,Y,Y,N,N,Y,Y'
# Is the argument list to apply to the message server application when opening
Start-Process $run -ArgumentList $myarg
# This starts the process (message server application) and applies the arguments (from the arguments list)
