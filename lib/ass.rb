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
lib_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
root_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
unless $LOAD_PATH.include?(lib_dir)
  $LOAD_PATH << lib_dir
end

unless File.exist?("#{Dir.pwd}/ass.yml") then
  puts 'create config file: ass.yml'
  system "cp #{root_dir}/ass.yml #{Dir.pwd}/ass.yml"
end

unless File.exist?("#{Dir.pwd}/cron") then
  puts "create a demo 'cron' script"
  system "cp #{root_dir}/cron #{Dir.pwd}/cron"
end

############################################################
## Configuration Setup
############################################################
env = ENV['SINATRA_ENV'] || "development"
config = YAML.load_file("#{Dir.pwd}/ass.yml")
$timer = config['timer'] || 1
$cron = config['cron'] || 'cron'
$port = config['port'] || 4567
$mode = config['mode'] || env
$certificate = config["#{$mode}"][0]['certificate'] || 'ck.pem'
ROOTDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
VERSION = File.open("#{ROOTDIR}/VERSION", "rb").read
$apps = config['apps'] || []

############################################################
## Certificate Key Setup
############################################################

unless File.exist?("#{Dir.pwd}/#{$certificate}") then
  puts "1: please provide certificate key pem file under current directory"
  puts "2: edit your ass.yml under current directory"
  puts "3: run spns"
  puts "4: iOS Client: in AppDelegate file, didRegisterForRemoteNotificationsWithDeviceToken method should access url below:"
  $apps.each { |app|
    puts "'#{app}'s registration url:  http://serverIP:#{$port}/v1/apps/#{app}/DeviceToken"
  }
  puts "5: Server: cron should access 'curl http://localhost:#{$port}/v1/app/push/#{messages}/#{pid}' to send push message"
  exit
else
  puts "*"*80
  puts "Simple Push Notification Server is Running (#{VERSION}) ..."
  puts "Mode: #{$mode}"
  puts "Port: #{$port}"
  puts "Certificate File: '#{Dir.pwd}/#{$certificate}'"
  puts "Cron Job: '#{Dir.pwd}/#{$cron}' script is running every #{$timer} #{($timer == 1) ? 'minute' : 'minutes'} " unless "#{$timer}".squeeze.strip == "0"
  puts "*"*80
end

$cert = File.read("#{Dir.pwd}/#{$certificate}")
$openSSLContext = OpenSSL::SSL::SSLContext.new
$openSSLContext.cert = OpenSSL::X509::Certificate.new($cert)
$openSSLContext.key = OpenSSL::PKey::RSA.new($cert)

############################################################
## Sequel Database Setup
############################################################

DB = nil;

unless File.exist?("#{Dir.pwd}/push.db") then
  DB = Sequel.connect("sqlite://#{Dir.pwd}/push.db")

  DB.create_table :tokens do
    primary_key :id
    String :app, :unique => true, :null => false
    String :token, :unique => true, :null => false, :size => 100
    index [:app, :token]
  end

  DB.create_table :pushes do
    primary_key :id
    String :pid, :unique => true, :null => false, :size => 100
    index :pid
  end
else
  DB = Sequel.connect("sqlite://#{Dir.pwd}/push.db")
end

Token = DB[:tokens]
Push = DB[:pushes]

############################################################
## Timer Job Setup
############################################################
scheduler = Rufus::Scheduler.start_new

unless "#{$timer}".squeeze.strip == "0"
  scheduler.every "#{$timer}m" do
    puts "running job: '#{Dir.pwd}/#{$cron}' every #{$timer} #{($timer == 1) ? 'minute' : 'minutes'}"
    system "./#{$cron}"
  end
else
  puts
  puts "*"*80
  puts "How to register notification?"
  puts
  puts "iOS Client: in AppDelegate file, didRegisterForRemoteNotificationsWithDeviceToken method should access url below:"
  $apps.each { |app|
    puts "'#{app}'s registration url:  http://serverIP:#{$port}/v1/apps/#{app}/DeviceToken"
  }
  puts
  puts "How to send push notification?"
  puts
  $apps.each { |app|
    puts "curl http://localhost:#{$port}/v1/apps/#{app}/push/{message}/{pid}"
  }
  puts
  puts "Note:"
  puts "message: notification message you want to send, remember the message should be html escaped"
  puts "pid: unique id that you mark the message, for example current timestamp"
  puts
  puts "*"*80
  puts
end

############################################################
## Simple Push Notification Server based on Sinatra
############################################################

class App < Sinatra::Base

  set :port, "#{$port}".to_i

  get '/' do
    puts "Simple Push Notification Server"
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
        # Connect to port 2195 on the server.
        sock = nil
        if $mode == 'production' then
          sock = TCPSocket.new('gateway.push.apple.com', 2195)
        else
          sock = TCPSocket.new('gateway.sandbox.push.apple.com', 2195)
        end
        # do our SSL handshaking
        sslSocket = OpenSSL::SSL::SSLSocket.new(sock, $openSSLContext)
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