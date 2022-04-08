output "vm_ip1" {
  value = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
}

output "lb_internal_ip" {
  value = google_compute_forwarding_rule.forwarding_rule.ip_address
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl",
    {
     vm_ip_1 = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
     vm_ip_2 = google_compute_instance.vm_instance_2.network_interface.0.access_config.0.nat_ip
     vm_ip_3 = google_compute_instance.vm_instance_3.network_interface.0.access_config.0.nat_ip
    }
  )
  filename = "./../inventory"
}
