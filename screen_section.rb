require "restforce"
require "oauth"

consumer_key    =  "3MVG9dCCPs.KiE4QmRacdUVI_XPT3er3iFNmpQjjgai.XzfwGYV92EU70cExfg9z_dXn.qnYOhPPk7M7FEsIQ"# from SalesForce
consumer_secret = "2272798963237739950" # from SalesForce

oauth_options = {
    :site => "https://test.salesforce.com",
    :scheme => :body,
    :request_token_path => '/_nc_external/system/security/oauth/RequestTokenHandler',
    :authorize_path => '/setup/secur/RemoteAccessAuthorizationPage.apexp',
    :access_token_path => '/_nc_external/system/security/oauth/AccessTokenHandler',
}

consumer = OAuth::Consumer.new consumer_key, consumer_secret, oauth_options
# consumer.http.set_debug_output STDERR # if you're curious

request       = consumer.get_request_token
authorize_url = request.authorize_url :oauth_consumer_key => consumer_key

puts "Go to #{authorize_url} in your browser, then enter the verification code:"
verification_code = gets.strip

access = request.get_access_token :oauth_verifier => verification_code

puts "Access Token:  " + access.token
puts "Access Secret: " + access.secret
puts access.inspect
