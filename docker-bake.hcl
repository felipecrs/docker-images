function "create_tags" {
	params = [image_name]
    variadic_params = tags
    
    result = concat(
        [for t in tags : "${image_name}:${t}"], 
        [for t in tags : "ghcr.io/${image_name}:${t}"]
    )
}

group "default" {
	targets = ["devcontainer"]
}

variable "DEVCONTAINER_IMAGE_NAME" {
	default = "felipecrs/devcontainer"
}

group "devcontainer" {
	targets = ["devcontainer-base", "devcontainer-github"]
}

target "devcontainer-base" {
    context = "images/devcontainer"
	dockerfile = "Dockerfile"
    target = "base"
	tags = create_tags("${DEVCONTAINER_IMAGE_NAME}", "latest", "base")
    cache-to = ["type=inline"]
}

target "devcontainer-github" {
    inherits = ["devcontainer-base"]
    target = "github"
	tags = create_tags("${DEVCONTAINER_IMAGE_NAME}", "github")
}
