def call(){
  pipeline {
    agent any
    stages {
      stage('Process Environment file(s)') {
        steps {
          sh 'chef exec ruby ~/chef_automation/generate_env_from_bu_json.rb -k ~/chef_repo/.chef/knife.rb'
        }
      }
      stage('Process Data Bags') {
        steps {
          sh 'chef exec ruby ~/chef_automation/create_data_bag_from_json.rb -f . -k ~/chef_repo/.chef/knife.rb'
        }
      }
    }
  }
}