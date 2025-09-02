Set-StrictMode -Version Latest
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$manufacturer = 'MaisTODOS'
$name = 'MaisTODOS POS Series Printer'
$device_ids = @(
    @{ VID = '0416'; PID = '5011' },
    @{ VID = '0456'; PID = '0808' },
    @{ VID = '0483'; PID = '070b' },
    @{ VID = '0519'; PID = '2015' },
    @{ VID = '28e9'; PID = '0289' }
)


function Find-Existing-Devices {
    $found = @()

    foreach ($device_id in $device_ids) {
        $devices = Get-PnpDevice | Where-Object {
            $_.InstanceId -match "VID_$($device_id.VID)&PID_$($device_id.PID)" 
        }

        if ($devices) {
            $found += @{
                VID = $device_id.VID;
                PID = $device_id.PID;
                DEVICES = $devices
            }
        }
    }

    return $found
}


function Uninstall-Manufacturer-Driver {
    try {
        $driver_package = Get-Package "POS Series Printer Driver*"
    } catch {
        $driver_package = $null
    }

    if ($driver_package) {
        Write-Host 'Driver do fabricante encontrado, desinstalando...'
        $uninstall_string = $driver_package.Meta.Attributes['QuietUninstallString']
        Start-Process -FilePath cmd.exe -ArgumentList '/c',$uninstall_string -Wait
    }
}


function Replace-Device-Driver {
    param (
        $found_device
    )

    $device_vid = $found_device.VID
    $device_pid = $found_device.PID
    $devices = $found_device.DEVICES

    Write-Host 'Substituindo driver para o dispositivo:'
    Write-Host "  VID=$device_vid PID=$device_pid"

    foreach ($device in $devices) {
        pnputil /remove-device $device.InstanceId /force | Out-Null
    }

    .\wdi-simple.exe --stealth-cert -t 0 `
        -n $name `
        -m $manufacturer `
        -v 0x$device_vid `
        -p 0x$device_pid
}


function Main {
    pnputil /scan-devices | Out-Null

    $found_devices = Find-Existing-Devices

    if ($found_devices) {
        Uninstall-Manufacturer-Driver

        foreach ($found_device in $found_devices) {
            Replace-Device-Driver $found_device
        }

        pnputil /scan-devices | Out-Null

        Write-Host 'Drivers instalados com sucesso!'
    } else {
        Write-Error 'Nenhuma impressora conhecida foi encontrada.'
    }
}

try {
    Main
} catch {
    Write-Error $_
}

Read-Host -Prompt 'Pressione Enter para fechar' | Out-Null
