<powershell>
Write-Host "Delete any existing WinRM listeners"
winrm delete winrm/config/listener?Address=*+Transport=HTTP  2>$Null
winrm delete winrm/config/listener?Address=*+Transport=HTTPS 2>$Null

Write-Host "Configure UAC to allow privilege elevation in remote shells"
$Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$Setting = 'LocalAccountTokenFilterPolicy'
Set-ItemProperty -Path $Key -Name $Setting -Value 1 -Force

Write-Host "Turn off PowerShell execution policy restrictions"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine

Write-Host "Generate SSL certificate"
$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "vbo365"
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force

Write-Host "Create a new WinRM listener and configure"
winrm create winrm/config/listener?Address=*+Transport=HTTP
winrm set "winrm/config" '@{MaxTimeoutms="7200000"}'
winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
winrm set "winrm/config/client" '@{AllowUnencrypted="false"}'
winrm set "winrm/config/client/auth" '@{Basic="true"}'
winrm set "winrm/config/service" '@{MaxConcurrentOperationsPerUser="12000"}'
winrm set "winrm/config/service" '@{AllowUnencrypted="false"}'
winrm set "winrm/config/service/auth" '@{Basic="true"}'
winrm set "winrm/config/service/auth" '@{CredSSP="true"}'
winrm set "winrm/config/listener?Address=*+Transport=HTTPS" "@{Port=`"5986`";Hostname=`"vbo365`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}"

Write-Host "Configure and restart the WinRM Service; enable the required firewall exception"
Stop-Service -Name WinRM
Set-Service -Name WinRM -StartupType Automatic
#netsh advfirewall firewall set rule name="Windows Remote Management (HTTPS-In)" new action=allow localip=any remoteip=any
netsh advfirewall firewall set rule group="Windows Remote Management (HTTPS-In)" new enable=yes
netsh firewall add portopening TCP 5986 "Port 5986"
Start-Service -Name WinRM
</powershell>