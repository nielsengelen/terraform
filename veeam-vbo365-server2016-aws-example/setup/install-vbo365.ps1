# Download Veeam Backup for Microsoft Office 365
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://download2.veeam.com/VeeamBackupOffice365_4.0.0.2516.zip"
$output = "$PSScriptRoot\VBO365.zip"
Invoke-WebRequest -Uri $url -OutFile $output

# Unpack VBO365.zip
Expand-Archive -Force -LiteralPath $output -DestinationPath C:\VBO365Install

# Veeam Backup for Microsoft Office 365 auto install
$jsoninstall = '{ 
   "license": { "src":"veeam_backup_microsoft_office.lic" },
   "steps": [
		{  
		  "src":"Veeam.Backup365_4.0.0.2516.msi",
		  "install":"__file__",
		  "arguments":[  
			 "/qn",
			 "/log __log__",
			 "ACCEPT_EULA=1",
			 "ACCEPT_THIRDPARTY_LICENSES=1"
		  ]
	   },
	   {  
		  "src":"VeeamExplorerForExchange_10.0.0.443.msi",
		  "install":"__file__",
		  "arguments":[  
			 "/qn",
			 "/norestart",
			 "/log __log__",
			 "ACCEPT_EULA=1",
			 "ACCEPT_THIRDPARTY_LICENSES=1"
		  ]
	   },
	   {  
		  "src":"VeeamExplorerForSharePoint_10.0.0.443.msi",
		  "install":"__file__",
		  "arguments":[  
			 "/qn",
			 "/log __log__",
			 "ACCEPT_EULA=1",
			 "ACCEPT_THIRDPARTY_LICENSES=1"
		  ]
	   }
	]
}'

function log {
    param($logline)
    Write-Host ("[{0}] - {1}" -f (get-date).ToString("yyyyMMdd - hh:mm:ss"), $logline)
}

function replaceenv {
    param( $line, $file, $log)

    $line = $line -replace "__file__", $file
    $line = $line -replace "__log__", $log

    return $line
}

function VBOinstall {
    param ($hostname)
    $json = @($jsoninstall | ConvertFrom-Json)[0]
    $steps = $json.steps
    $path = "C:\VBO365Install"

	foreach ($step in $steps) {
		if ($step.disabled -and $step.disabled -eq 1 ) {
			log(("[VBO365 Install] Disabled step detected {0}" -f $step.src))
		} else {
			$src = ("{0}" -f $step.src)
			$pathfile = Join-Path -Path $path -ChildPath $src
			$pathlog = Join-Path -Path $path -ChildPath "$src.log"
			$installline = replaceenv -line $step.install -file $pathfile -log $pathlog
			$rebuildargs = @()

			foreach($pa in $step.arguments) {
				$rebuildargs += ((replaceenv -line $pa -file $src -log $pathlog))
			}

			log("[VBO365 Install] Installing now:")
			log($installline)
			log($rebuildargs -join ",")
		
			Start-Process -FilePath $installline -ArgumentList $rebuildargs -Wait
		}
	}
	
	Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"
	
	if ($json.license -and $json.license.src)  {
		log("[VBO365 Install] Installing license")
		$pathfile = Join-Path -Path $path -ChildPath $json.license.src
		Install-VBOLicense -Path $pathfile
	}

	$cert = New-SelfSignedCertificate -subject $hostname -NotAfter (Get-Date).AddYears(10) -KeyDescription "Veeam Backup for Microsoft Office 365 auto install" -KeyFriendlyName "Veeam Backup for Microsoft Office 365 auto install"
	$certfile = (join-path $path "cert.pfx")
	$securepassword = ConvertTo-SecureString "VBOpassword!" -AsPlainText -Force

	Export-PfxCertificate -Cert $cert -FilePath $certfile -Password $securepassword

	log("[VBO365 Install] Enabling RESTful API service")
	Set-VBORestAPISettings -EnableService -CertificateFilePath $certfile -CertificatePassword $securepassword

	log("[VBO365 Install] Enabling Tenant Authentication Settings")
	Set-VBOTenantAuthenticationSettings -EnableAuthentication -CertificateFilePath $certfile -CertificatePassword $securepassword
}

log("[VBO365 Install] Starting Veeam Backup for Microsoft Office 365 install")
VBOinstall -hostname ([System.Net.Dns]::GetHostEntry([string]$env:computername).hostname)

log("[VBO365 Install] Creating Veeam Backup for Microsoft Office 365 firewall rules")
netsh advfirewall firewall add rule name="Veeam Backup for Microsoft Office 365 RESTful API Service" protocol=TCP dir=in localport=4443 action=allow
netsh advfirewall firewall add rule name="Veeam Backup for Microsoft Office 365" protocol=TCP dir=in localport=9191 action=allow

log("[VBO365 Install] Rebooting server")
Restart-Computer -Force