ass
=======
####Apple Service Server written with Ruby/Sinatra and Sequel(Sqlite3)####

Feature:
=======

1.  'ass' is a rubygem, simple to install.
2.  only need to provide pem file.
3.  no need to setup database(using sqlite3).
4.  provide default config file(ass.yml) with default value.

Sqlite3 Installation
=======

CentOS/Redhat:

    $ yum install sqlite3

Debian/Ubuntu:

    $ apt-get install sqlite3

FreeBSD:

    $ cd /usr/ports/databases/sqlite34
    $ sudo make install clean

Mac:

    $ brew install sqlite # Homebrew
    $ port install sqlite # Macport

Installation
=======

	$ sudo gem install ass
	
Usage
=======

Prepare pem file:

under the current directory, provide single pem file combined with certificate and key(name pattern: appid_mode.pem), HOWTO ([Check this link](http://www.raywenderlich.com/3443/apple-push-notification-services-tutorial-part-12))

	cert.pem:
		openssl x509 -in aps_development.cer -inform der -out cert.pem

	key.pem:
		$ openssl pkcs12 -nocerts -in key.p12 -out key.pem
		$ Enter Import Password: 
		$ MAC verified OK
		$ Enter PEM pass phrase: 
		$ Verifying - Enter PEM pass phrase: 

	Development Profile:
		cat cert.pem key.pem > appid_development.pem

	Distribution Profile:
		cat cert.pem key.pem > appid_production.pem


* start ass server, default port is 4567 (sinatra's default port)

![ass usage](https://raw.github.com/eiffelqiu/ass/master/doc/capture1.png)

Configuration (ass.yml)
=======

when you run 'ass' first time, it will generate 'ass.yml' config file under current directory. ([Check this link](https://raw.github.com/eiffelqiu/ass/master/ass.yml))
	
	port: 4567  ## ASS server port, default is sinatra's port number: 4567
	mode: development ## 'development' or 'production' mode, you should provide pem file ({appid}_{mode}.pem) accordingly(such as, app1_development.pem, app1_production.pem). 
	cron: cron  ## cron job file name, ASS server will generate a demo 'cron' file for demostration only under current directory.
	timer: 0	# how often you run the cron job, unit: minute. when set with 0, means no cron job execute.
	apps:
	- app1 ## appid you want to supprt APNS, ASS Server can give push notification support for many iOS apps, just list the appid here.


FAQ:
=======

1.  How to register notification? (Client Side)
-------

In AppDelegate file, add methods below to register device token

	- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
	{
	    NSString * tokenAsString = [[[deviceToken description] 
	                                 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] 
	                                stringByReplacingOccurrencesOfString:@" " withString:@""];    
	    NSString *urlAsString = [NSString stringWithFormat:@"http://serverIP:4567/v1/apps/app1/%@", token];
	    NSURL *url = [NSURL URLWithString:urlAsString];
	    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url]; 
	    [urlRequest setTimeoutInterval:30.0f];
	    [urlRequest setHTTPMethod:@"GET"];
	    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
	    [NSURLConnection sendAsynchronousRequest:urlRequest queue:queue completionHandler:nil]; 
	}

	- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
	{
		NSLog(@"Failed to get token, error: %@", error);
	}
	
2. How to send push notification? (Server Side)
-------

run **curl** command to send push notification message, whatever shell.

	$ curl http://localhost:4567/v1/apps/app1/push/{message}/{pid}
	
Note:

param1 (message): push notification message you want to send, remember the message should be html escaped

param2 (pid ): unique string to mark the message, for example current timestamp or md5/sha1 digest



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

#####Copyright (c) 2012 Eiffel Qiu. See LICENSE.txt for further details.#####

