# BackupIt

## Install
    $ gem install backupit

## Configuration File Example

    storage :file do
      path '/opt/backup/'
      mysql_check true
      mysql_config({:host=>"localhost",:user=>"root",:password=>"test",:databases=>"checkdb"})
    end

    server 'delonghi' do
      host "delonghi@10.0.1.1"
      port "222"

      rsync ['/home/www/app/shared/config',{'/home/staging/app/shared/config' => 'staging_config'}, '/home/www/app/shared/attachments']

      mysql 'delonghi' do
        user      'root'
        password  'mypassword'
        options   '-h 192.168.1.100'
        databases ['delonghi-staging', 'delonghi-production']
        tables    ['users','products'] # this would overwrite databases! `man mysqldump` for more help.
        skiptables "abc,dbc"  #tables ignore when dump,only skip first databases' tables
        #skiptables "abc,dbc","","feo,feog,gef"  #tables ignore when dump,second databases no skip
        check true
      end
    end

    server 'onitsukatiger' do
      host "otiger2@192.168.1.4"

      mysql 'ot_staging' do
        user      'root'
        password  'mytopsecret'
        databases 'ot_staging'
        check false
      end
    end

## Usage
    1, backup --pretend -f /opt/backup/backup.rb delonghi
       only backup server 'delonghi'  (pretend to run)
    2, backup -f /opt/backup/backup.rb
       backup all servers
    3, in storage , mysql_check(true | false) and mysql_config to check the backup can be restored
    4, in every mysql role, check mean to check the backup or not

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Jinzhu. See LICENSE for details.
