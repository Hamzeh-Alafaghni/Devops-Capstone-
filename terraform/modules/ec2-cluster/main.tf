data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
resource "random_password" "join" {
  length  = 48
  special = false
}
resource "aws_ssm_parameter" "join" {
  name  = "/${var.project}/k3s-token"
  type  = "SecureString"
  value = random_password.join.result
}
resource "aws_iam_role" "node" {
  name               = "${var.project}-node"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "node" {
  role = aws_iam_role.node.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ssm:GetParameter"], Resource = aws_ssm_parameter.join.arn },
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"], Resource = var.ecr_arns }
  ] })
}
resource "aws_iam_instance_profile" "node" {
  name = "${var.project}-node"
  role = aws_iam_role.node.name
}
resource "aws_iam_role" "control_plane" {
  name               = "${var.project}-control-plane"
  assume_role_policy = aws_iam_role.node.assume_role_policy
}
resource "aws_iam_role_policy_attachment" "control_plane_ssm" {
  role       = aws_iam_role.control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "control_plane" {
  role = aws_iam_role.control_plane.id
  policy = jsonencode({ Version = "2012-10-17", Statement = concat(jsondecode(aws_iam_role_policy.node.policy).Statement, [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.database_secret_arn }
  ]) })
}
resource "aws_iam_instance_profile" "control_plane" {
  name = "${var.project}-control-plane"
  role = aws_iam_role.control_plane.name
}
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.k3s_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.control_plane.name
  metadata_options { http_tokens = "required" }
  root_block_device {
    volume_size = 20
    encrypted   = true
  }
  user_data_replace_on_change = true
  user_data                   = templatefile("${path.module}/templates/control-plane.sh.tpl", { region = var.region, token_parameter = aws_ssm_parameter.join.name, k3s_version = var.k3s_version })
  tags                        = { Name = "${var.project}-control-plane" }
  depends_on                  = [aws_iam_role_policy.control_plane, aws_iam_role_policy_attachment.control_plane_ssm]
}
resource "aws_launch_template" "worker" {
  name_prefix   = "${var.project}-worker-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.worker_instance_type
  iam_instance_profile { name = aws_iam_instance_profile.node.name }
  vpc_security_group_ids = [var.k3s_sg_id]
  metadata_options { http_tokens = "required" }
  user_data = base64encode(templatefile("${path.module}/templates/worker.sh.tpl", { region = var.region, token_parameter = aws_ssm_parameter.join.name, k3s_version = var.k3s_version, control_plane_ip = aws_instance.control_plane.private_ip }))
}
resource "aws_autoscaling_group" "workers" {
  name                = "${var.project}-workers"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = var.private_subnet_ids
  launch_template {
    id      = aws_launch_template.worker.id
    version = aws_launch_template.worker.latest_version
  }
  instance_refresh { strategy = "Rolling" }
  tag {
    key                 = "Name"
    value               = "${var.project}-worker"
    propagate_at_launch = true
  }
}
