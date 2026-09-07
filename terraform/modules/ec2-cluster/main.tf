variable "private_subnet_ids" {}
variable "k3s_sg_id" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "k3s-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "k3s-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.k3s_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  tags = { Name = "k3s-control-plane" }
}

resource "aws_launch_template" "worker" {
  name_prefix   = "k3s-worker-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  iam_instance_profile { name = aws_iam_instance_profile.ssm_profile.name }
  vpc_security_group_ids = [var.k3s_sg_id]
}

resource "aws_autoscaling_group" "workers" {
  name                = "k3s-workers-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  vpc_zone_identifier = var.private_subnet_ids
  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }
}
