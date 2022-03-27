output "ip" {
  value = google_compute_instance.vm_instance.network_interface.0.network_ip
}

 resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl",
    {
     vm_ip_1 = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
     vm_ip_2 = google_compute_instance.vm_instance_2.network_interface.0.access_config.0.nat_ip
     vm_ip_3 = google_compute_instance.vm_instance_3.network_interface.0.access_config.0.nat_ip
    }
  )
  filename = "inventory"
}
