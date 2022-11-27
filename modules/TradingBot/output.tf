
output "instance_id" {
  value       = aws_instance.EC2.id
}

# output "arn" {
#   description = "The ARN of the instance"
#   value       = aws_instance.EC2-1.arn
# }

# output "capacity_reservation_specification" {
#   description = "Capacity reservation specification of the instance"
#   value       = aws_instance.EC2-1.capacity_reservation_specification
# }

# output "instance_state" {
#   description = "The state of the instance. One of: `pending`, `running`, `shutting-down`, `terminated`, `stopping`, `stopped`"
#   value       = aws_instance.EC2-1.instance_state
# }

# output "outpost_arn" {
#   description = "The ARN of the Outpost the instance is assigned to"
#   value       = aws_instance.EC2-1.outpost_arn
# }



# output "public_dns" {
#   description = "The public DNS name assigned to the instance. For EC2-VPC, this is only available if you've enabled DNS hostnames for your VPC"
#   value       = aws_instance.EC2-1.public_dns
# }

# output "public_ip" {
#   description = "The public IP address assigned to the instance, if applicable. NOTE: If you are using an aws_eip with your instance, you should refer to the EIP's address directly and not use `public_ip` as this field will change after the EIP is attached"
#   value       = aws_instance.EC2-1.public_ip
# }

# output "private_ip" {
#   description = "The private IP address assigned to the instance."
#   value       = aws_instance.EC2-1.private_ip
# }

# output "ipv6_addresses" {
#   description = "The IPv6 address assigned to the instance, if applicable."
#   value       = aws_instance.EC2-1.ipv6_addresses
# }

# output "tags_all" {
#   description = "A map of tags assigned to the resource, including those inherited from the provider default_tags configuration block"
#   value       = aws_instance.EC2-1.tags_all
# }



