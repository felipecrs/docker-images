group "default" {
	targets = ["devcontainer", "jenkins-agent-dind"]
}

target "base" {
    context = "."
}

target "devcontainer" {
    inherit = "base"
    target = "devcontainer"
}

target "jenkins-agent-dind" {
    inherit = "base"
    target = "jenkins-agent-dind"
}
