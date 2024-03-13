group "default" {
	targets = ["devcontainer", "jenkins-agent-dind"]
}

target "devcontainer" {
    context = "devcontainer"
}

target "jenkins-agent-dind" {
    context = "jenkins-agent-dind"
    contexts = {
        devcontainer-jenkins-agent-dind = "target:devcontainer-jenkins-agent-dind"
    }
}

target "devcontainer-jenkins-agent-dind" {
    context = "devcontainer"
    target = "non-root-user"
    args = {
        "NON_ROOT_USER" = "jenkins"
    }
}
