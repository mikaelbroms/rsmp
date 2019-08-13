#!/usr/bin/env ruby
# Note: the shebang above expects ruby to be intalled through rbenv
#
# Executable wrapper for starting an RSMP supervisor (server)
# Expect a settings files to be present at config/supervisor.yaml

require_relative 'supervisor'
require 'optparse'

dir = File.dirname(__FILE__)
options = {
	supervisor_settings_path: File.expand_path(File.join(dir,'config/supervisor.yaml')), 
	sites_settings_path: File.expand_path(File.join(dir,'config/sites.yaml')),
	supervisor_settings: {}
}

supervisor_settings = {}
options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: supervisor [options]"
  opts.on("-p PORT", "--port P", Integer, "Listen on port P") do |port|
    options[:supervisor_settings][:port] = port
  end
  opts.on( '-h', '--help', 'Show help' ) do
    puts opts
    exit
  end
end

begin
	options_parser.parse!
rescue OptionParser::ParseError => e
    puts e
    puts options_parser
    exit 1
end

supervisor = RSMP::Supervisor.new(options)
Async do 
	supervisor.start
	site = supervisor.wait_for_site 'RN+SI0001', 3
	if site
		puts "got site"
		#puts supervisor.wait_for_site_disconnect 'RN+SI0001', 3
	else
		puts "timeout"
	end
end

