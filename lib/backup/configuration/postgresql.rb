module Backup
  module Configuration
    class Postgresql
      extend Backup::Attribute
      generate_attributes :user, :password, :options, :databases, :host, :tables, :check, :skiptables
    end
  end
end
