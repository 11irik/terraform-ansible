variable "project" {}

variable "credentials_file" {}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

data "google_compute_image" "gcp_image" {
  family  = "debian-9"
  project = "debian-cloud"
}
