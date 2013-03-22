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
require 'uri-handler'
require 'active_support'
require 'json'

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
$log = config['log'] || 'off'
$user = config['user'] || 'admin'
$pass = config['pass'] || 'pass'

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
  html = <<-END
1: please provide certificate key pem file under current directory, name should be: appid_dev.pem for development and appid_prod.pem for production
2: edit your ass.yml under current directory
3: run ass
4: iOS Client: in AppDelegate file, didRegisterForRemoteNotificationsWithDeviceToken method should access url below:
END
  $apps.each { |app|
    html << "'#{app}'s registration url:  http://serverIP:#{$port}/v1/apps/#{app}/DeviceToken"
  }
  html <<  "5: Server: cron should access 'curl http://localhost:#{$port}/v1/app/push/{messages}/{pid}' to send push message"
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

unless File.exist?("#{Dir.pwd}/ass.db") then
  $DB = Sequel.connect("sqlite://#{Dir.pwd}/ass.db")

  $DB.create_table :tokens do
    primary_key :id
    String :app, :unique => false, :null => false
    String :token, :unique => false, :null => false, :size => 100
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
end

############################################################
## Apple Service Server based on Sinatra
############################################################

class App < Sinatra::Base
  
  set :root, File.expand_path('../../', __FILE__)
  set :port, "#{$port}".to_i
  set :public_folder, File.dirname(__FILE__) + '/../public'
  set :views, File.dirname(__FILE__) + '/../views'   
  
  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ["#{$user}","#{$pass}"]
  end

  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Oops... we need your login name & password\n"])
    end
  end

  configure :production, :development do
    if "#{$log}".strip == 'on' then
      enable :logging 
    end
  end  

  if "#{$mode}".strip == 'development' then
    set :show_exceptions, true
    set :dump_errors, true
  else
    set :show_exceptions, false
    set :dump_errors, false
  end
  
  get "/v1/apps/admin/:app/tokens" do
    protected!
    @o = Token.where(:app => params[:app])
    erb :tokens, :layout => :article_layout
  end  
  
  get "/v1/apps/admin/:app/pushes" do
    protected!
    #@o = Token.where(:app => params[:app])
    @o = Push.all
    erb :pushes, :layout => :article_layout
  end    

  get '/' do
    erb :index
  end

  $apps.each { |app|
    
    ## register token api
    get "/v1/apps/#{app}/:token" do
      puts "[#{params[:token]}] was added to '#{app}'" if "#{$mode}".strip == 'development' 
      o = Token.first(:app => app , :token => params[:token])
      unless o
        Token.insert(
            :app => app,
            :token => params[:token]
        )
      end
    end
    
    ## http POST method push api
    post "/v1/apps/#{app}/push" do
      message = CGI::unescape(params[:alert] || "")
      badge =  1
      puts "params[:badge] = [#{params[:badge]}]"
      badge = params[:badge].to_i if params[:badge] and params[:badge] != ''
      sound = CGI::unescape(params[:sound] || "") 
      extra = CGI::unescape(params[:extra] || "")
      
      puts "#{badge} : #{message} extra: #{extra}" if "#{$mode}".strip == 'development' 
      pid = params[:pid]

      puts "'#{message}' was sent to (#{app}) with pid: [#{pid}], badge:#{badge} , sound: #{sound}, extra:#{extra}" if "#{$mode}".strip == 'development' 

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
          po = {:aps => {:alert => "#{message}", :badge => badge , :sound => "#{sound}" }, :extra => "#{extra}" }
          payload = ActiveSupport::JSON.encode(po)
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

    ## http GET method push api
    get "/v1/apps/#{app}/push/:message/:pid" do
      message = CGI::unescape(params[:message])
      puts message if "#{$mode}".strip == 'development' 
      pid = params[:pid]

      puts "'#{message}' was sent to (#{app}) with pid: [#{pid}]" if "#{$mode}".strip == 'development' 

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
          po = {:aps => {:alert => "#{message}", :badge => 1}}
          payload = ActiveSupport::JSON.encode(po)
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