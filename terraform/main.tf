terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "../../tmp/tf_key.json"
  folder_id                = local.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "foo" {}

resource "yandex_vpc_subnet" "foo" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.foo.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

resource "yandex_container_registry" "registry1" {
  name = "registry1"
}

locals {
  folder_id = "b1gs0v2vqdts8glo467i"
  service-accounts = toset([
    "yy-noted-catgpt-sa",
  ])
  catgpt-sa-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
    "editor",
  ])
}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = each.key
}
resource "yandex_resourcemanager_folder_iam_member" "catgpt-roles" {
  for_each  = local.catgpt-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["yy-noted-catgpt-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}
# resource "yandex_compute_instance" "catgpt-1" {
#     platform_id        = "standard-v2"
#     service_account_id = yandex_iam_service_account.service-accounts["yy-noted-catgpt-sa"].id
#     resources {
#       cores         = 2
#       memory        = 1
#       core_fraction = 5
#     }
#     scheduling_policy {
#       preemptible = true
#     }
#     network_interface {
#       subnet_id = "${yandex_vpc_subnet.foo.id}"
#       nat = true
#     }
#     boot_disk {
#       initialize_params {
#         type = "network-hdd"
#         size = "30"
#         image_id = data.yandex_compute_image.coi.id
#       }
#     }
#     metadata = {
#       docker-compose = file("${path.module}/docker-compose.yaml")
#       ssh-keys  = "ubuntu:${file("~/.ssh/github_yapl.pub")}"
#     }
# }

resource "yandex_compute_instance_group" "group1" {
  name                = "test-ig"
  folder_id           = local.folder_id
  service_account_id  = yandex_iam_service_account.service-accounts["yy-noted-catgpt-sa"].id
  deletion_protection = false
  instance_template {
    platform_id = "standard-v2"
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    boot_disk {
      initialize_params {
        type = "network-hdd"
        size = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    network_interface {
      network_id     = yandex_vpc_network.foo.id
      subnet_ids = ["${yandex_vpc_subnet.foo.id}"]
      nat = true
    }
    metadata = {
      docker-compose = file("${path.module}/docker-compose.yaml")
      ssh-keys  = "ubuntu:${file("~/.ssh/github_yapl.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 2
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
}
