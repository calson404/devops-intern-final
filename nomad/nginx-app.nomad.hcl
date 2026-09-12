# nginx-app.nomad.hcl
#
# Deploys the NGINX image built by CI (Task 4) to Nomad.
# Image comes from GHCR; the tag is parameterised for reproducible rollouts.

variable "image_tag" {
  type        = string
  description = "GHCR tag of the devops-intern-final image (use the commit SHA, never 'latest' alone)."
}

variable "image_repo" {
  type        = string
  description = "GHCR repository for the image."
  default     = "ghcr.io/calson404/devops-intern-final"
}

job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "2m"
    auto_revert      = true
    canary           = 0
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    restart {
      attempts = 3
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 2
      interval       = "30m"
      delay          = "15s"
      delay_function = "exponential"
      max_delay      = "30s"
      unlimited      = false
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "${var.image_repo}:${var.image_tag}"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }

      service {
        name     = "nginx-app"
        port     = "http"
        provider = "consul"

        check {
          name     = "nginx-app /healthz"
          type     = "http"
          path     = "/healthz"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
