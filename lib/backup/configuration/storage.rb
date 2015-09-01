module Backup
  module Configuration
    class Storage
      extend Backup::Attribute
      generate_attributes :path, :smtp, :mysql_config, :mysql_check, :postgresql_config, :postgresql_check, :gpg_enable, :gpg_id
    end
  end
end
