
require 'rest-core'

require 'time' # for Time.parse

# http://wiki.flurry.com
RestCore::Flurry = RestCore::Builder.client(:apiKey, :apiAccessCode) do
  s = self.class # this is only for ruby 1.8!
  use s::Timeout       , 10

  use s::DefaultSite   , 'http://api.flurry.com/'
  use s::DefaultHeaders, {'Accept' => 'application/json'}
  use s::DefaultQuery  , {}

  use s::CommonLogger  , nil
  use s::Cache         , nil, 600 do
    use s::ErrorHandler, lambda{ |env|
      if env[s::ASYNC]
        if env[s::RESPONSE_BODY].kind_of?(::Exception)
          env
        else
          env.merge(s::RESPONSE_BODY =>
                      RuntimeError.new(env[s::RESPONSE_BODY]['message']))
        end
      else
        raise env[s::RESPONSE_BODY]['message']
      end}
    use s::ErrorDetectorHttp
    use s::JsonDecode  , true
  end
end

module RestCore::Flurry::Client
  # see: http://wiki.flurry.com/index.php?title=AppInfo
  # >> f.app_info
  # => {"@platform"=>"iPhone", "@name"=>"PicCollage",
  #     "@createdDate"=>"2011-07-24", "@category"=>"Photography",
  #     "@version"=>"1.0", "@generatedDate"=>"9/15/11 7:08 AM",
  #     "version"=>[{"@name"=>"2.1", ...
  def app_info query={}, opts={}
    get('appInfo/getApplication', query, opts)
  end

  # see: http://wiki.flurry.com/index.php?title=EventMetrics
  # >> f.event_names
  # => ["Products", "Save To Photo Library", ...]
  def event_names query={}, opts={}
    event_summary(query, opts).keys
  end

  # see: http://wiki.flurry.com/index.php?title=EventMetrics
  # >> f.event_summary({}, :days => 7)
  # => {"Products" => {"@usersLastWeek"  => "948" ,
  #                    "@usersLastMonth" => "2046",
  #                    "@usersLastDay"   => "4"   , ...}}
  def event_summary query={}, opts={}
    array2hash(get('eventMetrics/Summary',
                   *calculate_query_and_opts(query, opts))['event'],
               '@eventName')
  end

  # see: http://wiki.flurry.com/index.php?title=EventMetrics
  # >> f.event_metrics('Products', {}, :days => 7)
  # => [["2011-11-23", {"@uniqueUsers"   => "12"     ,
  #                     "@totalSessions" => "108392" ,
  #                     "@totalCount"    => "30"     ,
  #                     "@duration"      => "9754723"}],
  #     ["2011-11-22", {...}]]
  def event_metrics name, query={}, opts={}
    array2hash(get('eventMetrics/Event',
                   *calculate_query_and_opts(
                      {'eventName' => name}.merge(query), opts))['day'],
               '@date').sort{ |a, b| b <=> a }
  end

  # see: http://wiki.flurry.com/index.php?title=AppMetrics
  # >> f.metrics('ActiveUsers', {}, :weeks => 4)
  # => [["2011-09-19",  6516], ["2011-09-18", 43920], ["2011-09-17", 45412],
  #     ["2011-09-16", 40972], ["2011-09-15", 37587], ["2011-09-14", 34918],
  #     ...]
  def metrics path, query={}, opts={}
    get("appMetrics/#{path}", *calculate_query_and_opts(query, opts)
      )['day'].map{ |i| [i['@date'], i['@value'].to_i] }.reverse
  end

  # >> f.weekly(f.metrics('ActiveUsers', {}, :weeks => 4))
  # => [244548, 270227, 248513, 257149]
  def weekly array
    start = Time.parse(array.first.first, nil).to_i
    array.group_by{ |(date, value)|
      current = Time.parse(date, nil).to_i
      - (current - start) / (86400*7)
    # calling .last to discard week numbers created by group_by
    }.sort.map(&:last).map{ |week|
      week.map{ |(_, num)| num }.inject(&:+) }
  end

  # >> f.sum(f.weekly(f.metrics('ActiveUsers', {}, :weeks => 4)))
  # => [1020437, 775889, 505662, 257149]
  def sum array
    reverse = array.reverse
    (0...reverse.size).map{ |index|
      reverse[1, index].inject(reverse.first, &:+)
    }.reverse
  end

  def default_query
    {'apiKey'        => apiKey       ,
     'apiAccessCode' => apiAccessCode}
  end

  private
  def calculate_query_and_opts query, opts
    days = opts[:days] || (opts[:weeks]  && opts[:weeks] * 7)   ||
                          (opts[:months] && opts[:months] * 30) || 7

    startDate = query[:startDate] || (Time.now + 86400 - 86400*days).
      strftime('%Y-%m-%d')

    endDate   = query[:endDate]   || Time.now.
      strftime('%Y-%m-%d')

    [query.merge(:startDate => startDate,
                 :endDate   => endDate),
     opts.reject{ |k, _| [:days, :weeks, :months].include?(k) }]
  end

  def array2hash array, key
    array.inject({}){ |r, i|
      r[i[key]] = i.reject{ |k, _| k == key }
      r }
  end
end

RestCore::Flurry.send(:include, RestCore::Flurry::Client)
require 'rest-core/client/flurry/rails_util' if
  Object.const_defined?(:Rails)
