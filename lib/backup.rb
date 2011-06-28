$LOAD_PATH.unshift(File.dirname(__FILE__))
gem 'mail'
require 'mail'
require 'backup/attribute'
require 'backup/configuration/base'
require 'backup/server'
require 'backup/storage'

module Backup
  class Main
    def self.start(options)
      @@options = options

      @configuration = Backup::Configuration::Base.new
      @configuration.instance_eval { eval File.read(options[:config]) }

      @configuration.storage.map do |storage_key, storage_value|
        @configuration.server.map do |name, config|
          next if options[:name].size > 0 && options[:name].select {|n| n == name }.size == 0

          server = Backup::Server.new
          server.name    = name
          server.config  = config
          server.storage = Backup::Storage.new(storage_key, storage_value)
          server.backup
        end
      end
    end

    def self.run(shell)
      puts shell.red
      @@options[:pretend] ? true : system(shell)
    end

    def self.email(options)
      puts "sending email to #{options[:to]}"
      unless @@options[:pretend]
        Mail.new(options).deliver!
      end
    end
  end
end
