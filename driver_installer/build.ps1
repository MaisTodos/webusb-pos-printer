$prefix = "C:\MaisTODOS"

$embedded_files = @{
    "$prefix\wdi-simple.exe" = '.\installers\wdi-simple.exe'
    "$prefix\gertec-installer.exe" = '.\installers\gertec-installer.exe'
    "$prefix\ingenico-installer.exe" = '.\installers\ingenico-installer.exe'
    "$prefix\agenteCliSiTef.exe" = '.\installers\fiserv\agenteCliSiTef.exe'
    "$prefix\ca_cert.pem" = '.\installers\fiserv\ca_cert.pem'
    "$prefix\CertMgr.exe" = '.\installers\fiserv\CertMgr.exe'
}

ps2exe '.\setup.ps1' '.\setup.exe' `
    -verbose `
    -requireAdmin `
    -embedFiles $embedded_files
