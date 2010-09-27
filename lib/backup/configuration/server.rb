module Backup
  module Configuration
    class Server
      extend Backup::Attribute

      generate_attributes :command,:rsync

      def mysql(name=nil,&block)
        @mysqls ||= {}

        if block
          name ||= "mysql_#{@servers.keys.size}"
          @mysqls[name] = Backup::Configuration::Mysql.new
          @mysqls[name].instance_eval &block
        end

        @mysqls
      end
    end
  end
end
