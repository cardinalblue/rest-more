
require 'rest-more/test'

require 'rest-core/util/config'

describe RC::Config do

  before do
    @klass = RC::Facebook.dup
  end

  after do
    RR.verify
  end

  def check
    @klass.default_app_id     .should.eq 41829
    @klass.default_secret     .should.eq 'r41829'.reverse
    @klass.default_json_decode.should.eq false
    @klass.default_lang       .should.eq 'zh-tw'
  end

  should 'honor rails config' do
    app = Object.new
    mock(app).env { 'test' }
    mock(app).root{ File.dirname(__FILE__) }
    RC::Config.load_for_rails(@klass, 'facebook', app)
    check
  end

  should 'honor config' do
    RC::Config.load(
      @klass,
      "#{File.dirname(__FILE__)}/config/rest-core.yaml",
      'test',
      'facebook')
    check
  end
end
