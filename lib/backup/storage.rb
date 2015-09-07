require 'tempfile'

module Backup
  class Storage
    extend Backup::Attribute
    attr_accessor :name, :config, :changes, :subject_prefix

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
      backup_postgresql
      commit_changes

      if self.subject_prefix == "[ERROR]"
        send_mail(changes.join("\n"))
      end
    end

    def backup_rsync
      target_path = File.join(@backup_path, "rsync")

      FileUtils.mkdir_p target_path

      arguments = ['use_sudo','rsync_arg']

      @server_config.rsync.to_a.map do |path|
        remote_path = path.is_a?(Hash) ? (path.keys - arguments).first : path
        target_name = File.basename(path.is_a?(Hash) ? path["#{remote_path}"] : path)
        compress_level = 5
        compress_level = @server_config.rsync_compress_level if @server_config.rsync_compress_level and (not @server_config.rsync_compress_level.nil?)

        rsync_command = "rsync -ravkz"
        rsync_command += " --compress-level=#{compress_level}"
        rsync_command += " #{path['rsync_arg']}" if path.is_a?(Hash) and path.has_key?('rsync_arg')
        rsync_command += " --rsync-path=\"sudo rsync\"" if path.is_a?(Hash) and path.has_key?('use_sudo') and path['use_sudo']
        rsync_command += " #{@rsync_host}:#{remote_path} '#{File.join(target_path, target_name)}'"

        run_with_changes("#{rsync_command}")
      end
    end

    def backup_mysql
      target_path = File.join(@backup_path, "mysql")
      FileUtils.mkdir_p target_path

      @server_config.mysql.map do |key, mysql|
        mysql_config = ""
        mysql_config += " -u#{mysql.user}" if mysql.user
        mysql_config += " -p#{mysql.password}" if mysql.password
        mysql_config += " --databases #{mysql.databases.split("\n").join(' ')}" if mysql.databases
        mysql_config += " --tables #{mysql.tables.split("\n").join(' ')}" if mysql.tables
        mysql_config += " #{mysql.options}" if mysql.options
        mysql.skiptables && mysql.skiptables.split("\n").map do |table|
          table = table.include?('.') ? table : "#{mysql.databases.split("\n")[0]}.#{table}"
          mysql_config += " --ignore_table=#{table}"
        end

        backup_file = "#{target_path}/#{key}.sql"

        tmpfile = Tempfile.new('mysql.sql')
        run_with_changes("ssh #{@ssh_host} 'mysqldump #{mysql_config} > #{tmpfile.path}'",mysql_config) &&
        run_with_changes("scp #{@scp_host}:#{tmpfile.path} '#{backup_file}'") &&
        run_with_changes("ssh #{@ssh_host} 'rm #{tmpfile.path}'")

        check_backuped_mysql(target_path, key) if config.mysql_check and (mysql.check || mysql.check.nil?)

        encrypt_with_gpg(backup_file, config.gpg_id) if config.gpg_enable
      end
    end

    def backup_postgresql
      target_path = File.join(@backup_path, "postgresql")
      FileUtils.mkdir_p target_path

      @server_config.postgresql.map do |key, postgresql|
        postgresql_config = ""
        postgresql_config += " -d #{postgresql.databases.split("\n").join(' ')}" if postgresql.databases
        postgresql_config += " -U #{postgresql.user}" if postgresql.user
        postgresql_config += " -h #{postgresql.host}" if postgresql.host
        postgresql.tables && postgresql.tables.split("\n").map do |table|
          postgresql_config += " -t #{table}"
        end
        postgresql_config += " #{postgresql.options}" if postgresql.options
        postgresql.skiptables && postgresql.skiptables.split("\n").map do |table|
          table = table.include?('.') ? table : "#{postgresql.databases.split("\n")[0]}.#{table}"
          postgresql_config += " -T #{table}"
        end

        backup_file = "#{target_path}/#{key}.sql"

        postgresql_set_password = "PGPASSWORD=\"#{postgresql.password}\"" if postgresql.password

        tmpfile = Tempfile.new('postgresql.sql')
        run_with_changes("ssh #{@ssh_host} '#{postgresql_set_password} pg_dump -F c #{postgresql_config} > #{tmpfile.path}'", postgresql_set_password) &&
        run_with_changes("scp #{@scp_host}:#{tmpfile.path} '#{backup_file}'") &&
        run_with_changes("ssh #{@ssh_host} 'rm #{tmpfile.path}'")

        check_backuped_postgresql(target_path, key) if config.postgresql_check and (postgresql.check || postgresql.check.nil?)

        encrypt_with_gpg(backup_file, config.gpg_id) if config.gpg_enable
      end
    end

    def encrypt_with_gpg(backup_file, gpg_id)
      if !Backup::Main.run("gpg --fingerprint #{gpg_id}")
        Backup::Main.run("gpg --keyserver hkp://keys.gnupg.net --recv #{gpg_id}")
      end

      system("rm #{backup_file}.gpg") if File.exist?("#{backup_file}.gpg")
      run_with_changes("gpg --trust-model always -e -r #{gpg_id} -o #{backup_file}.gpg #{backup_file}")
      run_with_changes("rm #{backup_file}")
    end

    def check_backuped_mysql(target_path, key)
      dbconfig = config.mysql_config

      self.changes << "DBCheck running -- checking #{target_path}/#{key}.sql #{Time.now}"

      mysql_command = "mysql -h#{dbconfig[:host]} -u#{dbconfig[:user]} #{dbconfig[:password] ? "-p#{dbconfig[:password]}" : ""}"
      system("#{mysql_command} -e 'drop database #{dbconfig[:database]};'")
      system("#{mysql_command} -e 'create database #{dbconfig[:database]};'")

      status = run_with_changes("#{mysql_command} #{dbconfig[:database]} < #{target_path}/#{key}.sql") ? "SUCCESSFUL" : "FAILURE"
      self.changes << "DBCheck finished #{status} -- #{Time.now}"
    end

    def check_backuped_postgresql(target_path, key)
      dbconfig = config.postgresql_config

      self.changes << "DBCheck running -- checking #{target_path}/#{key}.sql #{Time.now}"

      system("dropdb -U #{dbconfig[:user]} #{dbconfig[:database]}")
      system("createdb -U #{dbconfig[:user]} #{dbconfig[:database]}")

      postgresql_command = ""
      postgresql_command += " PGPASSWORD=\"#{dbconfig[:password]}\"" if dbconfig[:password]
      postgresql_command += " pg_restore -e -O -n public -i -c #{dbconfig[:host] ? "-h #{dbconfig[:host]}" : ""}"

      status = run_with_changes("#{postgresql_command} -d #{dbconfig[:database]} -v #{target_path}/#{key}.sql") ? "SUCCESSFUL" : "FAILURE"
      self.changes << "DBCheck finished #{status} -- #{Time.now}"
    end

    def commit_changes
      Dir.chdir(@backup_path) do
        run_with_changes("git init") unless system("git status")
        run_with_changes("git add .")
        commited = `git status --untracked-files=no | wc -l`.strip!
        run_with_changes("git commit -am '#{Time.now.strftime("%Y-%m-%d %H:%M")}'") if commited.to_i > 2
      end
    end

    def run_with_changes(shell, remove_str="")
      result = Backup::Main.run(shell)
      shell.slice! remove_str
      self.changes << "== #{shell}"
      self.subject_prefix = "[ERROR]" unless result
      self.changes << result
      result
    end

    def send_mail(message)
      Dir.chdir(@backup_path) do
        smtp_config = config.smtp
        Mail.defaults { delivery_method :smtp, smtp_config } if smtp_config

        Backup::Main.email(:from => @server_config.email,
                           :to => @server_config.email,
                           :subject => "#{self.subject_prefix} #{@server.name} backed up at #{Time.now}",
                           :body => message,
                           :charset => 'utf-8', :content_type => 'text/plain; charset=utf-8'
                          ) if @server_config.email
      end
    end
  end
end
