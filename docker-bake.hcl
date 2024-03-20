group "default" {
	targets = ["devcontainer", "jenkins-agent-dind"]
}

target "devcontainer" {
    context = "devcontainer"
}

target "jenkins-agent-dind" {
    context = "jenkins-agent-dind"
    contexts = {
        jenkins-agent-dind-base = "target:jenkins-agent-dind-base"
    }
}

target "jenkins-agent-dind-base" {
    context = "devcontainer"
    target = "user"
    args = {
        USER = "jenkins"
    }
}
