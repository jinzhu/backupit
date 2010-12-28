module Backup
  module Configuration
    class Storage
      extend Backup::Attribute
      generate_attributes :path, :user
    end
  end
end
