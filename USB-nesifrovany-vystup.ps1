##############################################################################################
# KRII STANICE - Offline Flash Disk 
# Autor: MiJa, verze: 1.1
# Info: Skript pro nastaveni nesifrovaneho vystupu a pismene na USB flash disku 
##############################################################################################
function overeni 
{
Param($pismeno)
$pole =@("C","D","K","L","O","R","X","P")
if($pole -contains $pismeno ) {
    Write-host ("Zadali jste nepovolene pismeno") -BackgroundColor red -ForegroundColor yellow
    $pismeno = Read-Host "Zadejte pismeno flash disku znovu"
    $pismeno = overeni($pismeno)
    $pismeno=$pismeno.ToUpper()
    }
 return $pismeno
}

###################################################################################################################################################################
$trace = $MYINVOCATION.MyCommand.path
$path = split-path $trace  -resolve

# kontrola opravneni
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-EventLog -LogName KR2log -Source Deploy -EntryType 2 -EventId 10 -Message "Uzivateli zobrazena informace o nutnosti spusteni $(Split-Path $Path -Leaf) v roli spravce."
    Write-Host "`r Nastaveni USB flash disku je možné spouštět pouze v roli správce!`n`nPřihlaste se jako lokální správce (účty AD1, AD2...)" -BackgroundColor $msg_error[0] -ForegroundColor $msg_error[1]
    Open-Dialog -Title 'Nastaveni USB flash disku' -Text "Nastaveni USB flash disku je možné spouštět pouze v roli správce!`n`nPřihlaste se jako lokální správce (účty AD1, AD2...)" -Type Warning -Buttons OK
    Stop-Transcript
    exit
    }

# overeni pripojenych USB
$usb=@()
$usb=$usb + (gwmi win32_diskdrive | ?{$_.interfacetype -eq "USB"})
if ($usb.Count -eq 0){
    Write-Host (" Chyba: Nemate pripojen flash disk! ") -BackgroundColor yellow -ForegroundColor Black
    write-host("")
    Write-Host ("Prosim vlozte flash disk a spuste scrip znovu ") 
    Read-Host("Stiskem klavesy Enter zavrete dialogove okno")
    exit
    }
elseif($usb.Count -ge 2){
    Write-Host (" Chyba: Mate pripojeno vice jak jeden flash disk! ") -BackgroundColor yellow -ForegroundColor Black
    write-host("")
    Write-Host ("Prosim vyjmete prebyvajici disky a spuste scrip znovu ") 
    Read-Host("Stiskem klavesy Enter zavrete dialogove okno")
    exit
    }

#overeni zda je T: obsazeno
if(Get-ItemProperty -Path 'HKLM:\SYSTEM\MountedDevices\' -Name '\dosdevices\T:') {
    Write-Host "Pismeno [T:] je jiz obsazeno jinym zarizenim." -BackgroundColor yellow -ForegroundColor Black
    write-host("")
    write-Host "`rChcete pripojenemu flash disku pridat pismeno T: (P) a prepsat tak oznaceni uz 
                `rzavedeneho zarizeni nebo mu pridat nove pismeno (N)? (Vychozi je novy)"
    $rozhodnuti = read-host "( p / n )"
    if ($rozhodnuti -eq "" -or $rozhodnuti -eq "n"){
         write-host("############################        POZOR        ##############################")  -ForegroundColor red
         write-host(" ZAKAZANA PISMENA PRO OZNACENI FLASH DISKU: [C:] [D:] [K:] [L:] [X:] [R:] [P:] ")  -ForegroundColor red
         write-host("###############################################################################") -ForegroundColor red
         write-host("")
        }
    switch ($rozhodnuti) {
        n { $pismeno = read-host "Zadejte pismeno flash disku";$pismeno=$pismeno.ToUpper();$pismeno = overeni($pismeno);; $pismeno = $pismeno+":"}
        p { $pismeno = "T:"}
        default {$pismeno = read-host "Zadejte pismeno flash disku";$pismeno=$pismeno.ToUpper();$pismeno = overeni($pismeno); $pismeno = $pismeno+":"}
        }
    }
else{
    $pismeno = "T:"
    }

# nastaveni pismene USB
        $temp = Get-WmiObject win32_volume | Where-Object {$_.DriveType -eq '2'}
        try {Set-WmiInstance -InputObject $temp -Arguments @{DriveLetter=$pismeno} -ErrorAction Stop}
        catch {$out = $null; continue}


 #nastaveni nesifrovaneho vystupu
  if(Test-Path "$path\Sources\PCS1\10_Set_Drive.sir") {
        $Env:KEY_NAME = "$((Get-ItemProperty 'HKLM:\SOFTWARE\Wow6432Node\S.ICZ\CharonII\Common').OfficeKey)-MED"        
        $Env:ENC = '0'
        $Env:DISK = $pismeno
        Write-Host "Nastavuji sifrovani pevneho disku $Env:DISK"
        & sirsetup.exe -E "$path\Sources\PCS1\10_Set_Drive.sir" | Out-Null
        }
    else {
        write-Host("Pri nastaveni USB flash disku vznikla chyba. Zkontrolujte KR2log $path nebyl nalezen soubor: Drive_Set_Noncrypt.sir.") 
        Read-Host("Stiskem klavesy Enter zavrete dialogove okno")
        }

# kontrola nastaveni
        $temp = (Get-WmiObject win32_volume | Where-Object {$_.DriveType -eq '2'}).DriveLetter
        if($temp -contains $pismeno) {
           Write-EventLog -LogName KR2log -Source Deploy -EntryType Information -EventId 1004 -Message "Skript $(Split-Path $path -Leaf)`nNastaveni USB flash disku uspesne dokonceno."
           write-Host("Nastaveni USB flash disku uspesne dokonceno")
           Read-Host("Stiskem klavesy Enter zavrete dialogove okno")
           }
        else {
           Write-EventLog -LogName KR2log -Source Deploy -EntryType Error -EventId 1005 -Message "Skript $(Split-Path $path -Leaf)`nNastaveni USB flash disku selhalo. Zkontrolujte obsah souboru $logfile."
           write-Host("Pri nastaveni USB flash disku vznikla chyba. Zkontrolujte KR2log")
           Read-Host("Stiskem klavesy Enter zavrete dialogove okno")
           }

  