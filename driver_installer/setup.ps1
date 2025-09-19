Set-StrictMode -Version Latest
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Diretório temporário onde serão extraídos os arquivos do instalador
$prefix = 'C:\MaisTODOS'

# Identificadores personalizados para o driver WinUSB da impressora
$printer_manufacturer = 'MaisTODOS'
$printer_name = 'MaisTODOS POS Series Printer'

# --- Mapeamento de dispositivos conhecidos ---

$pos_device_ids = @{
    ingenico = @(
        @{ vid = '079B'; pid = '0028' }
        @{ vid = '0B00'; pid = '00A2' }
    )
    gertec = @(
        @{ vid = '1753'; pid = 'C902' }
    )
}

$printer_device_ids = @(
    @{ vid = '0416'; pid = '5011' }
    @{ vid = '0456'; pid = '0808' }
    @{ vid = '0483'; pid = '070B' }
    @{ vid = '0519'; pid = '2015' }
    @{ vid = '28E9'; pid = '0289' }
)


# --- Implementação: Evitar alterações a partir desta linha ---


function Find-InstalledPackage ($Pattern) {
    try {
        return Get-Package $Pattern
    } catch {
        return $null
    }
}


function Uninstall-Package ($Package) {
    $uninstall_string = $Package.Meta.Attributes['QuietUninstallString']
    Start-Process -FilePath cmd.exe -ArgumentList '/c',$uninstall_string -Wait
}


function Find-PosDevices {
    $device_brands = New-Object System.Collections.Generic.HashSet[string]

    foreach ($device_brand in $pos_device_ids.Keys) {
        foreach ($device_id in $pos_device_ids[$device_brand]) {
            $devices = Get-PnpDevice | Where-Object {
                $_.InstanceId -match "VID_$($device_id.vid)&PID_$($device_id.pid)" 
            }

            if ($devices) {
                $device_brands.Add($device_brand)
            }
        }
    }

    return $device_brands
}


function Install-PosDrivers ($Devices) {
    foreach ($device_brand in $Devices) {
        $install_string = $null

        switch ($device_brand) {
            'gertec' {
                if (Find-InstalledPackage -Pattern 'Gertec-Full-Installer*' -and ) {
                    Write-Output 'Driver da maquininha Gertec já está instalado.'
                } else {
                    Push-Location .\gertec
                    Write-Output 'Instalando driver da maquininha Gertec...'
                    Start-Process -FilePath '.\Gertec-Full-Installer_2.2.2.0.exe' -ArgumentList '/S' -Wait
                    Start-Process -FilePath '.\Gertec_Certificates_Installer_1.2.0.0.exe' -Wait
                    Start-Process -FilePath '.\Gertec_PIN_pad_Driver_Installer_2.7.3.0.exe' -ArgumentList '/s','/d','/f:1' -Wait
                    Start-Process -FilePath '.\Gertec-WebAPI_Installer_2.2.0.1.exe' -ArgumentList '/S' -Wait
                    Start-Process -FilePath '.\SerialDevMan_Setup_1.2.0.5.exe' -ArgumentList '/S'
                    Copy-Item -Path '.\gpinpad.dll' -Destination 'C:\Windows\gpinpad.dll' -Force
                    Pop-Location
                }
            }
            'ingenico' {
                if (Find-InstalledPackage -Pattern 'Ingenico USB Drivers*') {
                    Write-Output 'Driver da maquininha Ingenico já está instalado.'
                } else {
                    Push-Location .\ingenico
                    Write-Output 'Instalando driver da maquininha Ingenico...'
                    Start-Process -FilePath '.\IngenicoUSBDrivers_3.40_setup_SIGNED.exe' -ArgumentList '/S' -Wait
                }
            }
        }
    }
}


function Find-PrinterDevices {
    $found = @()

    foreach ($device_id in $printer_device_ids) {
        $devices = Get-PnpDevice | Where-Object {
            $_.InstanceId -match "VID_$($device_id.vid)&PID_$($device_id.pid)" 
        }

        if ($devices) {
            $found += @{
                vid = $device_id.vid
                pid = $device_id.pid
                devices = $devices
            }
        }
    }

    return $found
}


function Replace-PrinterDrivers ($Printers) {
    if ($driver_package = Find-InstalledPackage -Pattern 'POS Series Printer Driver*') {
        Write-Output 'Removendo driver do fabricante da impressora...'
        Uninstall-Package -Package $driver_package
    }

    foreach ($printer in $Printers) {
        Write-Output "Impressora encontrada: VID=$($printer.vid) PID=$($printer.pid)"

        $already_installed = $false
        foreach ($device in $printer.devices) {
            if ($device.Manufacturer -eq $printer_manufacturer) {
                $already_installed = $true
            }
        }
        if ($already_installed) {
            Write-Output 'Driver já está instalado.'
            continue
        }

        Write-Output 'Instalando driver da impressora...'

        foreach ($device in $printer.devices) {
            pnputil /remove-device $device.InstanceId /force | Out-Null
        }

        & '.\wdi-simple.exe' --stealth-cert -t 0 `
            -n $printer_name `
            -m $printer_manufacturer `
            -v 0x$($printer.vid) `
            -p 0x$($printer.pid)
    }
}


function Install-FiservAgent {
    Push-Location .\fiserv
    .\CertMgr.exe -add .\ca_cert.pem -all -s -r localMachine root
    .\agenteCliSiTef.exe -i
    net start AgenteCliSiTef
    Pop-Location
}

function Uninstall-FiservAgent {
    Push-Location .\fiserv
    .\agenteCliSiTef.exe -u
    Pop-Location
}

function Main {
    Set-Location $prefix

    # Precisamos parar o agente da fiserv para poder extrair o zip
    try { net stop AgenteCliSiTef 2> $null } catch {}

    Expand-Archive -Path .\installers.zip -DestinationPath . -Force

    Write-Output 'Instalando Agente Fiserv SiTef...'
    Install-FiservAgent

    pnputil /scan-devices | Out-Null

    $any_failure = $false

    Write-Output 'Buscando maquininha conectada...'
    if ($pos_devices = Find-PosDevices) {
        Install-PosDrivers -Devices $pos_devices
    } else {
        Write-Output 'Maquininha não encontrada.'
        $any_failure = $true
    }

    Write-Output 'Buscando impressora conectada...'
    if ($printers = Find-PrinterDevices) {
        Replace-PrinterDrivers -Printers $printers
    } else {
        Write-Output 'Impressora não encontrada.'
        $any_failure = $true
    }

    pnputil /scan-devices | Out-Null

    if ($any_failure) {
        Write-Output 'Entre em contato com o nosso suporte.'
    } else {
        Write-Output 'Instalação concluída com sucesso!'
    }
}


try {
    Main
} catch {
    Write-Error $_
}


Write-Output 'Pressione [Enter] para fechar.'
Read-Host | Out-Null
