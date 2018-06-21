def call(){
  pipeline {
    agent any
    stages {
      stage('Stage Environments') {
        steps {
          sh '''
          if [ ! -d "/var/lib/jenkins/chef_automation/global_envs" ]; then
            mkdir -p /var/lib/jenkins/chef_automation/global_envs
          fi
          cp * /var/lib/jenkins/chef_automation/global_envs/
          '''
        }
      }
      stage('Publish Environments to Production') {
        steps {
          input 'Publish Enviornments to Production Chef Server?'
          sh 'chef exec ruby /var/lib/jenkins/chef_automation/update_global_env_pins.rb -k /var/lib/jenkins/chef_repo/.chef/knife.rb -f /var/lib/jenkins/chef_automation'
        }
      }
    }
  }
}
