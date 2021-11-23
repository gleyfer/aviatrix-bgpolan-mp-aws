output "BGPoLAN_CSR_SSH_Cmd" {
  value = module.bgpolan_CSR.*.ssh_cmd_csr
}
output "TestClient_SSH_Cmd" {
  value = [for ip in aws_instance.test_client.*.public_ip : "ssh -i BGPoLAN-CSR-1-key.pem ubuntu@${ip}"]
}
output "TestServer_SSH_Cmd" {
  value = [for ip in aws_instance.test_server.*.public_ip : "ssh -i BGPoLAN-CSR-1-key.pem ubuntu@${ip}"]
}
output "TestClient_PrivateIP" {
  value = [for ip in aws_instance.test_client.*.private_ip : "${ip}"]
}
output "TestServer_PrivateIP" {
  value = [for ip in aws_instance.test_server.*.private_ip : "${ip}"]
}
