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

  set :root, File.expand_path('../../../', __FILE__)
  set :port, "#{$port}".to_i
  set :public_folder, File.dirname(__FILE__) + '/../../public'
  set :views, File.dirname(__FILE__) + '/../../views'

  helpers do

    include Rack::Utils
    alias_method :h, :escape_html    

    def connect_socket(app)
      openSSLContext = $certkey["#{app}"]
      sock = nil
      sslSocket = nil;
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