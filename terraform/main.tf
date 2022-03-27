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

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_firewall" "ssh-rule" {
  name = "ssh-rule"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  target_tags = ["dev"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "http-rule" {
  name = "http-rule"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["80"]
  }
  target_tags = ["http-server"]
  source_ranges = ["0.0.0.0/0"]
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
    network = google_compute_network.vpc_network.name
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
    network = google_compute_network.vpc_network.name
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
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

