require 'json'
require 'optparse'
require 'chef'
require 'pathname'

# Get the options from the command line
options = { folder: nil, knife: nil }

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: create_data_bag_from_json.rb [options]'
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
  print 'Enter path to data bag folder: '
  options[:folder] = gets.chomp
end
if options[:knife].nil?
  print 'Enter path to knife.rb: '
  options[:knife] = gets.chomp
end

# Setup connection to Chef Server
Chef::Config.from_file(options[:knife])
rest = Chef::ServerAPI.new(Chef::Config[:chef_server_url])

# Test and make sure the directory that was passed actually exists...
abort("ERROR: File: #{options[:folder]}/data_bags does not exist!") unless Dir.exist?("#{options[:folder]}/data_bags")

Dir["#{options[:folder]}/data_bags/*/*.json"].each do |item|
  data_bag_name = File.basename(File.dirname(item))
  data_bag_item = JSON.parse(File.read(item))

  # See if the data bag exists, if not, create it.
  begin
    rest.get_rest("/data/#{data_bag_name}")
    puts "Found #{data_bag_name}"
  rescue StandardError
    puts "Data Bag #{data_bag_name} not found, attempting to create"
    json = { name: data_bag_name }
    begin
      rest.post_rest('/data', json)
      puts "Successfully created #{data_bag_name}"
    rescue StandardError
      puts "Failed to create #{data_bag_name}"
    end
  end

  # Now that the data bag is there, let's see if it needs updating
  begin
    current_data_bag_item = rest.get_rest("/data/#{data_bag_name}/#{data_bag_item['id']}")
    puts "Found Data Bag Item: #{data_bag_item['id']}"
    if current_data_bag_item == data_bag_item
      puts 'Data bag item is current, no need to update.'
    else
      begin
        rest.put_rest("/data/#{data_bag_name}/#{data_bag_item['id']}", data_bag_item)
        puts "Successfully updated #{data_bag_name}/#{data_bag_item['id']}"
      rescue StandardError
        puts "Failed to update #{data_bag_name}/#{data_bag_item['id']}"
      end
    end
  rescue StandardError
    begin
      rest.post_rest("/data/#{data_bag_name}", data_bag_item)
      puts "Successfully added #{data_bag_name}/#{data_bag_item['id']}"
    rescue StandardError
      puts "Failed to add #{data_bag_name}/#{data_bag_item['id']}"
    end
  end
end
