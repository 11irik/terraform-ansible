terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
    tls = {
      source  = "hashicorp/tls"
    }
  }
}

provider "tls" {
  // no config needed
}

resource "tls_private_key" "ansible_sshkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key_pem" {
  content         = tls_private_key.ansible_sshkey.private_key_pem
  filename        = "./../ansible_sshkey.pem"
  file_permission = "0600"
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
  region      = var.region
  zone        = var.zone
}

resource "google_compute_network" "vpc_network" {
  name                    = "terraform-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "proxy_subnet" {
  name          = "terraform-proxy-subnet"
  ip_cidr_range = "10.0.0.0/24"
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "main_subnet" {
  name          = "terraform-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "f1-micro"
  tags         = ["dev", "http-server"]

 metadata = {
    ssh-keys = "${var.ansible_user}:${tls_private_key.ansible_sshkey.public_key_openssh}"
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.gcp_image.self_link
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.main_subnet.id
    access_config {
    }
  }
}

resource "google_compute_instance" "vm_instance_2" {
  name         = "terraform-instance2"
  machine_type = "f1-micro"
  tags         = ["dev", "http-server"]

 metadata = {
    ssh-keys = "${var.ansible_user}:${tls_private_key.ansible_sshkey.public_key_openssh}"
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.gcp_image.self_link
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.main_subnet.id
    access_config {
    }
  }
}

resource "google_compute_instance" "vm_instance_3" {
  name         = "terraform-instance3"
  machine_type = "f1-micro"
  tags         = ["dev", "http-server"]

  metadata = {
    ssh-keys = "${var.ansible_user}:${tls_private_key.ansible_sshkey.public_key_openssh}"
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.gcp_image.self_link
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.main_subnet.id
    access_config {
    }
  }
}

resource "google_compute_instance" "bastion" {
  name         = "terraform-bastion"
  machine_type = "f1-micro"
  tags         = ["dev", "http-server"]

  metadata = {
    ssh-keys = "${var.ansible_user}:${tls_private_key.ansible_sshkey.public_key_openssh}"
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.gcp_image.self_link
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.main_subnet.id
    access_config {
    }
  }
}

resource "google_compute_instance_group" "servers" {
  name        = "terraform-servers"

  instances = [
    google_compute_instance.vm_instance.id,
    google_compute_instance.vm_instance_2.id,
    google_compute_instance.vm_instance_3.id
  ]
}

resource "google_compute_region_health_check" "default" {
  name     = "terraform-hc"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
  }
}

resource "google_compute_region_backend_service" "default" {
  name                  = "terraform-backend-subnet"
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = 10
  health_checks         = [google_compute_region_health_check.default.id]
  backend {
    group           = google_compute_instance_group.servers.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_region_url_map" "default" {
  name            = "terraform-regional-url-map"
  default_service = google_compute_region_backend_service.default.id
}

resource "google_compute_region_target_http_proxy" "default" {
  name     = "terraform-target-http-proxy"
  url_map  = google_compute_region_url_map.default.id
}

resource "google_compute_forwarding_rule" "forwarding_rule" {
  name                  = "terraform-forwarding-rule"
  depends_on            = [google_compute_subnetwork.proxy_subnet]
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.id
  network               = google_compute_network.vpc_network.id
  subnetwork            = google_compute_subnetwork.main_subnet.id
  network_tier          = "PREMIUM"
}

resource "google_compute_firewall" "allow-ssh" {
  name = "terraform-allow-ssh"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  target_tags = ["http-server"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "fw-iap" {
  name          = "terraform-fw-allow-iap-hc"
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "35.235.240.0/20"]
  allow {
    protocol = "tcp"
  }
}

resource "google_compute_firewall" "fw-backends" {
  name          = "terraform-fw-backends"
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.id
  source_ranges = ["10.0.0.0/24"]
  target_tags   = ["http-server"]
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}
