require 'rest-core'

# http://instagram.com/developer/
module RestCore
  Instagram = Builder.client do
    use DefaultSite, 'https://api.instagram.com/'
    use JsonResponse, true
  end
end

module RestCore::Instagram::Client
  include RestCore

  def user_id username, options={}
    result = user_search(username, options)

    user_found = 
      result['meta']['code'] == 200 &&
      result['data'].length == 1

    result['data'].first['id'] if user_found
  end

  def user_search username, options={}
    get('v1/users/search', {q: username, client_id: options[:client_id]}, options)
  end
end

class RestCore::Instagram
  include RestCore::Instagram::Client
end
