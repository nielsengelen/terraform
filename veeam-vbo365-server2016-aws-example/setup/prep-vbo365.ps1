# Install Chocolatey and .NET framework 4.7.2
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install dotnet4.7.2 -y

# Restart server to finalize .NET framework 4.7.2 installation
Write-Host "Rebooting server"
Restart-Computer -Force