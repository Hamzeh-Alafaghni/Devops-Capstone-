data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "k3s-ssm-role-public"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "k3s-ssm-profile-public"
  role = aws_iam_role.ssm_role.name
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "aws_instance" "control_plane" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.small"
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.k3s_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/control-plane.sh.tpl", {
    cluster_token = random_password.k3s_token.result
  })

  tags = { Name = "devops-capstone-control-plane" }
}

resource "aws_launch_template" "worker" {
  name_prefix   = "k3s-worker-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  network_interfaces {
    security_groups = [var.k3s_sg_id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/templates/worker.sh.tpl", {
    control_plane_ip = aws_instance.control_plane.private_ip
    cluster_token    = random_password.k3s_token.result
  }))
}

resource "aws_autoscaling_group" "workers" {
  name                = "k3s-workers-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "devops-capstone-worker"
    propagate_at_launch = true
  }
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
