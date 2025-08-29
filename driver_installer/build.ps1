$embedded_files = @{
    'wdi-simple.exe' = '.\wdi-simple.exe';
}

ps2exe '.\install_driver.ps1' '.\install_driver.exe' `
    -verbose `
    -requireAdmin `
    -embedFiles $embedded_files
