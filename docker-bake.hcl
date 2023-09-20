function "create_tags" {
	params = [image_name]
    variadic_params = tags

    result = concat(
        [for t in tags : "${image_name}:${t}"], 
        [for t in tags : "ghcr.io/${image_name}:${t}"]
    )
}

variable "IMAGE_NAME" {
	default = "felipecrs/devcontainer"
}

group "default" {
	targets = ["base", "github"]
}

target "base" {
    context = "."
	dockerfile = "Dockerfile"
    target = "base"
	tags = create_tags("${IMAGE_NAME}", "latest", "base")
    cache-to = ["type=inline"]
}

target "github" {
    inherits = ["base"]
    target = "github"
    tags = create_tags("${IMAGE_NAME}", "github")
}
