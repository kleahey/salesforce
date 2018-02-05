require 'restforce'
require 'aws-sdk'
require 'mysql2'
require './libs/restforce'
require './libs/rds'
require 'time'

# Time
start = Time.now

# Initialize RDS Connection with Mysql2
rds = Rds.initialize

# Query to pull all of the common screens in the Common Application
results = rds.query("SELECT sc.ScreenId,
		                    CONCAT(\"CA \",
                                CASE when sc.FY = 1 and sc.TR = 0
                                then \"FY\"
                                when sc.FY = 0 and sc.TR = 1
                                then \"TR\"
                                else \"FY/TR\" END,
                                \" \", sc.Label) AS ScreenLabel,
		                    se.SectionId,
		                    CONCAT(\"CA \",
                                CASE when sc.FY = 1 and sc.TR = 0
                                then \"FY\"
                                when sc.FY = 0 and sc.TR = 1
                                then \"TR\"
                                else \"FY/TR\" END,
                                \" \", se.Label) AS SectionLabel
                        FROM Screen sc
                        INNER JOIN Section se on se.ScreenId=sc.ScreenId and se.DeleteStatus=0
                        WHERE MemberId is null and sc.DeleteStatus=0;")

# Create an array of ScreenIds and Label information
screens = []

results.map do |row|
  screens.push(row)
end

# Create Salesforce connection client
Restforce.log = true
client = Salesforce.initialize

# Use hash array created with screen information to upsert records in Salesforce
screens.map do |x|
  id = x["ScreenId"].to_s
  client.upsert("Application_Area__c",
                "Identifier__c",
                Identifier__c: id,
                Name: x["ScreenLabel"],
                Application_Id__c: x["ScreenId"],
                Type__c: "Screen")
end

# Query to pull all of the common sections in the Common Application
query = rds.query("SELECT sc.ScreenId,
		                    CONCAT(\"CA \",
                                CASE when sc.FY = 1 and sc.TR = 0
                                then \"FY\"
                                when sc.FY = 0 and sc.TR = 1
                                then \"TR\"
                                else \"FY/TR\" END,
                                \" \", sc.Label) AS ScreenLabel,
		                    se.SectionId,
		                    CONCAT(\"CA \",
                                CASE when sc.FY = 1 and sc.TR = 0
                                then \"FY\"
                                when sc.FY = 0 and sc.TR = 1
                                then \"TR\"
                                else \"FY/TR\" END,
                                \" \", se.Label) AS SectionLabel
                        FROM Screen sc
                        INNER JOIN Section se on se.ScreenId=sc.ScreenId and se.DeleteStatus=0
                        WHERE MemberId is null and sc.DeleteStatus=0;")

# Create an array of SectionIds and Label information
sections = []

query.map do |x|
  sections.push(x)
end

# Create a hash of ScreenId => ScreenIdKey (Salesforce Id)
mapping = Hash.new
results = client.query("SELECT Identifier__c, Id FROM Application_Area__c")

results.each do |x|
  mapping["#{x["Identifier__c"]}"] = x["Id"]
end

# Use hash array created with section information to create new records in Salesforce
sections.map do |x|
  id = x["ScreenId"].to_s + x["SectionId"].to_s
  client.upsert("Application_Area__c",
                "Identifier__c",
                Identifier__c: id,
                Name: x["SectionLabel"],
                Application_Id__c: x["SectionId"],
                Type__c: "Section",
                Parent__c: mapping[ x["ScreenId"].to_s ])
end

# Query to pull all of the Member screens in the Common Application
results = rds.query("SELECT m.MemberId,
	                        m.Name,
	                        sc.ScreenId,
	                        CONCAT(m.MemberId, \" \", CASE when sc.FY = 1 then \"FY\" ELSE \"TR\" END, \" \", sc.Label) AS ScreenLabel,
	                        se.SectionId,
	                        CONCAT(CASE when sc.FY = 1 then \"First Year\" ELSE \"Transfer\" END, \" \", se.Label) AS SectionLabel
                        FROM Member m
                        INNER JOIN Screen sc on m.MemberId=sc.MemberId and sc.DeleteStatus=0
                        INNER JOIN Section se on se.ScreenId=sc.ScreenId and se.DeleteStatus=0
                        WHERE m.Status IN (1,2) and m.DeleteStatus=0;")

# Create an array of Member ScreenIds and Label information
member_screens = []

results.map do |row|
  member_screens.push(row)
end

# Create a hash of MemberId => MemberIdKey (Salesforce Id)
members = Hash.new
results = client.query("SELECT Client_ID__c, Id \
                        FROM Account \
                        WHERE Client_ID__c NOT IN (null, 'x') \
                        ORDER BY Client_ID__c ASC NULLS FIRST")

results.each do |x|
  members["#{x["Client_ID__c"]}"] = x["Id"]
end

# Use hash array created with screen information to create new records in Salesforce
member_screens.map do |x|
  id = x["ScreenId"].to_s
  client.upsert("Application_Area__c",
                "Identifier__c",
                Identifier__c: id,
                Name: x["ScreenLabel"],
                Application_Id__c: x["ScreenId"],
                Type__c: "Screen",
                Account__c: members[ x["MemberId"].to_s ])
end

# Query to pull all of the Member sections in the Common Application
results = rds.query("SELECT m.MemberId,
	                        m.Name,
	                        sc.ScreenId,
	                        CONCAT(m.MemberId, \" \", CASE when sc.FY = 1 then \"FY\" ELSE \"TR\" END, \" \", sc.Label) AS ScreenLabel,
	                        se.SectionId,
	                        CONCAT(CASE when sc.FY = 1 then \"First Year\" ELSE \"Transfer\" END, \" \", se.Label) AS SectionLabel
                        FROM Member m
                        INNER JOIN Screen sc on m.MemberId=sc.MemberId and sc.DeleteStatus=0
                        INNER JOIN Section se on se.ScreenId=sc.ScreenId and se.DeleteStatus=0
                        WHERE m.Status IN (1,2) and m.DeleteStatus=0;")

# Create an array of SectionIds and Label information
member_sections = []

results.map do |x|
  member_sections.push(x)
end

# Create a hash of ScreenId => ScreenIdKey (Salesforce Id)
mapping = Hash.new
results = client.query("SELECT Identifier__c, Id FROM Application_Area__c")

results.each do |x|
  mapping["#{x["Identifier__c"]}"] = x["Id"]
end

# Use hash array created with section information to create new records in Salesforce
member_sections.map do |x|
  id = x["ScreenId"].to_s + x["SectionId"].to_s
  client.upsert("Application_Area__c",
                "Identifier__c",
                Identifier__c: id,
                Name: x["SectionLabel"],
                Application_Id__c: x["SectionId"],
                Type__c: "Section",
                Parent__c: mapping[ x["ScreenId"].to_s ],
                Account__c: members[ x["MemberId"].to_s ])
end

# Time
finish = Time.now
diff = finish - start
puts diff