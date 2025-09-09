$prefix = "$env:TEMP\maistodos_pos_installer"

$embedded_files = @{
    "$prefix\wdi-simple.exe" = '.\installers\wdi-simple.exe';
    "$prefix\gertec-installer.exe" = '.\installers\gertec-installer.exe';
    "$prefix\ingenico-installer.exe" = '.\installers\ingenico-installer.exe'
}

ps2exe '.\setup.ps1' '.\setup.exe' `
    -verbose `
    -requireAdmin `
    -embedFiles $embedded_files
