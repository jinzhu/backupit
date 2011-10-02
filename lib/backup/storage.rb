require 'tempfile'

module Backup
  class Storage
    extend Backup::Attribute
    attr_accessor :name, :config, :changes

    def initialize(name, config)
      self.name   = name
      self.config = config
    end

    def backup(server)
      @server        = server
      @server_config = @server.config
      @backup_path   = "#{config.path}/#{@server.name}"

      @ssh_host      = "-p#{@server_config.port || 22} #{@server_config.host}"
      @scp_host      = "-P#{@server_config.port || 22} #{@server_config.host}"
      @rsync_host    = "-e 'ssh -p#{@server_config.port || 22}' #{@server_config.host}"

      self.changes   = []

      backup_rsync
      backup_mysql
      commit_changes
      send_mail(changes.join("\n"))
    end

    def backup_rsync
      target_path = File.join(@backup_path, "rsync")

      FileUtils.mkdir_p target_path

      @server_config.rsync.to_a.map do |path|
        remote_path = path.is_a?(Hash) ? path.first[0] : path
        target_name = File.basename(path.is_a?(Hash) ? path.first[1] : path)
        self.changes << Backup::Main.run("rsync -ravk #{@rsync_host}:#{remote_path.sub(/\/?$/,'/')} '#{File.join(target_path, target_name)}'")
      end
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
        mysql_config += " #{mysql.options}" if mysql.options

        tmpfile = Tempfile.new('mysql.sql')
        (self.changes << Backup::Main.run("ssh #{@ssh_host} 'mysqldump #{mysql_config} > #{tmpfile.path}'")) &&
        (self.changes << Backup::Main.run("scp #{@scp_host}:#{tmpfile.path} '#{target_path}/#{key}.sql'")) &&
        (self.changes << Backup::Main.run("ssh #{@ssh_host} 'rm #{tmpfile.path}'"))

        #check the backup if config is setted
        if config.mysql_check and mysql.check 
            backup_check(target_path,key)
        end

      end
    end

    def send_mail(message)
      Dir.chdir(@backup_path) do
        smtp_config = config.smtp
        Mail.defaults { delivery_method :smtp, smtp_config } if smtp_config

        Backup::Main.email(:from => @server_config.email,
                           :to => @server_config.email,
                           :subject => "#{@server.name} backed up at #{Time.now}",
                           :body => message,
                           :charset => 'utf-8', :content_type => 'text/plain; charset=utf-8'
                          ) if @server_config.email
      end
    end

    def backup_check(target_path,key)
      puts "DBCheck running -- #{target_path}/#{key}.sql on checking"
      if config.mysql_config[:password] == ""
        status = system "mysql -h#{config.mysql_config[:host]} -u#{config.mysql_config[:user]} #{config.mysql_config[:databases]} < #{target_path}/#{key}.sql"
      else
        status = system "mysql -h#{config.mysql_config[:host]} -u#{config.mysql_config[:user]} -p#{config.mysql_config[:password]} #{config.mysql_config[:databases]} < #{target_path}/#{key}.sql"
      end

      if !status 
        message = "Error: #{target_path}/#{key}.sql can not be restored"
        send_mail(message)
      else
        puts "everything is ok :)"
      end
    end

    def commit_changes
      Dir.chdir(@backup_path) do
        (self.changes << Backup::Main.run("git init")) unless system("git status")
        self.changes << Backup::Main.run("git add .")
        self.changes << Backup::Main.run("git commit -am '#{Time.now.strftime("%Y-%m-%d %H:%M")}'")
      end
    end
  end
end
