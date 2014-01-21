module GoogleApiHelper

  # Shortcut for accessing the Google API client
  def google_api_client
    @client ||= Google::APIClient.new

    @client.authorization.access_token = cookies[:access_token] || auth_info["credentials"]["token"]

    # if @client.authorization.expired?
    #   @client.authorization.fetch_access_token!(cookies[:refresh_token])
    # end

    return @client
  end

  def google_api_events(parameters)
    client = Google::APIClient.new
    if cookies[:access_token]
      puts "YEAH I GOT AN ACCESS TOKEN"
    else
      puts "NO ACCESS TOKEN SHIIT"
    end
    client.authorization.access_token = cookies[:access_token] || auth_info["credentials"]["token"]
    service = client.discovered_api('calendar','v3')
    result = client.execute(
      api_method: service.calendar_list.list,
      parameters: parameters,
      headers: { 'Content-Type' => 'application/json' }
    )
  end
  # Wrapper for the Google API client discover and execute method
  def google_api_request(service, version, resources, method, parameters, body=nil, content_type='application/json')
    api_service = google_api_client.discovered_api(service, version)

    api_resource = api_service
    if resources.instance_of? Array
      resources.each { |resource| api_resource = service.send(resource) }
    else
      api_resource = api_resource.send(resources)
    end

    # if resources == 'events'
    #   parameters[:singleEvents] = true
    # end

    puts "HERE IS THE METHIOD"
    puts method
    puts "here i am and about to fail"
    puts google_api_client
    puts "that was the client"
    puts parameters
    puts "those were the PARAMETERS"
    puts api_resource.send(method)
    puts "that was api resource thing"
    puts content_type
    puts "that was content type"

    result = google_api_client.execute(
      api_method: api_resource.send(method),
      parameters: parameters,
      body: body,
      headers: { 'Content-Type' => content_type }
    )
  end

  # Accessor for the OmniAuth authorization information
  def auth_info
    request.env["omniauth.auth"]
  end

end
