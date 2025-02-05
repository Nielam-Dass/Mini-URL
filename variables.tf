variable "docker_image_tag" {
    description = "Tag for app's Docker image"
    type = string
    default = "nielamdass/mini-url-app:latest"
}

variable "docker_container_port" {
    description = "Docker container port serving application"
    type = number
    default = 5000
}
