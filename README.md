# RFC7597 (MAP-E) tool
This can calculate RFC7597 or draft-ietf-softwire-map-03 mapping between IPv4_A+P and IPv6.  This is going to be a Sinatra-based web app.  You can also use as a CLI tool.

NOTE: This is for MAP-E shared address type.  If you are looking for dedicated IP lookup, go to other tool.

## WebUI, API usage
Both API and WebUI are available.
Here is the result of `bundle exec rake routes`:
```
GET    /
GET    /webui
GET    /webui/map_rules
GET    /webui/lookup
GET    /webui/your_bmr?addr6=x
GET    /api/your_ipv6?addr4=x&port=y
GET    /api/your_ipv4?addr6=x
GET    /api/your_bmr?addr6=x
GET    /api/map_rules
POST   /api/provider/?
```

## Installation (Development)
- install `ruby 2.3.3` somehow (or make it up-to-date by resolving dependencies)
- `ruby -v`
- install `bundler`
  ```sh
  gem install bundler
  ```
- get this repository
- use bundler to install gems under this project
  ```sh
  bundle install --path=.bundle
  ```
- start a webserver bundled to `rack`
  ```sh
  $ bundle exec rackup
  [2018-03-20 10:27:31] INFO  WEBrick 1.3.1
  [2018-03-20 10:27:31] INFO  ruby 2.3.3 (2016-11-21)
  [2018-03-20 10:27:31] INFO  WEBrick::HTTPServer#start: pid=66791 port=9292
  ```
- done!  Visit http://localhost:9292

---

## Installation (running on remote Linux server)
- 前提:
  - OS: CentOS7.4
  - ruby 2.3.3 (rbenv でインストール)
    - gem, bundler

- install this project
  ```sh
    cd ~/
    git clone /path/to/this-repo.git
    cd ~/this-repo
    bundle install --path=.bundle --without development test
  ```
- install Apache
- install Passenger
  ```sh
    gem install passenger
    sudo chmod o+x "/home/webadmin"
    sudo ln -sv ~/rfc7597-util/public /var/www/html/rfc7597-util
    passenger-install-apache2-module
      -> Press `Enter` for all the questions
  ```
- configure on `/etc/httpd/conf.d/passenger.conf`. Refer to the following memo written during the process of `passenger-install-apache2-module`:
  ```apache
    LoadModule passenger_module /home/webadmin/.rbenv/versions/2.3.3/lib/ruby/gems/2.3.0/gems/passenger-5.2.1/buildout/apache2/mod_passenger.so
    <IfModule mod_passenger.c>
      PassengerRoot /home/webadmin/.rbenv/versions/2.3.3/lib/ruby/gems/2.3.0/gems/passenger-5.2.1
      PassengerDefaultRuby /home/webadmin/.rbenv/versions/2.3.3/bin/ruby
    </IfModule>

    RackBaseURI /rfc7597-util
    RackEnv production
    <Directory /rfc7597-util>
      Options ExecCGI FollowSymLinks
      Options -MultiViews
      AllowOverride All
      Order Allow,Deny
      Allow From All
    </Directory>

    # If needed, remove following HTTP header added by Passenger
    Header always unset "X-Powered-By"
    Header always unset "X-Rack-Cache"
    Header always unset "X-Content-Digest"
    Header always unset "X-Runtime"

    # Do these if needed
    PassengerMaxPoolSize 20
    PassengerMaxInstancesPerApp 4
    PassengerPoolIdleTime 3600
    PassengerHighPerformance on
    PassengerStatThrottleRate 10
  ```

- Do configtest and then restart apache
  ```sh
  sudo service httpd configtest
  sudo service httpd restart
  ```

- well, now everything should be ready!

---

## For Sinatra Application Admin
### Concept
- lightweight web app framework (sinatra)
- test-driven (TDD)
  - RSpec, Rack::Test
  - test scenario along with RFC7597 and OCN examples!
- rich test and visualization
  - guard (real-time/automated test)
  - simplecov (test coverage visualization)
- API-oriented
  - WebUI is just a wrapper

### Test
- rspec
  ```sh
  bundle exec rspec
  ```

- auto-run RSpec by Guard
  ```sh
  bundle exec guard
  ```

### CLI usage example
You can use map-e.rb library directly. In this case, please check rspec test (`spec/lib/map-e_spec.rb` etc.) the code itself to understand its specification.
  ```ruby
  require 'path/to/lib/map-e.rb'

  provider_params = {
    rule_net6: '2001:db8::/40',
    rule_net4: '192.0.2.0/24',
    ea_bit_len: 16,
    psid_offset: 6,
    br_addr6: '2001:db8:ffff::1',
    is_rfc: true
  }
  user_pref6 = '2001:db8:12:3400::/56'
  user_addr4 = '192.0.2.18'
  user_port = 1232
  user_psid = 52
  map_ce_addr6 = '2001:db8:12:3400:0:c000:212:34'

  map = MapE.new(provider_params)
  map.ipv6_to_ipv4(user_pref6) #=> { ipv4_address: user_addr4, psid: user_psid }
  map.ipv4_to_ipv6(ipv4_address: user_addr4, psid: user_psid) #=> map_ce_addr6
  map.port_to_psid(user_port) #=> user_psid
  map.ipv4_to_ipv6(ipv4_address: user_addr4, psid: user_psid) #=> map_ce_addr6
  ```

### Others
- library
  - minimum gem (IPAddress 0.8.3 がキー)
    - Make sure to specify where to install the gems: `bundle install --path=xxx`
  - ~~自前の monkey-patch : myipaddress~~ 結局本toolには使っていない (アドレス設計などでお遊びした)
- what to learn:
  - Ruby, sinatra, RSpec, Rack::Test, WebAPI, IPv6, MAP-E, phusion-passenger, linux, git
- directory structure (`tree -FL 3 map-e`)
  ```
  map-e/
  |-- Gemfile  # specifies gems to be installed
  |-- Gemfile.lock
  |-- README.md
  |-- Rakefile
  |-- config.ru
  |-- db/
  |   `-- rules.json  # MAP rules
  |-- lib/
  |   |-- map-e.rb  # MAP-E algorithm
  |   `-- myipaddress.rb  # not directly linked to this tool at this moment
  |-- main.rb  # sinatra app controller
  |-- public/  # js and css
  |   |-- css/
  |   |   `-- bootstrap.min.css
  |   `-- js/
  |       |-- jquery-3.3.1.min.js
  |       `-- lookup.js
  |-- spec/  # for tests
  |   |-- lib/
  |   |   |-- map-e_spec.rb
  |   |   `-- myipaddress_spec.rb
  |   |-- requests/
  |   |   |-- api_spec.rb
  |   |   `-- webui_spec.rb
  |   `-- spec_helper.rb
  `-- views/  # html templates
  ```
