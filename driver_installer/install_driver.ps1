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
} else {
    Write-Output 'Driver do fabricante não encontrado, continuando...'
}

foreach ($device_id in $device_ids) {
	$device_vid = $device_id.VID
	$device_pid = $device_id.PID

	$devices = Get-PnpDevice | Where-Object {
		$_.InstanceId -match "VID_$device_vid&PID_$device_pid" 
	}

    if ($devices) {
        Write-Output 'Substituindo driver para o dispositivo:'
        Write-Output "  VID=$device_vid PID=$device_pid"

        foreach ($device in $devices) {
            pnputil /remove-device $device.InstanceId /force
        }

        .\wdi-simple.exe --stealth-cert -t 0 `
            -n $name `
            -m $manufacturer `
            -v 0x$device_vid `
            -p 0x$device_pid

        pnputil /scan-devices
    }
}
