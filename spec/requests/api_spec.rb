require 'spec_helper'

describe MapeWebApp do
  let(:pref6) { '2001:db8:0:3d00::/56' }
  let(:addr6) { '2001:db8:0:3d00::' }
  let(:map_ce_addr6) { '2001:db8:0:3d00:a:f000:0:3d00' }
  let(:addr4) { '10.240.0.0' }
  let(:port) { 2000 }
  let(:psid) { 61 }

  it 'POST /api/provider' do
    params = {
      rule_net6: '2001:db8::/30',
      rule_net4: '10.0.0.0/12',
      ea_bit_len: 26,
      psid_offset: 6,
      br_addr6: 'feed:feed:feed:feed:feed:feed:feed:feed',
      is_rfc: false
    }
    env = {
      CONTENT_TYPE: 'application/json'
    }
    post('/api/provider', JSON.generate(params), env)
    expect(last_response).to be_ok
  end

  it 'GET /api/your_bmr' do
    get "/api/your_bmr?addr6=#{pref6}"
    expect(last_response).to be_ok
  end

  it 'GET /api/your_ipv6' do
    get "/api/your_ipv6?addr4=#{addr4}&port=#{port}"
    expect(last_response).to be_ok

    json = JSON.parse(last_response.body)
    expect(json['ipv6_address']).to eq addr6
    expect(json['map_ce_ipv6_address']).to eq map_ce_addr6
  end

  it 'GET /api/your_ipv4' do
    get "/api/your_ipv4?addr6=#{map_ce_addr6}"
    expect(last_response).to be_ok

    json = JSON.parse(last_response.body)
    expect(json['ipv4_address']).to eq addr4
    expect(json['psid']).to eq psid
    expect(json['ports']).to include(port)
  end
end
