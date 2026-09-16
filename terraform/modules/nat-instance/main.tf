
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.nat_sg_id]
  source_dest_check           = false
  associate_public_ip_address = true
  metadata_options { http_tokens = "required" }
  user_data = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail
    dnf install -y iptables-services
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-nat.conf
    sysctl --system
    IFACE=$(ip -o route show default | awk '{print $5; exit}')
    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
    iptables -F FORWARD
    iptables -P FORWARD ACCEPT
    service iptables save
    systemctl enable iptables
  SCRIPT
  tags      = { Name = "nat-instance" }
}

resource "aws_route" "private_nat" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}
