provider "aws" {
  region     = ""
  access_key = ""
  secret_key = ""
}

locals {
  serverconfig = [
    for srv in var.configuration : [
      for i in range(1, srv.no_of_instances + 1) : {
        instance_name = "${srv.application_name}-${i}"
        instance_type = srv.instance_type
        volume_size   = srv.Disk_Size
        subnet        = srv.subnet
        az            = srv.az
        sgno          = srv.sgno
        project       = srv.project
      }
    ]
  ]
}

locals {
  instances = flatten(local.serverconfig)
}

resource "aws_vpc" "Prod_VPC" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Prod_VPC"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.Prod_VPC.id
  availability_zone       = element(var.azs, count.index)
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.Prod_VPC.id
  availability_zone = element(var.azs, count.index)
  cidr_block        = element(var.private_subnet_cidrs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "Prod_IGW" {
  vpc_id = aws_vpc.Prod_VPC.id

  tags = {
    Name = "Prod-IGW"
  }
}

resource "aws_route_table" "Prod_Public_RT" {
  vpc_id = aws_vpc.Prod_VPC.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.Prod_IGW.id
      core_network_arn           = null
      carrier_gateway_id         = null
      destination_prefix_list_id = null
      egress_only_gateway_id     = null
      instance_id                = null
      ipv6_cidr_block            = null
      local_gateway_id           = null
      nat_gateway_id             = null
      network_interface_id       = null
      transit_gateway_id         = null
      vpc_endpoint_id            = null
      vpc_peering_connection_id  = null

    }
  ]

  tags = {
    Name = "Prod-Public-RT"
  }
  depends_on = [aws_internet_gateway.Prod_IGW]
}

resource "aws_route_table_association" "Prod_Public_association_1" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.Prod_Public_RT.id
}

resource "aws_iam_role" "SSMRoleforEC2Redis" {
  name = "SSMRoleforEC2Redis"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "SSMRoleforEC2"
  }
}


resource "aws_iam_role_policy_attachment" "AmazonEC2RoleforSSM" {
  role       = aws_iam_role.SSMRoleforEC2Redis.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMFullAccess" {
  role       = aws_iam_role.SSMRoleforEC2Redis.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMAutomationRole" {
  role       = aws_iam_role.SSMRoleforEC2Redis.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_security_group" "Prod_SG" {
  count  = length(var.configuration)
  name   = "${var.configuration[count.index]["application_name"]} SG"
  vpc_id = aws_vpc.Prod_VPC.id
  dynamic "ingress" {
    iterator = ports
    for_each = var.sg_peram
    content {
      from_port   = ports.value.fromport
      to_port     = ports.value.toport
      protocol    = ports.value.protocol
      cidr_blocks = [ports.value.cidr_block]
    }
  }
  egress = [
    {
      description      = "Public"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}



resource "aws_iam_instance_profile" "SSMRoleforEC2_profile" {
  name = "SSMRoleforEC2_profile"
  role = aws_iam_role.SSMRoleforEC2Redis.name
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "Prod_ansible" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  iam_instance_profile   = aws_iam_instance_profile.SSMRoleforEC2_profile.id
  subnet_id              = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [aws_security_group.Prod_SG[0].id]

  root_block_device {
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "Ansible"
  }
  key_name = "awsdev"
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("../ansible-data/awsdev.pem")
    host        = self.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install software-properties-common -y",
      "sudo add-apt-repository --yes --update ppa:ansible/ansible",
      "sudo apt install ansible -y",
      "mkdir ansible-data"
    ]
  }

}



resource "aws_instance" "Prod_EC2" {
  for_each = { for server in local.instances : server.instance_name => server }
  # subnet_id              = aws_subnet.Redis_Prod_Public_Subnet_us_east_2a.id
  subnet_id              = each.value.subnet == "public" ? aws_subnet.public_subnets[each.value.az].id : aws_subnet.private_subnets[each.value.az].id
  ami                    = data.aws_ami.ubuntu.id
  vpc_security_group_ids = [aws_security_group.Prod_SG[each.value.sgno].id]
  iam_instance_profile   = aws_iam_instance_profile.SSMRoleforEC2_profile.id
  instance_type          = each.value.instance_type
  root_block_device {
    volume_size           = each.value.volume_size
    delete_on_termination = true
    encrypted             = true
  }
  user_data = <<EOF
  #!/bin/bash
  echo "Changing the hostname to ${each.value.instance_name}"
  hostnamectl set-hostname ${each.value.instance_name}
  sudo echo "${each.value.instance_name}" > /etc/hostname
  EOF
  tags = {
    Name    = "${each.value.instance_name}"
    Project = "${each.value.project}"
  }
  key_name = "awsdev"
}

# output "instances" {
#   value       = aws_instance.Redis_Prod_EC2
#   description = "All Machine details"
# }

data "aws_instances" "server_ips" {
  count = length(var.configuration)
  instance_tags = {
    Project = "${var.configuration[count.index]["project"]}"
  }

  instance_state_names = ["running"]

  depends_on = [
    aws_instance.Prod_EC2
  ]
}

resource "local_file" "Ansible_Host_File" {
  filename = "../ansible-data/hosts"
  content  = <<-EOT
[Redis]
%{for ip in data.aws_instances.server_ips[0].private_ips~}
${ip}
%{endfor~}

[Prometheous]
%{for ip in data.aws_instances.server_ips[3].private_ips~}
${ip}
%{endfor~}

[Grafana]
%{for ip in data.aws_instances.server_ips[4].private_ips~}
${ip}
%{endfor~}
  EOT

  depends_on = [
    aws_instance.Prod_EC2
  ]
}


resource "null_resource" "scp" {
  provisioner "local-exec" {

    command = "scp -i ../ansible-data/awsdev.pem  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r ../ansible-data/ ubuntu@${aws_instance.Prod_ansible.public_ip}:~/"
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("../ansible-data/awsdev.pem")
    host        = aws_instance.Prod_ansible.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "mv /home/ubuntu/ansible-data/config .ssh/",
      "mv /home/ubuntu/ansible-data/awsdev.pem .ssh/",
      "sudo chmod 600 .ssh/awsdev.pem",
      "sudo mv /home/ubuntu/ansible-data/hosts /etc/ansible/",
      "ansible-galaxy collection install community.grafana",
      "ansible-playbook /home/ubuntu/ansible-data/ansible/main.yml"

    ]
  }

  depends_on = [aws_instance.Prod_ansible, aws_instance.Prod_EC2]
}