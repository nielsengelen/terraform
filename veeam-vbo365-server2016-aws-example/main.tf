provider "aws" {
	region     = "${var.region}"
	access_key = "${var.access_key}"
	secret_key = "${var.secret_key}"
}

data "aws_ami" "windows-2016-latest" {
	most_recent = true
	owners      = [ "amazon" ]
	filter {
		name   = "name"
		values = [ "Windows_Server-2016-English-Full-Base*" ]
	}
}

resource "aws_instance" "aws_VBO365" {
	ami                    = "${data.aws_ami.windows-2016-latest.id}"
	get_password_data      = true
	instance_type          = "${var.instance_type}"
	key_name               = "${var.key_name}"
	user_data              = "${file("setup/bootstrap.ps1")}"
	vpc_security_group_ids = [ "${aws_security_group.security_group_VBO365.id}" ]
	
	connection {
		type     = "winrm"
		port     = "5986"
		https    = true
		insecure = true
		timeout  = "10m"
		user     = "Administrator"
		password = "${rsadecrypt(self.password_data,file("setup/terraform.pem"))}"
	}
	
	tags {
		Name = "${var.instance_name}"
	}
	
	provisioner "file" {
		source      = "setup/prep-vbo365.ps1"
		destination = "C:\\VBO365Install\\prep-vbo365.ps1"
	}
	
	provisioner "file" {
		source      = "setup/install-vbo365.ps1"
		destination = "C:\\VBO365Install\\install-vbo365.ps1"
	}

	provisioner "file" {
		source      = "setup/veeam_backup_microsoft_office.lic"
		destination = "C:\\VBO365Install\\veeam_backup_microsoft_office.lic"
	}
	
	provisioner "remote-exec" {
		inline     = "powershell.exe -File C:\\VBO365Install\\prep-vbo365.ps1"
	}
}

resource "null_resource" "install_vbo_server" {
	depends_on = ["aws_instance.aws_VBO365"]
	
	connection {
		type     = "winrm"
		host     = "${aws_instance.aws_VBO365.public_ip}"
		port     = "5986"
		https    = true
		insecure = true
		timeout  = "10m"
		user     = "Administrator"
		password = "${rsadecrypt(aws_instance.aws_VBO365.password_data,file("setup/terraform.pem"))}"
	}
	
	provisioner "local-exec" {
		command     = "Start-Sleep -Seconds 60"
		interpreter = ["PowerShell"]
	}
	
	provisioner "remote-exec" {
		inline     = "powershell.exe -File C:\\VBO365Install\\install-vbo365.ps1"
	}
}

resource "aws_security_group" "security_group_VBO365" {
	name        = "${var.security_group_name}"
	description = "Used for the aws_VBO365 instance"
	
	# Remote Desktop
	ingress {
		from_port   = 3389
		to_port     = 3389
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	# WinRM access
	ingress {
		from_port   = 5986
		to_port     = 5986
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	# Veeam Backup for Microsoft Office 365 RESTful API service port
	ingress {
		from_port   = 4443
		to_port     = 4443
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	# Veeam Backup for Microsoft Office 365 port
	ingress {
		from_port   = 9191
		to_port     = 9191
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	# outbound internet access
	  egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "${var.security_group_name}"
	}
}

output "public_ip" {
	value = "${aws_instance.aws_VBO365.public_ip}"
}