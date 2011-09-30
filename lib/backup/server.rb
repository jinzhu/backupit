module Backup
  class Server
    attr_accessor :config, :name, :storage

    def backup
      storage.backup(self) if storage
    end
  end
end
