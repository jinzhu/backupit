module Backup
  class Server
    attr_accessor :config, :name, :storage, :check

    def backup
      storage.backup(self) if storage
    end
  end
end
