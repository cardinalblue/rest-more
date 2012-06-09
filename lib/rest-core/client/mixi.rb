
# http://developer.mixi.co.jp/connect/mixi_graph_api/
RestCore::Mixi = RestCore::Builder.client(
  :data, :consumer_key, :consumer_secret, :redirect_uri) do
  s = RestCore
  use s::Timeout       , 10

  use s::DefaultSite   , 'http://api.mixi-platform.com/'
  use s::DefaultHeaders, {'Accept' => 'application/json'}

  use s::Oauth2Header  , 'OAuth', nil

  use s::CommonLogger  , nil
  use s::Cache         , nil, 600 do
    use s::ErrorHandler  , lambda{ |env| p env }
    use s::ErrorDetectorHttp
    use s::JsonDecode    , true
  end
end

module RestCore::Mixi::Client
  include RestCore

  def me query={}, opts={}
    get('2/people/@me/@self', query, opts)
  end

  def access_token
    data['access_token'] if data.kind_of?(Hash)
  end

  def access_token= token
    data['access_token'] = token if data.kind_of?(Hash)
  end

  def authorize_url queries={}
    url('https://mixi.jp/connect_authorize.pl',
        {:client_id     => consumer_key,
         :response_type => 'code',
         :scope         => 'r_profile'}.merge(queries))
  end

  def authorize! payload={}, opts={}
    pl = {:client_id     => consumer_key   ,
          :client_secret => consumer_secret,
          :redirect_uri  => redirect_uri   ,
          :grant_type    => 'authorization_code'}.merge(payload)

    self.data = post('https://secure.mixi-platform.com/2/token', pl, {}, opts)
  end

  private
  def default_data
    {}
  end
end

RestCore::Mixi.send(:include, RestCore::Mixi::Client)
require 'rest-core/client/mixi/rails_util' if
  Object.const_defined?(:Rails)
