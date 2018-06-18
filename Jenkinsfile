pipeline {
  agent any
  stages {
    stage('Pre-req Tests') {
      parallel {
        stage('Check ChefDK') {
          steps {
            sh '''
            # Make sure ChefDK is installed
            if [ ! $(which chef) ]; then
              echo "ChefDK is missing! Please visit https://downloads.chef.io."
              exit 1
            fi
            '''
          }
        }
        stage('Check the chef_repo') {
          steps {
            sh '''
            if [ ! -d "/var/lib/jenkins/chef_repo/.chef" ]; then
              mkdir -p /var/lib/jenkins/chef_repo/.chef
            fi
            if [ ! -f "/var/lib/jenkins/chef_repo/.chef/knife.rb" ]; then
              echo "WARNING"
              echo "We are creating empty files so the setup can proceed."
              echo "Replace the contents of /var/lib/jenkins/chef_repo/.chef/knife.rb with your information"
              touch /var/lib/jenkins/chef_repo/.chef/knife.rb
            fi
            if [ ! -f "/var/lib/jenkins/chef_repo/.chef/client.pem" ]; then
              touch /var/lib/jenkins/chef_repo/.chef/client.pem
            fi
            '''
          }
        }
      }
    }
    stage('Verify Ruby files') {
      steps {
        sh 'chef exec rubocop utilities/.'
      }
    }
    stage('Stage Utilities') {
      steps {
        sh '''
        if [ ! -d "/var/lib/jenkins/chef_automation" ]; then
          mkdir -p /var/lib/jenkins/chef_automation
        fi
        cp utilities/* /var/lib/jenkins/chef_automation/
        '''
      }
    }
  }
}