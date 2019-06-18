# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class YammerMessagePostV2
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
  end

  def execute()
    post_object = {"body" => @parameters['message']}

    # Getting the group id cooresponding to the inputted group name (if included)
    if @parameters['group_name'] != ''
      puts "Obtaining the Yammer group id by retrieving a list of groups" if @enable_debug_logging
      begin
        group_resp = RestClient.get("https://www.yammer.com/api/v1/groups.json",
         :authorization=>"Bearer #{@info_values['access_token']}")
      # If the access token is expired, throws an error to let the user that they
      # need to retrieve and input a new access token
      rescue RestClient::Unauthorized
        raise StandardError, "Bad/Expired Access Token (Unauthorized): Please check that your access token is still valid and try again."
      end
      group_json = JSON.parse(group_resp)

      puts "Finding the group id using the Yammer response" if @enable_debug_logging
      for group in group_json
        if group["full_name"] == @parameters['group_name']
          group_id = group['id']
        end
      end

      # Throwing an error if the group was not found in the domain
      if group_id.nil?
        raise StandardError, "Invalid Group Name: Group cannot be found on this domain"
      else
        post_object['group_id'] = group_id
      end
    end

    # Just noting here that at the moment it appears that a message will only be
    # posted to a users default network. This all depends on what network the
    # access_token refers to, and for now it seems that the only obvious token
    # connection is to the default
    puts "Posting the message the Yammer" if @enable_debug_logging
    result_json = RestClient.post("https://www.yammer.com/api/v1/messages.json", post_object,
      :authorization=>"Bearer #{@info_values['access_token']}")

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