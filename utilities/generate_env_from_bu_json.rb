require 'json'
require 'optparse'
require 'chef'

# Get the options from the command line
options = { knife: nil }

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: generate_env_from_bu_json.rb [options]'
  opts.on('-k', '--knife /path/to/my/knife.rb', 'Knife Path') do |knife|
    options[:knife] = knife
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end

parser.parse!

# Ask if the user missed an option
if options[:knife].nil?
  print 'Enter path to knife.rb: '
  options[:knife] = gets.chomp
end

# Setup connection to Chef Server
Chef::Config.from_file(options[:knife])
rest = Chef::ServerAPI.new(Chef::Config[:chef_server_url])

puts 'Attempting to load JSON files from the ./environments folder of the repository.'

# Loop through all json files in the environments folder
Dir['./environments/*.json'].each do |item|
  # Parse the file and merge

  begin
    bu_env = JSON.parse(File.read(item))
    env_name = bu_env['name']
    puts "Successfully loaded the #{env_name} environment."
  rescue StandardError
    abort("Failed to load the #{env_name} environment.")
  end

  begin
    global_env = JSON.parse(File.read("/var/lib/jenkins/chef_automation/global_envs/#{env_name}.json"))
  rescue StandardError
    abort("Can't open /var/lib/jenkins/chef_automation/global_envs/#{env_name}.json.")
  end

  begin
    env = Chef::Mixin::DeepMerge.deep_merge(global_env, bu_env)
    puts "Successfully merged the #{env_name} environment."
    puts 'Result of merge:'
    puts JSON.pretty_generate(env)
  rescue StandardError
    abort("Failed to merge the #{env_name} environment.")
  end

  # Compare env with what's on the Chef server
  result = rest.get_rest("/environments/#{env_name}")
  puts "Result from Chef server for the #{env_name} environment."
  puts JSON.pretty_generate(result)
  if env == result
    puts "No change for the #{env_name} environment"
  else
    puts "Change detected in #{env_name}"
    # Verify cookbooks and versions
    cookbooks = Marshal.load(Marshal.dump(env))
    cookbooks['cookbook_versions'].each do |cookbook, version|
      # Strip out operator characters from the json data
      version.tr!('=', '') if version.include?('=')
      version.tr!('>', '') if version.include?('>')
      version.tr!('<', '') if version.include?('<')
      version.tr!('~', '') if version.include?('~')
      version.tr!(' ', '') if version.include?(' ')

      begin
        rest.get_rest("/cookbooks/#{cookbook}/#{version}")
        puts "SUCCESS! Found #{cookbook}/#{version}!"
      rescue StandardError
        abort("FAILURE! Couldn't find #{cookbook}/#{version} on Chef server.")
      end
    end

    # Save a copy of the validated environment file to disk
    File.write("/var/lib/jenkins/chef_repo/environments/#{env_name}.json", JSON.pretty_generate(env))

    # Attempt to save the change to the Chef server.
    begin
      rest.put_rest("/environments/#{env_name}", env)
      puts "Successfully updated #{env_name}"
    rescue StandardError
      abort("Failed to update #{env_name}")
    end
  end
end
