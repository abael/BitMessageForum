require 'sinatra/base'
require 'sinatra/reloader'
require 'haml'
require_relative 'message_store.rb'
require_relative 'address_store.rb'

class BMF < Sinatra::Base

  set :server, 'thin'
  set :root, File.expand_path("../../", __FILE__)
  set :layout, :layout

  configure :development do
    register Sinatra::Reloader
  end

  def folder folder_name
    case folder_name
    when "chans"
      MessageStore.instance.chans
    when "inbox"
      MessageStore.instance.inbox
    when "lists"
      MessageStore.instance.lists
    else
      raise "BADFOLDER"
    end
  end

  def sync
    MessageStore.instance.update
    AddressStore.instance.update
  rescue Errno::ECONNREFUSED => ex
    halt(500, "Couldn't connect to PyBitmessage server.  Is it running and enabled? ")
  rescue XmlrpcClientError => ex
    halt(500, "XmlrpcClient issued error '#{ex.message}'.  Do you have the correct information in keys.dat? ")
  end




  get "/", :provides => :html do
    sync

    @messages = folder("inbox")
    @addresses = AddressStore.instance.addresses
    haml :threaded_messages
  end

  get "/messages/compose/", :provides => :html do
    @to = params[:to]
    @from = params[:from]
    @subject = params[:subject]
    @message = params[:message]
    haml :compose
  end

  post "/messages/send/", :provides => :html do
    to = params[:to]
    from = params[:from]
    subject = Base64.encode64(params[:subject])
    message = Base64.encode64(params[:message])

    res = XmlrpcClient.instance.sendMessage(to, from, subject, message)
    if XmlrpcClient.is_error? res
      halt(500, haml(res))
    else
      haml "Sent.  Confirmation #{res}"
    end
  end

  get "/:folder/", :provides => :html do
    sync

    @messages = folder params[:folder]
    
    @addresses = AddressStore.instance.addresses
    haml :addresses
  end

  get "/:folder/:address/", :provides => :html do
    sync
    
    @address, @threads = folder(params[:folder]).detect {|address, threads| address == params[:address] }
    @addresses = AddressStore.instance.addresses

    haml :threads
    
  end

  get "/:folder/:address/:thread", :provides => :html do
    sync
    
    @address, threads = folder(params[:folder]).detect {|address, threads| address == params[:address] }
    @thread, @messages = threads.detect do |thread, messages|
      # puts messages.inspect
      thread == CGI.unescape(params[:thread])
    end
    
    
    @addresses = AddressStore.instance.addresses

    haml :messages


  end

  run! if app_file == $0

end

