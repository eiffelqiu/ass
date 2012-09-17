#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'sinatra'
require 'sequel'
require 'socket'
require 'openssl'
require 'cgi'
require 'rufus/scheduler'
require 'eventmachine'
require 'sinatra/base'
require 'yaml'

############################################################
## Initilization Setup
############################################################
LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
ROOTDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
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
$port = config['port'] || 4567
$mode = config['mode'] || env
$VERSION = File.open("#{ROOTDIR}/VERSION", "rb").read
$apps = config['apps'] || []

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
      openSSLContext.key = OpenSSL::PKey::RSA.new(certfile)   
      $certkey["#{app}"] = openSSLContext       
    end
  }  
  return true
end

unless check_cert then
  puts "1: please provide certificate key pem file under current directory, name should be: appid_dev.pem for development and appid_prod.pem for production"
  puts "2: edit your ass.yml under current directory"
  puts "3: run ass"
  puts "4: iOS Client: in AppDelegate file, didRegisterForRemoteNotificationsWithDeviceToken method should access url below:"
  $apps.each { |app|
    puts "'#{app}'s registration url:  http://serverIP:#{$port}/v1/apps/#{app}/DeviceToken"
  }
  puts "5: Server: cron should access 'curl http://localhost:#{$port}/v1/app/push/{messages}/{pid}' to send push message"
  exit
else
  puts "*"*80
  puts "Apple Service Server(#{$VERSION}) is Running ..."
  puts "Push Notification Service: Enabled"
  puts "Mode: #{$mode}"
  puts "Port: #{$port}"
  puts "Cron Job: '#{Dir.pwd}/#{$cron}' script is running every #{$timer} #{($timer == 1) ? 'minute' : 'minutes'} " unless "#{$timer}".to_i == 0
  puts "*"*80
end

############################################################
## Sequel Database Setup
############################################################

unless File.exist?("#{Dir.pwd}/ass.db") then
  $DB = Sequel.connect("sqlite://#{Dir.pwd}/ass.db")

  $DB.create_table :tokens do
    primary_key :id
    String :app, :unique => true, :null => false
    String :token, :unique => true, :null => false, :size => 100
    index [:app, :token]
  end

  $DB.create_table :pushes do
    primary_key :id
    String :pid, :unique => true, :null => false, :size => 100
    index :pid
  end
else
  $DB = Sequel.connect("sqlite://#{Dir.pwd}/ass.db")
end

Token = $DB[:tokens]
Push = $DB[:pushes]

############################################################
## Timer Job Setup
############################################################
scheduler = Rufus::Scheduler.start_new

unless $timer == 0 then
  scheduler.every "#{$timer}m" do
    puts "running job: '#{Dir.pwd}/#{$cron}' every #{$timer} #{($timer == 1) ? 'minute' : 'minutes'}"
    system "./#{$cron}"
  end
else
  puts "1: How to register notification? (Client Side)"
  puts
  puts "In AppDelegate file, inside didRegisterForRemoteNotificationsWithDeviceToken method access url below to register device token:"
  $apps.each { |app|
    puts "'#{app}'s registration url:  http://serverIP:#{$port}/v1/apps/#{app}/DeviceToken"
  }
  puts
  puts "2: How to send push notification? (Server Side)"
  puts
  $apps.each { |app|
    puts "curl http://localhost:#{$port}/v1/apps/#{app}/push/{message}/{pid}"
  }
  puts
  puts "Note:"
  puts "param1 (message): push notification message you want to send, remember the message should be html escaped"
  puts "param2 (pid    ): unique string to mark the message, for example current timestamp or md5/sha1 digest"
  puts
  puts "*"*80
end

############################################################
## Apple Service Server based on Sinatra
############################################################

class App < Sinatra::Base

  set :port, "#{$port}".to_i
  
  if "#{$mode}".strip == 'development' then
    set :show_exceptions, true
    set :dump_errors, true
  else
    set :show_exceptions, false
    set :dump_errors, false      
  end

  get '/' do
    o = "Apple Service Server #{$VERSION} <br/><br/>" + 
    "author: Eiffel(Q) <br/>email: eiffelqiu@gmail.com<br/><br/>"
    o += "1: How to register notification? (Client Side)<br/><br/>"
    o += "In AppDelegate file, inside didRegisterForRemoteNotificationsWithDeviceToken method access url below to register device token:<br/><br/>"
    $apps.each { |app|
      o += "'#{app}':  http://serverIP:#{$port}/v1/apps/#{app}/DeviceToken<br/>"
    }
    o += "<br/>2: How to send push notification? (Server Side)<br/><br/>"
    $apps.each { |app|
      o += "curl http://localhost:#{$port}/v1/apps/#{app}/push/{message}/{pid}<br/>"
    }
    o +=  "<br/>Note:<br/>"
    o +=  "param1 (message): push notification message you want to send, remember the message should be html escaped<br/>"
    o +=  "param2 (pid    ): unique string to mark the message, for example current timestamp or md5/sha1 digest<br/>"  
    o
  end

  $apps.each { |app|
    get "/v1/apps/#{app}/:token" do
      puts "[#{params[:token]}] was added to '#{app}'"
      o = Token.first(:token => params[:token])
      unless o
        Token.insert(
            :app => app,
            :token => params[:token]
        )
      end
    end

    get "/v1/apps/#{app}/push/:message/:pid" do
      message = CGI::unescape(params[:message])
      pid = params[:pid]

      puts "'#{message}' was sent to (#{app}) with pid: [#{pid}]"

      @push = Token.where(:app => app)
      @exist = Push.first(:pid => pid)

      unless @exist
        openSSLContext = $certkey["#{app}"]
        # Connect to port 2195 on the server.
        sock = nil
        if $mode == 'production' then
          sock = TCPSocket.new('gateway.push.apple.com', 2195)
        else
          sock = TCPSocket.new('gateway.sandbox.push.apple.com', 2195)
        end
        # do our SSL handshaking
        sslSocket = OpenSSL::SSL::SSLSocket.new(sock, openSSLContext)
        sslSocket.connect
        #Push.create( :pid => pid )
        Push.insert(:pid => pid)
        # write our packet to the stream
        @push.each do |o|
          tokenText = o[:token]
          # pack the token to convert the ascii representation back to binary
          tokenData = [tokenText].pack('H*')
          # construct the payload
          payload = "{\"aps\":{\"alert\":\"#{message}\", \"badge\":1}}"
          # construct the packet
          packet = [0, 0, 32, tokenData, 0, payload.length, payload].pack("ccca*cca*")
          # read our certificate and set up our SSL context
          sslSocket.write(packet)
        end
        # cleanup
        sslSocket.close
        sock.close
      end
    end
  }
end