Set-StrictMode -Version Latest
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Diretório temporário onde serão extraídos os arquivos do instalador
$prefix = "$env:TEMP\maistodos_pos_installer"

# Identificadores personalizados para o driver WinUSB da impressora
$printer_manufacturer = 'MaisTODOS'
$printer_name = 'MaisTODOS POS Series Printer'

# --- Mapeamento de dispositivos conhecidos ---

$pos_device_ids = @{
    ingenico = @(
    )
    gertec = @(
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
            "gertec" {
                if (Find-InstalledPackage -Pattern 'Gertec*') {
                    Write-Output 'Driver da maquininha Gertec já está instalado.'
                } else {
                    Write-Output 'Instalando driver da maquininha Gertec...'
                    $install_string = ".\gertec-installer.exe"
                }
            }
            "ingenico" {
                if (Find-InstalledPackage -Pattern 'Ingenico*') {
                    Write-Output 'Driver da maquininha Ingenico já está instalado.'
                } else {
                    Write-Output 'Instalando driver da maquininha Ingenico...'
                    $install_string = ".\ingenico-installer.exe"
                }
            }
        }

        if ($install_string) {
            Start-Process -FilePath $install_string -ArgumentList '/S' -Wait
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
    if ($driver_package = Find-InstalledPackage -Pattern "POS Series Printer Driver*") {
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

        & ".\wdi-simple.exe" --stealth-cert -t 0 `
            -n $printer_name `
            -m $printer_manufacturer `
            -v 0x$($printer.vid) `
            -p 0x$($printer.pid)
    }
}


function Install-FiservAgent {
    Copy-Item -Path .\fiserv -Destination C:\AgenteCliSiTef -Recurse
    pushd C:\AgenteCliSiTef
    .\CertMgr.exe -add .\ca_cert.pem -all -s -r localMachine root | Out-Null
    .\agenteCliSiTef.exe -i | Out-Null
    net start AgenteCliSiTef | Out-Null
    popd
}


function Main {
    Set-Location $prefix

    pnputil /scan-devices | Out-Null

    $any_failure = $false

    Write-Output 'Buscando maquininha conectada...'
    if ($pos_devices = Find-PosDevices) {
        Install-PosDrivers -Devices $pos_devices
    } else {
        Write-Output 'Maquininha não encontrada.'
        $any_failure = $true
    }

    if (Get-WmiObject -Class Win32_Service -Filter 'Name="AgenteCliSiTef"') {
        Write-Output 'Agente Fiserv SiTef já está instalado.'
    } else {
        Write-Output 'Instalando Agente Fiserv SiTef...'
        Install-FiservAgent
    }

    Write-Output 'Buscando impressora conectada...'
    if ($printers = Find-PrinterDevices) {
        Replace-PrinterDrivers -Printers $printers
        pnputil /scan-devices | Out-Null
    } else {
        Write-Output 'Impressora não encontrada.'
        $any_failure = $true
    }

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
