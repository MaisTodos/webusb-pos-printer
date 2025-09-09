$prefix = "$env:TEMP\maistodos_pos_installer"

$embedded_files = @{
    "$prefix\wdi-simple.exe" = '.\installers\wdi-simple.exe'
    "$prefix\gertec-installer.exe" = '.\installers\gertec-installer.exe'
    "$prefix\ingenico-installer.exe" = '.\installers\ingenico-installer.exe'
    "$prefix\fiserv\agenteCliSiTef.exe" = '.\installers\fiserv\agenteCliSiTef.exe'
    "$prefix\fiserv\ca_cert.pem" = '.\installers\fiserv\ca_cert.pem'
    "$prefix\fiserv\CertMgr.exe" = '.\installers\fiserv\CertMgr.exe'
}

ps2exe '.\setup.ps1' '.\setup.exe' `
    -verbose `
    -requireAdmin `
    -embedFiles $embedded_files
