# MAP-E_tool (as of 2018/03/23)
This can calculate RFC7597 or draft-ietf-softwire-map-03 mapping between IPv4_A+P and IPv6.  This is going to be a Sinatra-based web app.  You can also use as a CLI tool.

NOTE: This is for MAP-E shared address type.  If you are looking for dedicated IP lookup, go to other tool.

## WebUI, API usage
Both API and WebUI are available.
Here is the result of `bundle exec rake routes`:
```
GET    /
GET    /webui
GET    /webui/map_rules               # アドレスシェアのルール 一覧
GET    /webui/lookup                  # 4-6変換するwebui
GET    /webui/your_bmr?addr6=x        # アドレスシェアのルール にマッチする 6 を叩けば詳細情報が返ってくる
GET    /api/your_ipv6?addr4=x&port=y  # アドレスシェアのルール にマッチする 4のaddr+port を叩けば ipv6 が返ってくる
GET    /api/your_ipv4?addr6=x         # アドレスシェアのルール にマッチする 6 pref を叩けば IPv4 と port rangeが返ってくる
GET    /api/your_bmr?addr6=x          # アドレスシェアのルール にマッチする 6 を叩けば詳細情報が返ってくる
GET    /api/map_rules                 # アドレスシェアのルール 一覧
POST   /api/provider/?                # 一定の中身を post すると MAP-E の設計情報が返ってくる。 expert向け
```

## Installation (Development)
- install `ruby 2.3.3` somehow (2.x なら多分動くけど, 変えるなら Gemfile 編集してください, 本当は最新にしたい)
  `ruby -v` コマンドでバージョン確認
- install `bundler`
  ```sh
  gem install bundler
  ```
- get `map-e` (コレ読んでるならもう持ってますね)
  ```sh
  git clone path/to/repository/map-e.git  # or exec tar command in case of .tar.gz package
  cd map-e/
  ```
- use bundler to install gems under this project
  ```sh
  bundle install --path=.bundle
  ```
- start a webserver bundled to `rack`
  ```sh
  $ bundle exec rackup
  # 以下のログが出ていれば、port 9292 で上がっている
  [2018-03-20 10:27:31] INFO  WEBrick 1.3.1
  [2018-03-20 10:27:31] INFO  ruby 2.3.3 (2016-11-21)
  [2018-03-20 10:27:31] INFO  WEBrick::HTTPServer#start: pid=66791 port=9292
  ```
- done!  http://localhost:9292 にアクセス。

---

## Installation (Production)
- 前提:
  - OS: CentOS7.4
    - 任意のテンプレートで構築
  - ruby 2.3.3 (rbenv でインストール)
    - gem, bundler

- map-e tool のインストール
  ```sh
    cd ~/
    git clone /usr/local/repository/map-e.git
    cd ~/map-e/
    bundle install --path=.bundle --without development test
  ```
- apache インストール: 省略
- passenger インストール
  ```sh
    gem install passenger
    sudo chmod o+x "/home/webadmin"
    sudo ln -sv ~/map-e/public /var/www/html/map-e
    passenger-install-apache2-module
      -> 実行後、設問はすべてenterを入力, 一部メモ
  ```
- `/etc/httpd/conf.d/passenger.conf` を作成する。細かいところは環境に応じて修正してほしいが、 passenger-install-apache2-module の途中でしたメモを活用して作っていく:
  ```apache
    LoadModule passenger_module /home/webadmin/.rbenv/versions/2.3.3/lib/ruby/gems/2.3.0/gems/passenger-5.2.1/buildout/apache2/mod_passenger.so
    <IfModule mod_passenger.c>
      PassengerRoot /home/webadmin/.rbenv/versions/2.3.3/lib/ruby/gems/2.3.0/gems/passenger-5.2.1
      PassengerDefaultRuby /home/webadmin/.rbenv/versions/2.3.3/bin/ruby
    </IfModule>

    RackBaseURI /map-e
    RackEnv production
    <Directory /map-e>
      Options ExecCGI FollowSymLinks
      Options -MultiViews
      AllowOverride All
      Order Allow,Deny
      Allow From All
    </Directory>

    # 必要なら Passenger が追加するHTTPヘッダを削除するための設定。
    Header always unset "X-Powered-By"
    Header always unset "X-Rack-Cache"
    Header always unset "X-Content-Digest"
    Header always unset "X-Runtime"

    # 必要ならこの辺も
    PassengerMaxPoolSize 20
    PassengerMaxInstancesPerApp 4
    PassengerPoolIdleTime 3600
    PassengerHighPerformance on
    PassengerStatThrottleRate 10
  ```

- configtest してから apache 再起動して利用開始
  ```sh
  sudo service httpd configtest
  sudo service httpd restart
  ```

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
map-e.rb ライブラリを直接叩く/本ツール以外に使いまわすなら、の参考. 詳細の使い方は rspec test (`spec/lib/map-e_spec.rb` etc.) を見るか library 直接見てね
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
  - 必要最小限の gem (IPAddress 0.8.3 がキー)
    - ユーザ環境に install しない。 必ず `bundle install --path=xxx` を指定
  - ~~自前の monkey-patch : myipaddress~~ 結局本toolには使っていない (アドレス設計時に利用した)
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
