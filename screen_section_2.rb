require "oauth"
require "restforce"

consumer_key    = "3MVG9dCCPs.KiE4QmRacdUVI_XPT3er3iFNmpQjjgai.XzfwGYV92EU70cExfg9z_dXn.qnYOhPPk7M7FEsIQ"# from SalesForce
consumer_secret = "2272798963237739950" # from SalesForce
access_token    = "5Aep861wugch8LWHvl0PwS.SOaGiTeut2Cl0MJHWsxybLROHTmVgeLPMcS0J7MdiU4CrshXHjyaqJ41nr4Uq5JF" # from the previous step
access_secret   = "-3016766648989635509" # from the previous step

client = Restforce.new(oauth_token: access_token,
                       instance_url: 'https://cs78.salesforce.com',
                       api_version: '41.0')

query = client.query("SELECT Name FROM Application_Area__c")

puts query