def call(String projName, String[] groupNames){
  pipeline {
    agent any
    stages {
      stage('Pre-Cleanup') {
        steps {
          sh '''
            rm -rf ~/chef_repo/cookbooks/${proj_name}
          '''
        }
      }
      stage('Verify') {
        parallel {
          stage('Lint') {
            steps {
              sh 'chef exec foodcritic .'
            }
          }
          stage('Syntax') {
            steps {
              sh 'chef exec cookstyle .'
            }
          }
          stage('Unit') {
            steps {
              sh 'chef exec rspec .'
            }
          }
        }
      }
      stage('Smoke') {
        steps {
          sh '# kitchen test'
        }
      }
      stage('Stage files') {
        when {
          // Only execute when on the master branch
          expression { env.BRANCH_NAME == 'master' }
        }
        steps {
          sh '''
            mkdir -p ~/chef_repo/cookbooks/${proj_name}
            cp -r * ~/chef_repo/cookbooks/${proj_name}
          '''
        }
      }
      stage('Generate Lock File') {
        when {
          // Only execute when on the master branch
          expression { env.BRANCH_NAME == 'master' }
        }
        steps {
          sh '''
            cd ~/chef_repo/cookbooks/${proj_name}
            chef install
          '''
        }
      }
      stage('Deployment') {
        when {
          // Only execute when on the master branch
          expression { env.BRANCH_NAME == 'master' }
        }
        parallel {
          groupNames.each {
            stage('Approval') {
              
              steps {
                input 'Push ${proj_name} to the ${it} Policy Group?'
              }
            }
            stage('Upload') {
              steps {
                sh '''
                cd ~/chef_repo/cookbooks/${proj_name}
                chef push ${it}
                '''
              }
            }
          }
        }
      }
      stage('Post-Cleanup') {
        when {
          // Only execute when on the master branch
          expression { env.BRANCH_NAME == 'master' }
        }
        steps {
          sh '''
            rm -rf ~/chef_repo/cookbooks/${proj_name}
          '''
        }
      }
    }
    environment {
      proj_name = "${projName}"
    }
  }
}