module Backup
  module Configuration
    class Check
      extend Backup::Attribute
      generate_attributes :config
    end
  end
end
