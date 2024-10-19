// Specify the provider and its configuration
provider "alicloud" {
  access_key = var.access_key
  secret_key = var.secret_key
  region = "me-central-1"
}

// 1- VPC
resource "alicloud_vpc" "vpc" {
  vpc_name   = "vpc-project" // Name of the VPC
  cidr_block = "10.0.0.0/8" // CIDR block of the VPC
}


// 2- VSwitch

// get the available zones
data "alicloud_zones" "default" {}

// Create a public vswitch (subnet)
resource "alicloud_vswitch" "public_vswitch" {
  vswitch_name      = "public" // Name of the VSwitch
  cidr_block        = "10.0.1.0/24" // CIDR block of the VSwitch
  vpc_id            = "${alicloud_vpc.vpc.id}" // ID of the VPC to which the VSwitch belongs
  zone_id = "${data.alicloud_zones.default.zones.0.id}" // ID of the zone in which the VSwitch is created, its A
}
// Create a private vswitch
resource "alicloud_vswitch" "private_vswitch" {
  vswitch_name      = "private"
  cidr_block        = "10.0.2.0/24"
  vpc_id            = "${alicloud_vpc.vpc.id}"
  zone_id = "${data.alicloud_zones.default.zones.0.id}" // ID of the zone in which the VSwitch is created, its A
}

// 3- Security Group

// This is the security group for the nginx server, it allows traffic on port 80 and 22 from any source

resource "alicloud_security_group" "nginx-sg" {
  name        = "nginx-sg"
  vpc_id = alicloud_vpc.vpc.id
}

resource "alicloud_security_group_rule" "allow-http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = alicloud_security_group.nginx-sg.id
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow-ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = alicloud_security_group.nginx-sg.id
  cidr_ip           = "0.0.0.0/0"
}

// 4- ECS

// Create a key pair
resource "alicloud_ecs_key_pair" "myKeytest" {
  key_pair_name = "my-key-project"
  resource_group_id = alicloud_vpc.vpc.resource_group_id
  key_file = "my-ecs-key-project.pem"
}


// This is a server to use nginx, it uses the security group nginx-sg, 
// and the key pair myKeytest, also its on the public subnet vswitch, its now on zone A. 
// internet_max_bandwidth_out is 100 so it will have a public ip, 

resource "alicloud_instance" "nginx" {
  availability_zone = data.alicloud_zones.default.zones.0.id
  security_groups   = [alicloud_security_group.nginx-sg.id]

  instance_type              = "ecs.g6.large"
  system_disk_category       = "cloud_essd"
  system_disk_size           = 20
  image_id                   = "ubuntu_24_04_x64_20G_alibase_20240812.vhd"
  instance_name              = "jump-box"
  vswitch_id                 = alicloud_vswitch.public_vswitch.id
  internet_max_bandwidth_out = 100
  internet_charge_type       = "PayByTraffic"
  instance_charge_type       = "PostPaid"
  key_name                   = alicloud_ecs_key_pair.myKeytest.key_pair_name
  user_data = base64encode(file("nginx.sh"))
}

output "ip" {
  value = alicloud_instance.nginx.public_ip
}