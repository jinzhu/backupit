require 'tempfile'

module Backup
  class Storage
    extend Backup::Attribute
    attr_accessor :name, :config

    def initialize(name, config)
      self.name   = name
      self.config = config
    end

    def backup(server)
      @server        = server
      @server_config = @server.config
      @backup_path   = "#{config.path}/#{@server.name}"

      backup_rsync
      backup_mysql
      commit_changes
    end

    def backup_rsync
      target_path = File.join(@backup_path, "rsync")
      FileUtils.mkdir_p target_path

      @server_config.rsync.to_a.map do |path|
        Backup::Main.run "rsync -rav '#{@server_config.command}:#{path}' '#{target_path}'"
      end
    end

    def backup_mysql
      target_path = File.join(@backup_path, "rsync")
      FileUtils.mkdir_p target_path

      @server_config.mysql.map do |key, mysql|
        mysql_config = ""
        mysql_config += " -u#{mysql.user}" if mysql.user
        mysql_config += " -p#{mysql.user}" if mysql.password
        mysql_config += " --databases #{mysql.databases.to_a.join(' ')}" if mysql.databases
        mysql_config += " --tables #{mysql.tables.to_a.join(' ')}" if mysql.tables
        mysql_config += " #{mysql.options}" if mysql.options

        tmpfile = Tempfile.new('mysql.sql')
        Backup::Main.run("ssh '#{@server_config.command}' -c '$(which mysqldump) #{mysql_config} > #{tmpfile.path}'") &&
        Backup::Main.run("scp '#{@server_config.command}:#{tmpfile.path}' '#{target_path}/#{key}.sql'") &&
        Backup::Main.run("ssh '#{@server_config.command}' -c 'rm #{tmpfile.path}'")
      end
    end

    def commit_changes
      Dir.chdir(@backup_path) do
        Backup::Main.run("$(which git) add .")
        Backup::Main.run("$(which git) commit -am '#{Time.now.strftime("%Y-%m-%d %H:%M")}'")
      end
    end
  end
end
