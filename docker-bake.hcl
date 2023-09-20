group "default" {
	targets = ["base", "github"]
}

target "base" {
    context = "."
    target = "base"
    cache-to = ["type=inline"]
}

target "github" {
    inherits = ["base"]
    target = "github"
}
