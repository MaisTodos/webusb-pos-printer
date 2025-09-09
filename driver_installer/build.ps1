$embedded_files = @{ 'C:\MaisTODOS\installers.zip' = '.\installers.zip' }
ps2exe '.\setup.ps1' '.\setup.exe' -verbose -requireAdmin -embedFiles $embedded_files
