variable "digital_ocean_token" {
  type        = "string"
  description = "A DigitalOcean API token."
}

variable "ssh_key_id" {
  type        = "string"
  description = "The ID of an SSH key on DigitalOcean."
}

provider "digitalocean" {
  token = "${var.digital_ocean_token}"
}

resource "digitalocean_droplet" "build_and_prod" {
  image    = "ubuntu-16-04-x64"
  name     = "build-and-prod"
  region   = "nyc3"
  size     = "512mb"
  ssh_keys = ["${var.ssh_key_id}"]

  provisioner "local-exec" {
    command = "echo [build] > one_droplet.txt && echo ${digitalocean_droplet.build_and_prod.ipv4_address} ansible_user=root ansible_python_interpreter=/usr/bin/python3 >> one_droplet.txt"
  }
}
