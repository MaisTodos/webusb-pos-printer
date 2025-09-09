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

# Dispositivo local para testes:
# @{ vid = '0BDA'; pid = '554A' }

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
    @{ vid = '0BDA'; pid = '554A' },

    @{ vid = '0416'; pid = '5011' },
    @{ vid = '0456'; pid = '0808' },
    @{ vid = '0483'; pid = '070B' },
    @{ vid = '0519'; pid = '2015' },
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
                if (Find-InstalledPackage -Pattern "Gertec*") {
                    Write-Host "Driver da maquininha Gertec já está instalado."
                } else {
                    Write-Host "Instalando driver da maquininha Gertec..."
                    $install_string = ".\gertec-installer.exe"
                }
            }
            "ingenico" {
                if (Find-InstalledPackage -Pattern "Ingenico*") {
                    Write-Host "Driver da maquininha Ingenico já está instalado."
                } else {
                    Write-Host "Instalando driver da maquininha Ingenico..."
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
                vid = $device_id.vid;
                pid = $device_id.pid;
                devices = $devices
            }
        }
    }

    return $found
}


function Replace-PrinterDrivers ($Printers) {
    if ($driver_package = Find-InstalledPackage -Pattern "POS Series Printer Driver*") {
        Write-Host 'Removendo driver do fabricante da impressora...'
        Uninstall-Package -Package $driver_package
    }

    foreach ($printer in $Printers) {
        Write-Host "Impressora encontrada: VID=$($printer.vid) PID=$($printer.pid)"

        $already_installed = $false
        foreach ($device in $printer.devices) {
            if ($device.Manufacturer -eq $printer_manufacturer) {
                Write-Host $device
                $already_installed = $true
            }
        }
        if ($already_installed) {
            Write-Host 'Driver já está instalado.'
            continue
        }

        Write-Host 'Substituindo driver...'

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


function Main {
    Set-Location $prefix

    pnputil /scan-devices | Out-Null

    $any_failure = $false

    Write-Host "Buscando maquininha conectada..."
    if ($pos_devices = Find-PosDevices) {
        Install-PosDrivers -Devices $pos_devices
    } else {
        Write-Host 'Maquininha não encontrada.'
        $any_failure = $true
    }

    Write-Host "Buscando impressora conectada..."
    if ($printers = Find-PrinterDevices) {
        Replace-PrinterDrivers -Printers $printers
        pnputil /scan-devices | Out-Null
    } else {
        Write-Host 'Impressora não encontrada.'
        $any_failure = $true
    }

    if ($any_failure) {
        Write-Host 'Entre em contato com o nosso suporte.'
    } else {
        Write-Host 'Instalação concluída com sucesso!'
    }
}


try {
    Main
} catch {
    Write-Error $_
}

Write-Host 'Pressione [Enter] para fechar.'
Read-Host | Out-Null
