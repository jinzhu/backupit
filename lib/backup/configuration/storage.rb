module Backup
  module Configuration
    class Storage
      extend Backup::Attribute
      generate_attributes :path
    end
  end
end
