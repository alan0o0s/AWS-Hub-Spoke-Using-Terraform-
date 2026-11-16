output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the launch template."
  value       = aws_launch_template.app.latest_version
}
