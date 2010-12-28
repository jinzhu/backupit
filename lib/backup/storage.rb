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
      @backup_user   = "#{config.user || 'root'}"

      @ssh_host      = "#{@server_config.host}"
      @scp_host      = "#{@server_config.host}"
      @rsync_host    = "#{@server_config.host}"

      # TODO: Add individual options here
      @ssh_opts      = "-p#{@server_config.port || 22}"
      @scp_opts      = "-P#{@server_config.port || 22}"
      @rsync_opts    = "-e 'ssh -p#{@server_config.port || 22}'"

      backup_rsync unless @server_config.rsync.nil?
      backup_mysql unless @server_config.mysql.nil?
    end

    def backup_rsync
      target_path = File.join(@backup_path, "rsync")

      FileUtils.mkdir_p target_path

      @server_config.rsync.to_a.map do |path|
        remote_path = path.is_a?(Hash) ? path.first[0] : path
        target_name = File.basename(path.is_a?(Hash) ? path.first[1] : path)
        Backup::Main.run "rsync -ravk #{@rsync_opts} #{@backup_user}@#{@rsync_host}:#{remote_path.sub(/\/?$/,'/')} '#{File.join(target_path, target_name)}'"
      end
      commit_changes(target_path)
    end

    def backup_mysql
      target_path = File.join(@backup_path, "mysql")
      FileUtils.mkdir_p target_path

      @server_config.mysql.map do |key, mysql|
        mysql_config = ""
        mysql_config += " -u#{mysql.user}" if mysql.user
        mysql_config += " -p#{mysql.password}" if mysql.password
        mysql_config += " --databases #{mysql.databases.to_a.join(' ')}" if mysql.databases
        mysql_config += " --tables #{mysql.tables.to_a.join(' ')}" if mysql.tables
        mysql_config += " -A" if mysql.databases.nil? and mysql.tables.nil?
        mysql_config += " #{mysql.options}" if mysql.options

        tmpfile = Tempfile.new('mysql.sql')
        Backup::Main.run("ssh #{@ssh_opts} #{@backup_user}@#{@ssh_host} 'mysqldump #{mysql_config} > #{tmpfile.path}'") &&
          Backup::Main.run("scp #{@scp_opts} #{@backup_user}@#{@scp_host}:#{tmpfile.path} '#{target_path}/#{key}.sql'") &&
          Backup::Main.run("ssh #{@ssh_opts} #{@backup_user}@#{@ssh_host} 'rm #{tmpfile.path}'")
      end
      commit_changes(target_path)
    end

    def commit_changes(path)
      Dir.chdir(path) do
        Backup::Main.run("git init") unless system("git status")
        Backup::Main.run("git add .")
        Backup::Main.run("git commit -am '#{Time.now.strftime("%Y-%m-%d %H:%M")}'")
      end
    end
  end
end
