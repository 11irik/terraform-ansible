terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
  region      = var.region
  zone        = var.zone
}

# VPC network
resource "google_compute_network" "ilb_network" {
  name                    = "l7-ilb-network"
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "fw-rule" {
  name = "terraform-fw-rule"
  network = google_compute_network.ilb_network.name
  allow {
    protocol = "tcp"
    ports = ["22", "80"]
  }
  target_tags = ["http-server"]
  source_ranges = ["0.0.0.0/0"]
}

# proxy-only subnet
resource "google_compute_subnetwork" "proxy_subnet" {
  name          = "l7-ilb-proxy-subnet"
  ip_cidr_range = "10.0.0.0/24"
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
  network       = google_compute_network.ilb_network.id
}

# backend subnet
resource "google_compute_subnetwork" "ilb_subnet" {
  name          = "l7-ilb-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.ilb_network.id
}

# forwarding rule
resource "google_compute_forwarding_rule" "google_compute_forwarding_rule" {
  name                  = "l7-ilb-forwarding-rule"
  depends_on            = [google_compute_subnetwork.proxy_subnet]
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.id
  network               = google_compute_network.ilb_network.id
  subnetwork            = google_compute_subnetwork.ilb_subnet.id
  network_tier          = "PREMIUM"
}

# HTTP target proxy
resource "google_compute_region_target_http_proxy" "default" {
  name     = "l7-ilb-target-http-proxy"
  url_map  = google_compute_region_url_map.default.id
}

# URL map
resource "google_compute_region_url_map" "default" {
  name            = "l7-ilb-regional-url-map"
  default_service = google_compute_region_backend_service.default.id
}

# backend service
resource "google_compute_region_backend_service" "default" {
  name                  = "l7-ilb-backend-subnet"
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

# health check
resource "google_compute_region_health_check" "default" {
  name     = "l7-ilb-hc"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
  }
}

# allow all access from IAP and health check ranges
resource "google_compute_firewall" "fw-iap" {
  name          = "l7-ilb-fw-allow-iap-hc"
  direction     = "INGRESS"
  network       = google_compute_network.ilb_network.id
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "35.235.240.0/20"]
  allow {
    protocol = "tcp"
  }
}

# allow http from proxy subnet to backends
resource "google_compute_firewall" "fw-ilb-to-backends" {
  name          = "l7-ilb-fw-allow-ilb-to-backends"
  direction     = "INGRESS"
  network       = google_compute_network.ilb_network.id
  source_ranges = ["10.0.0.0/24"]
  target_tags   = ["http-server"]
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "f1-micro"
  tags         = ["dev", "http-server"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.gcp_image.self_link
    }
  }

  network_interface {
    network    = google_compute_network.ilb_network.id
    subnetwork = google_compute_subnetwork.ilb_subnet.id
    access_config {
    }
  }
}

resource "google_compute_instance" "vm_instance_2" {
  name         = "terraform-instance2"
  machine_type = "f1-micro"
  tags         = ["dev", "http-server"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.gcp_image.self_link
    }
  }

  network_interface {
    network    = google_compute_network.ilb_network.id
    subnetwork = google_compute_subnetwork.ilb_subnet.id
    access_config {
    }
  }
}

resource "google_compute_instance" "vm_instance_3" {
  name         = "terraform-instance3"
  machine_type = "f1-micro"
  tags         = ["dev", "http-server"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.gcp_image.self_link
    }
  }

  network_interface {
    network    = google_compute_network.ilb_network.id
    subnetwork = google_compute_subnetwork.ilb_subnet.id
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

# test instance
resource "google_compute_instance" "vm-test" {
  name         = "l7-ilb-test-vm"
  machine_type = "e2-small"
  network_interface {
    network    = google_compute_network.ilb_network.id
    subnetwork = google_compute_subnetwork.ilb_subnet.id
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }
}
