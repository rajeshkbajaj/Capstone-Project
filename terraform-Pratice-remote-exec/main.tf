# Creating vpc , public and private subnets in us-east-1 region.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

  name = "${var.name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  #A Internet Gateway or NAT Gateway are not created by default.
  #Setting the arguments "create_igw" and "enable_nat_gateway" to "true" will create an internet gateway and nat gateway respectively.

  enable_nat_gateway = true
  single_nat_gateway = true
  create_igw         = true
  enable_dns_hostnames= true

  public_subnet_tags = {
     "kubernetes.io/cluster/my-eks-201" = "shared"
     "kubernetes.io/role/internal-elb"     = "1"
    Type = "public-subnets"
  }
  private_subnet_tags = {
     "kubernetes.io/cluster/my-eks-201" = "shared"
     "kubernetes.io/role/internal-elb"     = "1"
    Type = "private-subnets"
  }

  tags = {
    Terraform = "true"
   "kubernetes.io/cluster/my-eks-201"    = "shared" 
    Owner                                 = "Rajesh"
    Environment = "rajesh-project"
  }
  vpc_tags = {
    Name = "${var.name}-vpc"
  }
}

# Getting the Self IP address from below define url

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}


# Security group - Bastion Host SSH

resource "aws_security_group" "Bastion_host-self-ip" {
  name        = "Bastion_host-self-ip"
  description = "Allow self ip to ssh and allow all egress."
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from self ip"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
    ingress {
    description = "HTTP from self ip"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "Bastion_host_SG"
    Terraform = "true"
  }
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22 #Allows SSH connection
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

# providing private IP's address ranges for all_worker_mgmt..
    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

# EC2 instance - Bastion Host

# key pair

resource "aws_key_pair" "id_rsa" {
  key_name   = "id_rsa"
  public_key = file("~/.ssh/id_rsa.pub")
}


resource "aws_instance" "bastion-ec2" {
  ami             = var.ami
  instance_type   = var.instance_type
  key_name        = aws_key_pair.id_rsa.key_name
  subnet_id       = module.vpc.public_subnets[0]
  security_groups = ["${aws_security_group.Bastion_host-self-ip.id}"]

  tags = {
    Name      = "${var.name}-Bastion"
    Terraform = "true"
  }
   
    connection {
        type        = "ssh"
        host        = self.public_ip
        user        = "ubuntu"
        private_key = file("~/.ssh/id_rsa")
    }

    provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt install unzip -y",
      "sudo curl -LO https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
      "unzip awscli-exe-linux-x86_64.zip",
      "sudo ./aws/install",
      "sudo apt-get install -y jq",
      "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3",
      "chmod 700 get_helm.sh",
      "./get_helm.sh",
      "sudo apt-get install -y docker.io",
      "curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl",
      "curl -o kubectl.sha256 https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl.sha256",
      "openssl sha1 -sha256 kubectl",
      "chmod +x ./kubectl",
      "mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin",
      "echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc",
      "curl --silent --location \"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz\" | tar xz -C /tmp",
      "sudo mv /tmp/eksctl /usr/local/bin",
      "helm repo add stable https://charts.helm.sh/stable",
      "helm repo update",
      "curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -",
      "sudo apt-get install apt-transport-https --yes",
      "echo 'deb https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list",
      "sudo apt-get update",
      "sudo apt-get install helm -y",
      "apt-get update",
      "apt-get install apache2-utils -y"
    ]
  }
}
