# backupit

## Configuration File Example

    storage :file do
      path '/your_backup_path'
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
      end
    end

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
