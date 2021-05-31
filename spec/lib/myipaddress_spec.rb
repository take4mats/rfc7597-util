require 'spec_helper'
require 'rspec/its'
require 'myipaddress'

describe 'IPv4' do
  let(:ipv4_0) { IPAddress('192.168.0.0/24') }
  let(:ipv4_1) { IPAddress('192.168.1.0/24') }
  let(:ipv4_2) { IPAddress('192.168.0.0/23') }
  let(:ipv4_3) { IPAddress('192.168.2.0/23') }
  let(:ipv4_4) { IPAddress('192.168.0.0/22') }
  let(:ipv4_5) { IPAddress('192.168.4.0/24') }
  let(:arr4_0) { [ipv4_3, ipv4_0, ipv4_1, ipv4_5] }
  let(:arr4_1) { [ipv4_4, ipv4_5] }


  it 'should parse IPv4' do
    expect(ipv4_0.size).to eq 256
  end
  it 'should aggregate two IPv4 blocks' do
    expect(ipv4_0 + ipv4_1).to eq [ipv4_2]
    expect(ipv4_0 + ipv4_2).to eq [ipv4_2]
    expect((ipv4_3 + ipv4_0).sort).to eq [ipv4_0, ipv4_3]
  end
  it 'should summarize multiple IPv4 blocks' do
    expect(IPAddress::ExtIPv4.summarize(*arr4_0)).to eq arr4_1
  end
  it 'should return total size of multiple IPv4 prefixes' do
    expect(IPAddress::ExtIPv4.size_all(['192.168.0.0/24', '192.168.2.0/24'])).to eq 512
  end
end

describe 'IPv6' do
  let(:ipv6_0) { IPAddress('2001:db8:0::/48') }
  let(:ipv6_1) { IPAddress('2001:db8:1::/48') }
  let(:ipv6_2) { IPAddress('2001:db8:0::/47') }
  let(:ipv6_3) { IPAddress('2001:db8:2::/47') }
  let(:ipv6_4) { IPAddress('2001:db8:0::/46') }
  let(:ipv6_5) { IPAddress('2001:db8:4::/48') }
  let(:arr6_0) { [ipv6_3, ipv6_0, ipv6_1, ipv6_5] }
  let(:arr6_1) { [ipv6_4, ipv6_5] }

  it 'should parse IPv6' do
    expect(ipv6_0.size).to eq 2**(128 - 48)
  end
  it 'should aggregate two IPv6 blocks' do
    expect(ipv6_0 + ipv6_1).to eq [ipv6_2]
    expect(ipv6_0 + ipv6_2).to eq [ipv6_2]
    expect((ipv6_3 + ipv6_0).sort).to eq [ipv6_0, ipv6_3]
  end
  it 'should summarize multiple IPv6 blocks' do
    expect(IPAddress::ExtIPv6.summarize(*arr6_0)).to eq arr6_1
  end
  it 'should return total size of multiple IPv6 prefixes' do
    expect(IPAddress::ExtIPv6.size_all(['2001:db8::/64', '2001:db8:0:f::/64'])).to eq 2 * (2**64)
  end
end

describe 'IPAddress' do
  let(:ip_strings1) { ['192.168.0.0/24', '10.0.8.0/24', '192.168.1.0/24', '192.168.2.0/23', '10.0.9.0/24'] }
  let(:ip_strings2) { ['2001:db8:1::/48', '2001:db8::/48'] }
  let(:ip_strings3) { ['10.0.0.0/25', '10.0.0.0/24'] }
  let(:ip_strings4) { ['2001:db8:1::/48', '2001:db8::/32'] }

  it 'should summarize address blocks' do
    expect(IPAddress.summarize(ip_strings1)).to eq ['10.0.8.0/23', '192.168.0.0/22']
    expect(IPAddress.summarize(ip_strings2)).to eq ['2001:db8::/47']
    expect(IPAddress.summarize(ip_strings3)).to eq ['10.0.0.0/24']
    expect(IPAddress.summarize(ip_strings4)).to eq ['2001:db8::/32']
  end
  it 'should check exclusibility' do
    expect(IPAddress.exclusive?(ip_strings1)).to eq true
    expect(IPAddress.exclusive?(ip_strings2)).to eq true
    expect(IPAddress.exclusive?(ip_strings3)).to eq false
    expect(IPAddress.exclusive?(ip_strings4)).to eq false
  end
end
