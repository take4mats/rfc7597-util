require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'logger'
require 'json'
require_relative './lib/map-e'
# require './lib/myipaddress'
require 'ipaddress'

# sinatra main class
class MapeWebApp < Sinatra::Base
  register Sinatra::Reloader

  RULE_FILE = './db/rules.json'.freeze

  #--- helper methods ---#

  # read map rules from a file
  def read_map_rules(json_file)
    json_data = JSON.parse(File.read(json_file), symbolize_names: true)
    return json_data[:basic_map_rules]
  end

  # validate params addr6
  def validate_addr6(addr6)
    addr6_obj = IPAddress(addr6)
    pref6_len = addr6_obj.prefix
    raise ArgumentError.new("Input #{addr6} isn't IPv6") unless addr6_obj.ipv6?
    raise ArgumentError.new("Input prefix length must be /56 or longer, but got #{pref6_len}") if pref6_len < 56
    return addr6_obj
  rescue ArgumentError => error_message
    error = {
      error: {
        message: error_message
      }
    }
    halt 400, error.to_json
  end

  # syntax check
  # a4_plus_p = '192.168.0.1:2020'
  def validate_ipv4(addr4, port)
    addr4_obj = IPAddress(addr4)
    raise ArgumentError.new("Input address #{addr4} doesn't look like IPv4") unless addr4_obj.ipv4?
    raise ArgumentError.new("Input number #{port} is not within valid TCP/UDP port range") unless [*0..65535].include?(port)
    return addr4_obj, port
  rescue ArgumentError => error_message
    error = {
      error: {
        message: error_message
      }
    }
    halt 400, error.to_json
  end

  # returns IPAddress object for net4 or net6
  def rule_to_net(ipversion, rule)
    case ipversion
    when 6
      pref = :ipv6_prefix
      length = :ipv6_prefix_length
    when 4
      pref = :ipv4_prefix
      length = :ipv4_prefix_length
    end

    return IPAddress("#{rule[pref.to_sym]}/#{rule[length.to_sym]}")
  end

  # lookup BMR that matches the given ipadderss
  def find_rule(ipversion, ipaddress)
    map_rules = read_map_rules(RULE_FILE)

    rules = map_rules.find_all do |r|
      rule_to_net(ipversion, r).include?(ipaddress)
    end

    if rules.length != 1
      error = {
        error: {
          number_of_rules_matched: rules.length,
          rules: rules,
          message: 'Enter IP address or prefix that matches only one rule'
        }
      }
      halt 400, JSON.pretty_generate(error)
    end
    return rules[0]
  end

  # hoge
  def get_map_by_rule(rule)
    provider_params = {
      rule_net6: rule_to_net(6, rule).to_string,
      rule_net4: rule_to_net(4, rule).to_string,
      ea_bit_len: rule[:ea_bit_length].to_i,
      psid_offset: rule[:psid_offset_rule].to_i,
      br_addr6: rule[:br_ipv6_address],
      is_rfc: false
    }
    return MapE.new(provider_params)
  end

  def your_bmr(addr6)
    pref6_obj = validate_addr6(addr6).network
    rule = find_rule(6, pref6_obj)
    map = get_map_by_rule(rule)
    mapping_info = map.mapping_info(pref6_obj)

    return rule, map, mapping_info
  end

  #--- web UI ---#

  # root
  get '/' do
    content_type(:html, charset: 'utf-8')
    redirect to('/webui'), 303
  end

  get '/webui' do
    content_type(:html, charset: 'utf-8')
    erb :index
  end

  # show map rules
  get '/webui/map_rules' do
    @map_rules = read_map_rules(RULE_FILE)
    content_type(:html, charset: 'utf-8')
    erb :map_rules
  end

  # goes to search utility page
  get '/webui/lookup' do
    content_type(:html, charset: 'utf-8')
    erb :lookup
  end

  # returns Basic Mapping Rule to the user with the IPv6
  get '/webui/your_bmr' do
    @rule, @map, @mapping_info = your_bmr(params[:addr6]) unless params[:addr6].nil? || params[:addr6] == ''

    content_type(:html, charset: 'utf-8')
    erb :your_bmr
  end

  #--- API ---#

  # look up IPv6 address by IPv4 addr+port
  get '/api/your_ipv6' do
    addr4_obj, port = validate_ipv4(params[:addr4], params[:port].to_i)
    rule = find_rule(4, addr4_obj)
    map = get_map_by_rule(rule)

    if map.port_reserved?(port)
      error = {
        error: {
          message: "Input port #{port} is reserved, not assinged to users!"
        }
      }
      content_type(:json, charset: 'utf-8')
      halt 400, JSON.pretty_generate(error)
    end

    ipv4 = {
      ipv4_address: addr4_obj.to_string,
      psid: map.port_to_psid(port)
    }

    response = map.ipv4_to_ipv6(ipv4)

    content_type(:json, charset: 'utf-8')
    return JSON.pretty_generate(response)
  end

  # look up IPv4 addr+port by IPv6 address
  get '/api/your_ipv4' do
    addr6_obj = validate_addr6(params[:addr6])
    rule = find_rule(6, addr6_obj)
    map = get_map_by_rule(rule)

    response = map.ipv6_to_ipv4(addr6_obj.to_string)
    response[:ports] = map.psid_to_ports(response[:psid])

    content_type(:json, charset: 'utf-8')
    return JSON.pretty_generate(response)
  end

  # return basic map rule to certain CPE
  get '/api/your_bmr' do
    rule, *, mapping_info = your_bmr(params[:addr6])

    response = {
      basic_map_rule: rule,
      mapping_info: mapping_info
    }

    content_type(:json, charset: 'utf-8')
    return JSON.pretty_generate(response)
  end

  # return all the map rules
  get '/api/map_rules' do
    response = read_map_rules(RULE_FILE)
    content_type(:json, charset: 'utf-8')
    return JSON.pretty_generate(response)
  end

  # calculates MAP
  post '/api/provider' do
    provider_params = JSON.parse(request.body.read, symbolize_names: true)
    map = MapE.new(provider_params)
    response = {
      input: provider_params,
      output: {
        pref6_len: map.pref6_len,
        pref4_len: map.pref4_len,
        suffix6_len: map.suffix6_len,
        suffix4_len: map.suffix4_len,
        user_pref6_len: map.user_pref6_len,
        subnet_id_len: map.subnet_id_len,
        if_id_pad_head_len: map.if_id_pad_head_len,
        if_id_pad_tail_len: map.if_id_pad_tail_len,
        psid_len: map.psid_len,
        free_port_bit_len: map.free_port_bit_len,
        rsv_port: map.rsv_port,
        density4: map.density4,
        ports_per_user: map.ports_per_user,
        total_user: map.total_user
      }
    }

    content_type(:json, charset: 'utf-8')
    return JSON.pretty_generate(response)
  end
end
