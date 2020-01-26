pipeline {
	agent any
        stages {
        	stage('Echo') {
                	steps { 
                        	sh 'echo felipe' 
                        }
                  
                }
                stage("Display changeset?") {
                  when {
                      changeset 'Jenkinsfile'
                  }
                  steps { 
                      sh 'echo Jenkins!!!' 
                  }
        	}	
        }
}