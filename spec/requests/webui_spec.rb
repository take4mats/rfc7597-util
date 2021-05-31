require 'spec_helper'

describe MapeWebApp do
  let(:pref6) { '2400:4050:0:3d00::/56' }

  it 'GET /' do
    get '/'
    expect(last_response.status).to eq 303
  end

  it 'GET /webui' do
    get '/webui'
    expect(last_response).to be_ok
  end

  it 'GET /webui/map_rules' do
    get '/webui/map_rules'
    expect(last_response.body).to include('2400:4050::/32')
  end

  it 'GET /webui/lookup' do
    get '/webui/lookup'
    expect(last_response).to be_ok
  end

  it 'GET /webui/your_bmr' do
    get "/webui/your_bmr?addr6=#{pref6}"
    expect(last_response).to be_ok
  end
end
