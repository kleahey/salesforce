require 'restforce'
require 'mysql2'

class Salesforce
  def self.initialize
    Restforce.new(
      host: ENV['SALESFORCE_HOST'],
      username: ENV['SALESFORCE_USERNAME'],
      password: ENV['SALESFORCE_PASSWORD'],
      security_token: ENV['SALESFORCE_SECURITY_TOKEN'],
      client_id: ENV['SALESFORCE_CLIENT_ID'],
      client_secret: ENV['SALESFORCE_CLIENT_SECRET'],
      api_version: ENV['SALESFORCE_API_VERSION']
    )
  end
end

class Commonapp
  def self.rds
    Mysql2::Client.new(
      host: ENV['COMMONAPP_HOST'],
      username: ENV['COMMONAPP_USERNAME'],
      password: ENV['COMMONAPP_PASSWORD'],
      port: ENV['COMMONAPP_PORT'],
      database: ENV['COMMONAPP_DATABASE']
    )
  end
end