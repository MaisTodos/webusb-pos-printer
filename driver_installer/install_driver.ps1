$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$manufacturer = 'MaisTODOS'
$name = 'MaisTODOS POS Series Printer'
$device_ids = @(
    @{ VID = '0416'; PID = '5011' },
    @{ VID = '0456'; PID = '0808' },
    @{ VID = '0483'; PID = '070b' },
    @{ VID = '0519'; PID = '2015' },
    @{ VID = '28e9'; PID = '0289' }
)

try {
    $driver_package = Get-Package "POS Series Printer Driver*" -ErrorAction Stop
} catch {
    $driver_package = $null
}
if ($driver_package) {
    Write-Output 'Driver do fabricante encontrado, desinstalando...'
    $uninstall_string = $driver_package.Meta.Attributes['QuietUninstallString']
    Start-Process -FilePath cmd.exe -ArgumentList '/c',$uninstall_string -Wait
}

$found = $false

foreach ($device_id in $device_ids) {
	$devices = Get-PnpDevice | Where-Object {
		$_.InstanceId -match "VID_$($device_id.VID)&PID_$($device_id.PID)" 
	}

    if ($devices) {
        $found = $true
        Write-Output 'Substituindo driver para o dispositivo:'
        Write-Output "  VID=$($device_id.VID) PID=$($device_id.PID)"

        foreach ($device in $devices) {
            pnputil /remove-device $device.InstanceId /force
        }

        .\wdi-simple.exe --stealth-cert -t 0 `
            -n $name `
            -m $manufacturer `
            -v 0x$($device_id.VID) `
            -p 0x$($device_id.PID)

        pnputil /scan-devices
    }
}

if ($found) {
    Write-Output 'Drivers instalados com sucesso!'
} else {
    Write-Output 'Nenhuma impressora conhecida foi encontrada.'
}

Read-Host -Prompt 'Pressione Enter para fechar' | Out-Null
