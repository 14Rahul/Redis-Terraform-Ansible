vpc_cidr             = "10.0.0.0/16"
azs                  = ["us-east-2a", "us-east-2b", "us-east-2c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

sg_peram = [{
  fromport   = 0
  toport     = 0
  protocol   = "-1"
  cidr_block = "0.0.0.0/0"
}]

configuration = [
  {
    "application_name" : "Redis-us-east-2a",
    "no_of_instances" : "1",
    "instance_type" : "t2.large",
    "Disk_Size" : 50
    "subnet" : "public"
    "az" : 0
    "sgno" : 0
    "project" : "Redis"
  },

  {
    "application_name" : "Redis-us-east-2b",
    "no_of_instances" : "1",
    "instance_type" : "t2.large",
    "Disk_Size" : 50
    "subnet" : "public"
    "az" : 1
    "sgno" : 0
    "project" : "Redis"
  },
  {
    "application_name" : "Redis-us-east-2c",
    "no_of_instances" : "1",
    "instance_type" : "t2.large",
    "Disk_Size" : 50
    "subnet" : "public"
    "az" : 2
    "sgno" : 0
    "project" : "Redis"
  },
  {
    "application_name" : "Prometheous",
    "no_of_instances" : "1",
    "instance_type" : "t2.medium",
    "Disk_Size" : 20
    "subnet" : "public"
    "az" : 2
    "sgno" : 0
    "project" : "Prometheous"
  },
  {
    "application_name" : "Grafana",
    "no_of_instances" : "1",
    "instance_type" : "t2.medium",
    "Disk_Size" : 20
    "subnet" : "public"
    "az" : 2
    "sgno" : 0
    "project" : "Grafana"
  }

]