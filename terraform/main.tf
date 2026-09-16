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
  project            = var.project
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.security_groups.rds_sg_id
}
module "ecr" {
  source  = "./modules/ecr"
  project = var.project
}
module "ec2_cluster" {
  source              = "./modules/ec2-cluster"
  project             = var.project
  region              = var.aws_region
  k3s_version         = var.k3s_version
  private_subnet_ids  = module.vpc.private_subnet_ids
  k3s_sg_id           = module.security_groups.k3s_sg_id
  ecr_arns            = module.ecr.repository_arns
  database_secret_arn = module.rds.secret_arn
  depends_on          = [module.nat_instance]
}
module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  asg_name          = module.ec2_cluster.asg_name
}
module "iam_oidc" {
  source            = "./modules/iam-oidc"
  project           = var.project
  region            = var.aws_region
  github_repository = var.github_repository
  repository_arns   = module.ecr.repository_arns
  state_bucket      = var.state_bucket
  state_lock_table  = var.state_lock_table
  oidc_provider_arn = var.oidc_provider_arn
}
