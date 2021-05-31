require 'spec_helper'
require 'rspec/its'
require 'map-e'

describe 'MAP-E RFC7597' do
  let(:provider_params) do
    {
      rule_net6: '2001:db8::/40',
      rule_net4: '192.0.2.0/24',
      ea_bit_len: 16,
      psid_offset: 6,
      br_addr6: '2001:db8:ffff::1',
      is_rfc: true
    }
  end
  let(:map) { MapE.new(provider_params) }
  let(:user_pref6) { '2001:db8:12:3400::/56' }
  let(:user_addr6) { '2001:db8:12:3400::' }
  let(:user_addr4) { '192.0.2.18' }
  let(:user_port) { 1232 }
  let(:user_psid) { 52 }
  let(:map_ce_addr6) { '2001:db8:12:3400:0:c000:212:34' }

  describe 'Example 1 - Basic Mapping Rule:' do
    it 'should translate user_pref6 -> user_addr4 + user_psid' do
      expect(map.ipv6_to_ipv4(user_pref6)).to eq(ipv4_address: user_addr4, psid: user_psid)
    end
    it 'should provide user_ce_addr6' do
      expect(map.ipv4_to_ipv6(ipv4_address: user_addr4, psid: user_psid)).to eq(ipv6_address: user_addr6, map_ce_ipv6_address: map_ce_addr6)
    end
    it 'should provide mapping_info from user_pref6' do
      expect(map.mapping_info(IPAddress(user_pref6))).to eq({
        pref6: user_pref6,
        addr4: user_addr4,
        psid: user_psid,
        port_range: map.psid_to_port_range(user_psid),
        ports: map.psid_to_ports(user_psid)
      })
    end
  end
  describe 'Example 2 - BR:' do
    it 'should translate user_port -> user_psid' do
      expect(map.port_to_psid(user_port)).to eq(user_psid)
    end
    it 'should translate user_addr4 + user_psid -> map_ce_ipv6_address' do
      expect(map.ipv4_to_ipv6(ipv4_address: user_addr4, psid: user_psid)).to eq(ipv6_address: user_addr6, map_ce_ipv6_address: map_ce_addr6)
    end
  end
end

describe 'MAP-E Draft-v3: ' do
  let(:provider_params) do
    {
      rule_net6: '2001:db8::/30',
      rule_net4: '10.0.0.0/12',
      ea_bit_len: 26,
      psid_offset: 6,
      br_addr6: 'feed:feed:feed::1',
      is_rfc: false
    }
  end
  let(:map) { MapE.new(provider_params) }

  describe 'provider_param sized for east/west part of AS4713' do
    it 'should provide correct bits and bit-length' do
      expect(map.ea_bit_len).to eq 26
      expect(map.subnet_id_len).to eq 8
      expect(map.if_id_pad_head_len).to eq 8
      expect(map.if_id_pad_tail_len).to eq 8
      expect(map.psid_offset).to eq 6
      expect(map.psid_len).to eq 6
      expect(map.free_port_bit_len).to eq 4
      expect(map.suffix4_len).to eq 20
      expect(map.density4).to eq 64
      expect(map.total_user).to eq 2**26 # ~= 67,000,000 users in east (or west) Japan
    end
    it 'should translate PSID -> ports' do
      expect(map.psid_to_ports(0).size).to eq map.ports_per_user
    end
    it 'should translate PSID -> port range' do
      expect(map.psid_to_port_range(0).size).to eq map.ports_per_user/2**map.free_port_bit_len
      expect(map.psid_to_port_range(0)).to eq [
        1024..1039, 2048..2063, 3072..3087, 4096..4111, 5120..5135,
        6144..6159, 7168..7183, 8192..8207, 9216..9231, 10240..10255,
        11264..11279, 12288..12303, 13312..13327, 14336..14351, 15360..15375,
        16384..16399, 17408..17423, 18432..18447, 19456..19471, 20480..20495,
        21504..21519, 22528..22543, 23552..23567, 24576..24591, 25600..25615,
        26624..26639, 27648..27663, 28672..28687, 29696..29711, 30720..30735,
        31744..31759, 32768..32783, 33792..33807, 34816..34831, 35840..35855,
        36864..36879, 37888..37903, 38912..38927, 39936..39951, 40960..40975,
        41984..41999, 43008..43023, 44032..44047, 45056..45071, 46080..46095,
        47104..47119, 48128..48143, 49152..49167, 50176..50191, 51200..51215,
        52224..52239, 53248..53263, 54272..54287, 55296..55311, 56320..56335,
        57344..57359, 58368..58383, 59392..59407, 60416..60431, 61440..61455,
        62464..62479, 63488..63503, 64512..64527
      ]
    end
    it 'should judge port reservation' do
      expect(map.port_reserved?(80)).to eq(true)
      expect(map.port_reserved?(8888)).to eq(false)
    end
    it 'should translate Port -> PSID' do
      expect(map.port_to_psid(1024)).to eq(0)
      expect(map.port_to_psid(21845)).to eq(21)
    end
  end
  describe 'assigned resources to a CPE' do
    it 'should translate: IPv4+PSID -> IPv6' do
      expect(map.ipv4_to_ipv6(ipv4_address: '10.0.0.0', psid: 0)).to eq(ipv6_address: '2001:db8::', map_ce_ipv6_address: '2001:db8:0:0:a::')
      expect(map.ipv4_to_ipv6(ipv4_address: '10.1.85.85', psid: 21)).to eq(ipv6_address: '2001:db8:5555:5500::', map_ce_ipv6_address: '2001:db8:5555:5500:a:155:5500:1500')
      expect{ map.ipv4_to_ipv6(ipv4_address: '192.168.1.1', psid: 21) }.to raise_error(ArgumentError)
    end
    it 'should translate: IPv6 -> IPv4+PSID' do
      expect(map.ipv6_to_ipv4('2001:db8:0:0:a::')).to eq(ipv4_address: '10.0.0.0', psid: 0)
      expect(map.ipv6_to_ipv4('2001:db8:5555:5500:a:155:5500:1500')).to eq(ipv4_address: '10.1.85.85', psid: 21)
      expect{ map.ipv6_to_ipv4('::1') }.to raise_error(ArgumentError)
    end
  end
end
