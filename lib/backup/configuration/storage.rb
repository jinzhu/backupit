module Backup
  module Configuration
    class Storage
      extend Backup::Attribute
      generate_attributes :path, :smtp, :mysql_config
    end
  end
end
