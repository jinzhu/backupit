module Backup
  module Configuration
    class Server
      extend Backup::Attribute
      generate_attributes :host, :rsync, :port, :email, :rsync_compress_level

      def mysql(name=nil,&block)
        @mysqls ||= {}

        if block
          name ||= "mysql_#{@servers.keys.size}"
          @mysqls[name] = Backup::Configuration::Mysql.new
          @mysqls[name].instance_eval &block
        end

        @mysqls
      end

      def postgresql(name=nil,&block)
        @postgresqls ||= {}

        if block
          name ||= "postgresql_#{@servers.keys.size}"
          @postgresqls[name] = Backup::Configuration::Postgresql.new
          @postgresqls[name].instance_eval &block
        end

        @postgresqls
      end
    end
  end
end
