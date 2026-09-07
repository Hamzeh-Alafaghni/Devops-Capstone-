module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}

module "security_groups" {
  source   = "./modules/security-groups"
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr
}

module "ecr" {
  source = "./modules/ecr"
}
