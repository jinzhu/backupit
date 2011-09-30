module Backup
  module Configuration
    class Mysql
      extend Backup::Attribute
      generate_attributes :user, :password, :options, :databases, :tables, :check
    end
  end
end
