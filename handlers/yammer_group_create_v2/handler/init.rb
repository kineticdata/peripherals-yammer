# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class YammerGroupCreateV2
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text
    }
    @enable_debug_logging = @info_values['enable_debug_logging'] == 'Yes'

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      # Associate the attribute name to the String value (stripping leading and
      # trailing whitespace)
      @parameters[node.attribute('name').value] = node.text.to_s.strip
    end

    # Catching a blank group name before the call is sent
    if @parameters['group_name'].empty?
      raise StandardError, "Invalid Request: Group Name cannot be empty."
    end
  end

  def execute()
    # Building the object that will be sent to Yammer to create the group
    post_object = {"name" => @parameters['group_name']}

    if @parameters['private'] == "true"
      post_object['private'] = "true"
    end

    # Just noting here that at the moment it appears that a group will only be
    # created on a users default network. This all depends on what network the
    # access_token refers to, and for now it seems that the only obvious token
    # connection is to the default
    begin
      puts "Creating the group on Yammer" if @enable_debug_logging
      result = RestClient.post("https://www.yammer.com/api/v1/groups.json", post_object,
        :authorization=>"Bearer #{@info_values['access_token']}")
    # If the access token is expired, throws an error to let the user that they
    # need to retrieve and input a new access token
    rescue RestClient::Unauthorized
      raise StandardError, "Bad/Expired Access Token (Unauthorized): Please check that your access token is still valid and try again."
    rescue RestClient::ResourceNotFound => error
      json_resp = JSON.parse(error.response)
      if json_resp["name"].to_s == "is not unique"
        raise StandardError, "Invalid Group: A group with the name #{@parameters['group_name']} already exists in this network."
      end
      raise
    end

    return "<results/>"
  end

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

end