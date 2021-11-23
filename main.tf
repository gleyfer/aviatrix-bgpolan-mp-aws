#Create transit, spoke, and simulated on-prem via another transit
module "sdwan_transit" {
  source          = "terraform-aviatrix-modules/aws-transit/aviatrix"
  cidr            = var.sdwan_transit_cidr
  region          = var.aws_region
  account         = var.account
  name            = "sdwan"
  local_as_number = var.sdwan_asn
  insane_mode     = true
  bgp_ecmp        = true
  instance_size   = var.transit_gw_instance_size
}

module "test_spoke" {
  source        = "terraform-aviatrix-modules/aws-spoke/aviatrix"
  name          = "prod-server"
  cidr          = "10.100.0.0/24"
  region        = "us-west-2"
  account       = var.account
  insane_mode   = true
  instance_size = var.prioritize == "price" ? "c5n.xlarge" : "c5n.4xlarge"
  transit_gw    = module.sdwan_transit.transit_gateway.gw_name
}

module "onprem_transit" {
  source          = "terraform-aviatrix-modules/aws-transit/aviatrix"
  cidr            = var.onprem_transit_cidr
  region          = var.aws_region
  account         = var.account
  name            = "onprem"
  local_as_number = var.onprem_asn
  bgp_ecmp        = true
  enable_advertise_transit_cidr = true
  instance_size   = var.prioritize == "price" ? "c5n.large" : "c5n.4xlarge"
}

#Create BGPoLAN subnets for use later in CSR module
resource "aws_subnet" "BGPoLAN" {
  count         = 2
  vpc_id        = module.sdwan_transit.vpc.vpc_id
  cidr_block    = cidrsubnet(var.sdwan_transit_cidr,5,length(module.sdwan_transit.vpc.subnets)+count.index+1)
  availability_zone = count.index == 0 ? "${var.aws_region}${var.az1}" : "${var.aws_region}${var.az2}"
  
  lifecycle {
    ignore_changes = [ tags ]
  }
}

#Create BGPoLAN CSRs
module "bgpolan_CSR" {
  count          = var.csr_pairs
  source         = "github.com/gleyfer/aviatrix-demo-onprem-aws"
  prioritize     = var.prioritize
  hostname       = "BGPoLAN-CSR-${count.index + 1}"
  network_cidr   = var.network_cidr
  public_subnet_ids     = [module.sdwan_transit.vpc.public_subnets[0].subnet_id,module.sdwan_transit.vpc.public_subnets[2].subnet_id]
  bgpolan_subnet_ids    = [aws_subnet.BGPoLAN[0].id,aws_subnet.BGPoLAN[1].id]
  instance_type  = var.prioritize == "price" ? "t3.medium" : "c5n.xlarge"
  tunnel_proto   = "LAN"
  public_conns   = ["${module.onprem_transit.transit_gateway.gw_name}:${var.onprem_asn}:1"]
  private_conns   = ["${module.sdwan_transit.transit_gateway.gw_name}:${var.sdwan_asn}:1"]
  csr_bgp_as_num = var.csr_bgp_as_num
  create_client  = false

  depends_on = [module.sdwan_transit,module.onprem_transit]
}

#Create test client and server
data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20211027"]
  }
}

resource "aws_security_group" "allow_all_client" {
  name        = "testclient_allow_all"
  description = "Allow all traffic in testclient private subnet"
  vpc_id      = module.onprem_transit.vpc.vpc_id

  ingress {
    description      = "All Traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "testclient_allow_all"
  }
}

resource "aws_security_group" "allow_all_server" {
  name        = "testserver_allow_all"
  description = "Allow all traffic in testserver private subnet"
  vpc_id      = module.test_spoke.vpc.vpc_id

  ingress {
    description      = "All Traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "testserver_allow_all"
  }
}

resource "aws_instance" "test_client" {
  count                       = var.prioritize == "price" ? 1 : 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.prioritize == "price" ? "t3.micro" : "c5n.4xlarge"
  key_name                    = "BGPoLAN-CSR-1_sshkey"
  subnet_id                   = count.index == 0 ? module.onprem_transit.vpc.public_subnets[0].subnet_id : module.onprem_transit.vpc.public_subnets[2].subnet_id
  vpc_security_group_ids      = [aws_security_group.allow_all_client.id]
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
sudo sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
sudo systemctl restart sshd
echo ubuntu:Aviatrix123 | sudo chpasswd
sudo apt-get update
sudo apt-get install -y traceroute
sudo apt-get install -y unzip
wget https://github.com/microsoft/ethr/releases/latest/download/ethr_linux.zip
unzip ethr_linux.zip -d /home/ubuntu/
EOF

  depends_on = [ module.bgpolan_CSR ]

  tags = {
    "Name" = "TestClient"
  }
}

resource "aws_instance" "test_server" {
  count                       = var.prioritize == "price" ? 1 : 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.prioritize == "price" ? "t3.micro" : "c5n.4xlarge"
  key_name                    = "BGPoLAN-CSR-1_sshkey"
  subnet_id                   = count.index == 0 ? module.test_spoke.vpc.public_subnets[0].subnet_id :module.test_spoke.vpc.public_subnets[1].subnet_id
  vpc_security_group_ids      = [aws_security_group.allow_all_server.id]
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
sudo sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
sudo systemctl restart sshd
echo ubuntu:Aviatrix123 | sudo chpasswd
sudo apt-get update
sudo apt-get install -y traceroute
sudo apt-get install -y unzip
wget https://github.com/microsoft/ethr/releases/latest/download/ethr_linux.zip
unzip ethr_linux.zip -d /home/ubuntu/
EOF

  depends_on = [ module.bgpolan_CSR,module.test_spoke ]

  tags = {
    "Name" = "TestServer"
  }
}
