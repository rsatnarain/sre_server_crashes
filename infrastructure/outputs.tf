# =========================================================================================
# Author: Rob Satnarain
# Created: 2026-05-04
# Description: This file contains the outputs.
#
# Updated By     Date       Version     Description
# Rob Satnarain 2026-05-04  1.0         Initial creation - outputs
# =========================================================================================


output "prometheus_ui_url" {
  description = "URL to access the Prometheus UI"
  value       = "http://${aws_instance.prometheus_server.public_ip}:9090"
}

output "victim_website_url" {
  description = "URL to hit for the load test"
  value       = "http://${aws_instance.victim_server.public_ip}"
}