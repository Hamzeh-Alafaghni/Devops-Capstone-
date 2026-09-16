output "control_plane_id" { value = aws_instance.control_plane.id }
output "asg_name" { value = aws_autoscaling_group.workers.name }
