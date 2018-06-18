def call(String projName){
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
          sh 'kitchen test'
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
      stage('Approval') {
        when {
          // Only execute when on the master branch
          expression { env.BRANCH_NAME == 'master' }
        }
        steps {
          input 'Release to Production?'
        }
      }
      stage('Upload') {
        when {
          // Only execute when on the master branch
          expression { env.BRANCH_NAME == 'master' }
        }
        steps {
          sh '''
          cd ~/chef_repo/cookbooks/${proj_name}
          berks install
          berks upload --ssl-verify=false
          '''
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