output "alb_sg_id" { value = aws_security_group.alb_sg.id }
output "k3s_sg_id" { value = aws_security_group.k3s_sg.id }
output "rds_sg_id" { value = aws_security_group.rds_sg.id }
output "nat_sg_id" { value = aws_security_group.nat_sg.id }
