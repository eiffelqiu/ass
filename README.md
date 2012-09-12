ass
=======
Apple Service Server written with Sinatra and Sequel(Sqlite3) with apple push notification and in app purchase support.

Feature:
=======

1.  rubygem, simple to install.
2.  provide pem file is the only requirement.
3.  no need to setup database, using sqlite3.
4.  provide default config file(ass.yml) with default value.

Requirement
=======

Sqlite3
-------

CentOS/Redhat:

    $ yum install sqlite3

Debian/Ubuntu:

    $ apt-get install sqlite3

FreeBSD:

    $ cd /usr/ports/databases/sqlite34
    $ sudo make install clean

Mac:

    $ brew install sqlite3 # Homebrew
    $ port install sqlite3 # Macport

Installation
=======

	$ sudo gem install ass
	
Usage
=======
1.  under the current directory, provide single pem file combined with certificate and key, HOWTO ([Check this link](http://www.raywenderlich.com/3443/apple-push-notification-services-tutorial-part-12))

2.  edit ass.yml. (when you run ass first time, it will generate this file) ([Check this link](https://raw.github.com/eiffelqiu/ass/master/ass.yml))

3.  provide a cron script under current directory, default named "cron" according to ass.yml

4.  start ass server, default port is 4567(sinatra's default port)

![ass usage](https://raw.github.com/eiffelqiu/ass/master/doc/capture1.png)

Contributing to ass
=======
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

Copyright
=======

Copyright (c) 2012 Eiffel Qiu. See LICENSE.txt for further details.

