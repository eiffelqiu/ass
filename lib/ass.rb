#encoding: utf-8

require 'rubygems'
require 'yaml'
require 'logger'
require 'sequel'
require 'socket'
require 'openssl'
require 'cgi'

require 'rufus/scheduler'
require 'eventmachine'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/synchrony'
require 'rack/mobile-detect'

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

WillPaginate.per_page = 10

class Token < Sequel::Model
  Sequel.extension :pagination
end

class Push < Sequel::Model
  Sequel.extension :pagination
end

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
  
  register Sinatra::Synchrony

  use Rack::MobileDetect

  enable :logging
  
  LOGGER = Logger.new("ass-#{$mode}.log", 'a+')

  case $loglevel.upcase
  when 'FATAL'
    set :logging, Logger::FATAL
  when 'ERROR'
    set :logging, Logger::ERROR
  when 'WARN'
    set :logging, Logger::WARN
  when 'INFO'
    set :logging, Logger::INFO   
  when 'DEBUG'
    set :logging, Logger::DEBUG        
  else
    set :logging, Logger::DEBUG
  end  

  if "#{$mode}".strip == 'production' then
    set :environment, :production 
  else
    set :environment, :development    
  end

  set :root, File.expand_path('../../', __FILE__)
  set :port, "#{$port}".to_i
  set :public_folder, File.dirname(__FILE__) + '/../public'
  set :views, File.dirname(__FILE__) + '/../views'

  helpers do

    include Rack::Utils
    alias_method :h, :escape_html    

    def connect_socket(app)
      openSSLContext = $certkey["#{app}"]
      sock = nil
      if $mode == 'production' then
        sock = TCPSocket.new('gateway.push.apple.com', 2195)
      else 
        sock = TCPSocket.new('gateway.sandbox.push.apple.com', 2195)
      end
      sslSocket = OpenSSL::SSL::SSLSocket.new(sock, openSSLContext)
      sslSocket.connect

      [sock, sslSocket]
    end    

    def logger
      LOGGER
    end

    def checkFlood?(req)
      if $client_ip != "#{req.ip}" then
        $client_ip = "#{req.ip}"
        return false
      else
        if $last_access == 0 then
          return false
        else
          return isFlood?
        end
      end      
    end

    def isFlood?
        result = (Time.now - $last_access) < $flood * 60
        $last_access = Time.now
        return result
    end

    def iOS? 
      result = case request.env['X_MOBILE_DEVICE']
            when /iPhone|iPod|iPad/ then
              true
            else false
            end
      return result     
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ["#{$user}", "#{$pass}"]
    end

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Oops... we need your login name & password\n"])
      end
    end

    def push(parameter)
      message = CGI::unescape(parameter[:alert].encode("UTF-8") || "")[0..107]
      pid = "#{parameter[:pid]}"
      badge = 1
      badge = parameter[:badge].to_i if parameter[:badge] and parameter[:badge] != ''
      sound = CGI::unescape(parameter[:sound] || "")
      extra = CGI::unescape(parameter[:extra] || "")         

      @tokens = Token.where(:app => "#{app}").reverse_order(:id)
      @exist = Push.first(:pid => "#{pid}", :app => "#{app}")      

      unless @exist
        Push.insert(:pid => pid, 
                    :message => message, 
                    :created_at => Time.now, 
                    :app => "#{app}",
                    :ip => "#{parameter.ip}" ) 
        
        sock, sslSocket = connect_socket("#{app}")      

        # write our packet to the stream
        @tokens.each do |o|
          begin
            tokenText = "#{o[:token]}"
            tokenData = [tokenText].pack('H*')
            aps = {'aps'=> {}}
            aps['aps']['alert'] = message
            aps['aps']['badge'] = badge
            aps['aps']['sound'] = sound
            aps['aps']['extra'] = extra
            pm = aps.to_json
            packet = [0,0,32,devData,0,pm.bytesize,pm].pack("ccca*cca*")
            sslSocket.write(packet)  
          rescue Errno::EPIPE, OpenSSL::SSL::SSLError => e
            puts "e: #{e} from id:#{o[:id]}"
            sleep 3
            sock, sslSocket = connect_socket("#{app}")
            next
            #retry
          end              
        end
        # cleanup
        sslSocket.close
        sock.close
      end      
    end

    def localonly(req)
      protected! unless req.host == 'localhost'
    end

  end  

  before do
    if "#{$mode}".strip == 'development' then
      enable :dump_errors, :raise_errors, :show_exceptions
    else
      disable :dump_errors, :raise_errors, :show_exceptions
    end
  end

  get '/' do
    erb :index
  end

  get '/about' do
    erb :about
  end

  not_found do
    erb :not_found
  end  

  error do
    @error = "";
    @error = params['captures'].first.inspect if development?
  end  

  post '/v1/send' do
    app = params[:app]
    message = CGI::escape(params[:message] || "").encode("UTF-8")   
    pid = "#{Time.now.to_i}"   
    # begin  
    #   url = URI.parse("http://localhost:#{$port}/v1/apps/#{app}/push")
    #   post_args1 = { :alert => "#{message}".encode('UTF-8'), :pid => "#{pid}" }
    #   Net::HTTP.post_form(url, post_args1) 
    # rescue =>err  
    #   puts "#{err.class} ##{err}"  
    # end  
    system "curl http://localhost:#{$port}/v1/apps/#{app}/push/#{message}/#{pid}"  
    redirect '/v1/admin/push' if (params[:app] and  params[:message])
  end  

  get "/v1/admin/:db" do
    protected!
    db = params[:db] || 'token'
    page = 1
    page = params[:page].to_i if params[:page]
    if (db == 'token') then 
      @o = []
      $apps.each_with_index { |app, index|
        @o << Token.where(:app => app).order(:id).reverse.paginate(page, 20)
      }
      erb :token
    elsif (db == 'push') then 
      @p = []
      $apps.each_with_index { |app, index|
        @p << Push.where(:app => app).order(:id).reverse.paginate(page, 20)
      }
      erb :push
    else
      erb :not_found
    end
  end  

  $apps.each { |app|

    ## register token api
    get "/v1/apps/#{app}/:token" do
      if (("#{params[:token]}".length == 64) and iOS? and checkFlood?(request) ) then
        o = Token.first(:app => app, :token => params[:token])
        unless o
          Token.insert(
              :app => app,
              :token => params[:token],
              :created_at => Time.now
          )
        end
      end
    end

    ## http POST method push api
    post "/v1/apps/#{app}/push" do
      localonly(request)
      push(params)
    end

    ## http GET method push api 
    ## POST method get more options
    get "/v1/apps/#{app}/push/:message/:pid" do
      localonly(request)
      push(params)
    end
  }
end