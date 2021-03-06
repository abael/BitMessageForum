require 'singleton'
require 'base64'
require 'json'
require 'thread'

require_relative 'xmlrpc_client.rb'

class BMF::AddressStore
  include Singleton

#  attr_reader :addresses

  def addresses
    Mutex.new.synchronize { @addresses.dup.freeze }
  end

  def identities
    addresses.select { |key, value| value['_source'] == 'addresses' && value['enabled'] }
  end
  
  def subscriptions
    addresses.select { |key, value| value['_source'] == 'subscriptions' && value['enabled'] }
  end
  

  def address_book
    addresses.select { |key, value| value['_source'] == 'addressbook' }
  end
  
  def initialize
    @addresses = {}
    # update
  end
  
  def log x
    puts x
  end

  def update_address_list method
    address_text = BMF::XmlrpcClient.instance.send(method)
    if BMF::XmlrpcClient.is_error? address_text
      puts "Couldn't call #{method}. #{address_text}"

      if method == :listAddressbook
        puts "This is expected because listAddressbook isn't in the official release yet."
        puts "Merge pull request #429 into PyBitmessage to add it."
      end
      
      return
    end
    
    source = method.to_s[4..-1].downcase
    source = 'addressbook' if source == 'addressbookentries'

    address_field = method == :listSubscriptions ? "subscriptions" : "addresses"
    address_infos = JSON.parse(address_text)[address_field]

    lock = Mutex.new

    lock.synchronize do
      new_addresses = 0

      address_infos.each do |address_info|
        address_info['_source'] = source

        if address_info['label'][-1] == "\n" # Probably base64
          address_info['label'] = Base64.decode64(address_info['label'])
        end
        
        address = address_info['address']
        if !@addresses.has_key? address
          new_addresses += 1
          @addresses[address] = address_info
        end
      end

      log "Added #{new_addresses} addresses..." if new_addresses > 0
    end
  end

  def update
    [:listAddresses, :listSubscriptions, :listAddressBookEntries].each { |m| update_address_list(m) }
  end
end
