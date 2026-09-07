module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}

module "security_groups" {
  source   = "./modules/security-groups"
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr
}

module "nat_instance" {
  source                 = "./modules/nat-instance"
  public_subnet_id       = module.vpc.public_subnet_ids[0]
  nat_sg_id              = module.security_groups.nat_sg_id
  private_route_table_id = module.vpc.private_route_table_id
}

module "rds" {
  source             = "./modules/rds"
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.security_groups.rds_sg_id
}

module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
}

module "ec2_cluster" {
  source             = "./modules/ec2-cluster"
  private_subnet_ids = module.vpc.private_subnet_ids
  k3s_sg_id          = module.security_groups.k3s_sg_id
}

module "ecr" {
  source = "./modules/ecr"
}

module "iam_oidc" {
  source = "./modules/iam-oidc"
}
