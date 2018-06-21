require 'json'
require 'optparse'
require 'chef'
require 'pathname'
# Get the options from the command line
options = { folder: nil, knife: nil }

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: update_global_env_pins.rb [options]'
  opts.on('-f', '--folder /path/to/my/folder', 'Folder Name') do |folder|
    options[:folder] = folder
  end

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
if options[:folder].nil?
  print 'Enter path to project folder: '
  options[:folder] = gets.chomp
end
if options[:knife].nil?
  print 'Enter path to knife.rb: '
  options[:knife] = gets.chomp
end

# Setup connection to Chef Server
Chef::Config.from_file(options[:knife])
rest = Chef::ServerAPI.new(Chef::Config[:chef_server_url])

Dir["#{options[:folder]}/global_envs/*.json"].each do |item|
  bu_env = JSON.parse(File.read(item))
  env_name = File.basename(item, File.extname(item))
  puts "Processing the #{env_name} environment file."
  # If the env doesn't exist, create it
  begin
    result = rest.get_rest("/environments/#{env_name}")
  rescue Net::HTTPServerException => e
    if e.response.code == "404"
      puts "Attempting to create the #{env_name} environment"
      rest.post_rest("/environments/#{env_name}")
      result = rest.get_rest("/environments/#{env_name}")
      puts "Successfully created the #{env_name} environment"
    else
      abort("failed to create the #{env_name} environment")
    end
  end

  env = Chef::Mixin::DeepMerge.deep_merge(bu_env, result)

  # Pull the env from the chef server again b/c
  # deep_merge is doing something weird with the variables....
  result = rest.get_rest("/environments/#{env_name}")

  if env == result
    puts "No change for the #{env_name} environment"
  else
    puts "Change detected in #{env_name}"
    begin
      rest.put_rest("/environments/#{env_name}", env)
      puts "Successfully updated #{env_name}"
    rescue StandardError
      abort("Failed to update #{env_name}")
    end

  end
end
