#encoding: utf-8

require 'rubygems'
require 'yaml'
require 'logger'
require 'sequel'
require 'socket'
require 'openssl'
require 'cgi'

require 'rufus/scheduler'

require 'uri' 
require 'uri-handler'
require 'net/http'

require 'active_support'
require 'json'
require 'digest/sha2'

require 'will_paginate'
require 'will_paginate/sequel'

############################################################
## Initilization Setup
############################################################
LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '../..', 'lib'))
ROOTDIR = File.expand_path(File.join(File.dirname(__FILE__), '../..'))
unless $LOAD_PATH.include?(LIBDIR)
  $LOAD_PATH << LIBDIR
end

unless File.exist?("#{Dir.pwd}/ass.yml") then
  puts 'create config file: ass.yml'
  system "cp #{ROOTDIR}/ass.yml #{Dir.pwd}/ass.yml"
end

unless File.exist?("#{Dir.pwd}/cron") then
  puts "create a demo 'cron' script"
  system "cp #{ROOTDIR}/cron #{Dir.pwd}/cron"
end

############################################################
## Configuration Setup
############################################################
env = ENV['SINATRA_ENV'] || "development"
config = YAML.load_file("#{Dir.pwd}/ass.yml")
$timer = "#{config['timer']}".to_i
$cron = config['cron'] || 'cron'
$port = "#{config['port']}".to_i || 4567
$mode = config['mode'] || env
$VERSION = File.open("#{ROOTDIR}/VERSION", "rb").read
$apps = config['apps'] || []
$log = config['log'] || 'off'
$user = config['user'] || 'admin'
$pass = config['pass'] || 'pass'
$pempass = config['pempass'] || ''
$loglevel = config['loglevel'] || 'info'
$flood = "#{config['flood']}".to_i || 1  # default 1 minute

$client_ip = '127.0.0.1'
$last_access = 0

############################################################
## Certificate Key Setup
############################################################

$certkey = {}

def check_cert
  $apps.each { |app|
    unless File.exist?("#{Dir.pwd}/#{app}_#{$mode}.pem") then
      puts "Please provide #{app}_#{$mode}.pem under '#{Dir.pwd}/' directory"
      return false;
    else
      puts "'#{app}'s #{$mode} PEM: (#{app}_#{$mode}.pem)"
      certfile = File.read("#{Dir.pwd}/#{app}_#{$mode}.pem")
      openSSLContext = OpenSSL::SSL::SSLContext.new
      openSSLContext.cert = OpenSSL::X509::Certificate.new(certfile)
      if $pempass == '' then
        openSSLContext.key = OpenSSL::PKey::RSA.new(certfile) 
      else
        openSSLContext.key = OpenSSL::PKey::RSA.new(certfile,"#{$pempass}")
      end
      $certkey["#{app}"] = openSSLContext
    end
  }
  return true
end

unless check_cert then
  html = <<-END
1: please provide certificate key pem file under current directory, name should be: appid_development.pem for development and appid_production.pem for production
2: edit your ass.yml under current directory
3: run ass
4: iOS Client: in AppDelegate file, didRegisterForRemoteNotificationsWithDeviceToken method should access url below:
  END
  $apps.each { |app|
    html << "'#{app}'s registration url:  http://serverIP:#{$port}/v1/apps/#{app}/DeviceToken"
  }
  html << "5: Server: cron should access 'curl http://localhost:#{$port}/v1/app/push/{messages}/{pid}' to send push message"
  puts html
  exit
else
  html = <<-END
#{'*'*80}
Apple Service Server(#{$VERSION}) is Running ...
Push Notification Service: Enabled
Mode: #{$mode}
Port: #{$port}
  END
  html << "#{'*'*80}"
  html << "Cron Job: '#{Dir.pwd}/#{$cron}' script is running every #{$timer} #{($timer == 1) ? 'minute' : 'minutes'} " unless "#{$timer}".to_i == 0
  html << "\n"
  html << "access http://localhost:#{$port}/ for more information"
  html << "\n"
  html << "#{'*'*80}"
  puts html
end

############################################################
## Sequel Database Setup
############################################################

unless File.exist?("#{Dir.pwd}/ass-#{$mode}.db") then
  $DB = Sequel.connect("sqlite://#{Dir.pwd}/ass-#{$mode}.db")
  $DB.create_table :tokens do
    primary_key :id
    String :app, :unique => false, :null => false
    String :token, :unique => false, :null => false, :size => 100
    Time :created_at
    index [:app, :token]
  end
  $DB.create_table :pushes do
    primary_key :id
    String :pid, :unique => false, :null => false, :size => 100
    String :app, :unique => false, :null => false, :size => 30
    String :message, :unique => false, :null => false, :size => 107
    String :ip, :unique => false, :null => false, :size => 20
    Time :created_at
    index [:pid, :app, :message]
  end
else
  $DB = Sequel.connect("sqlite://#{Dir.pwd}/ass-#{$mode}.db")
end

class Token < Sequel::Model
  #Sequel.extension :pagination
end

class Push < Sequel::Model
  #Sequel.extension :pagination
end

############################################################
## Timer Job Setup
############################################################
scheduler = Rufus::Scheduler.new

unless $timer == 0 then
  scheduler.every "#{$timer}m" do
    puts "running job: '#{Dir.pwd}/#{$cron}' every #{$timer} #{($timer == 1) ? 'minute' : 'minutes'}"
    system "./#{$cron}"
  end
end