require 'restforce'
require 'mysql2'
require './libs/configs'
require 'time'

# Time tracking
start = Time.now

# Define Restforce debugging
Restforce.log = true

# Variables for storing Common App RDS and Salesforce query strings
@screens_and_sections = "SELECT sc.ScreenId,
                                CONCAT(\"CA \",
                                CASE when sc.FY = 1 and sc.TR = 0
                                then \"FY\"
                                when sc.FY = 0 and sc.TR = 1
                                then \"TR\"
                                else \"FY/TR\" END,
                                \" \", sc.Name) AS ScreenLabel,
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
                        WHERE MemberId is null and sc.DeleteStatus=0;"

@member_screens_and_sections = "SELECT m.MemberId,
	                        m.Name,
	                        sc.ScreenId,
	                        CONCAT(m.Name, \" \", CASE when sc.FY = 1 then \"First Year\" ELSE \"Transfer\" END, \" \", sc.Name) AS ScreenLabel,
	                        se.SectionId,
	                        CONCAT(m.Name, CASE when sc.FY = 1 then \" First Year\" ELSE \" Transfer\" END, \" \", se.Label) AS SectionLabel
                        FROM Member m
                        INNER JOIN Screen sc on m.MemberId=sc.MemberId and sc.DeleteStatus=0
                        INNER JOIN Section se on se.ScreenId=sc.ScreenId and se.DeleteStatus=0
                        WHERE m.Status IN (1,2) and m.DeleteStatus=0;"

# Method for connecting to Common App database and submitting a query
def query_commonapp(query)
  rds = Commonapp.rds
  rds.query(query)
end

# Method for upserting Common Screen information to Salesforce
def common_screen_upsert
  client = Salesforce.initialize
  screens = []
  results = query_commonapp(@screens_and_sections)

  results.map do |row|
    screens.push(row)
  end

  screens.map do |x|
    id = x['ScreenId'].to_s
    client.upsert('Application_Area__c',
                  'Identifier__c',
                  Identifier__c: id,
                  Name: x['ScreenLabel'],
                  Application_Id__c: x['ScreenId'],
                  Type__c: 'Screen')
  end
end

# Method for upserting Common Section information to Salesforce
def common_section_upsert
  client = Salesforce.initialize
  sections = []
  results = query_commonapp(@screens_and_sections)

  results.map do |row|
    sections.push(row)
  end

  mapping = {}
  sf = client.query('SELECT Identifier__c, Id FROM Application_Area__c')

  sf.each do |x|
    mapping["#{x["Identifier__c"]}"] = x['Id']
  end

  sections.map do |x|
    id = x['ScreenId'].to_s + x['SectionId'].to_s
    client.upsert('Application_Area__c',
                  'Identifier__c',
                  Identifier__c: id,
                  Name: x['SectionLabel'],
                  Application_Id__c: x['SectionId'],
                  Type__c: 'Section',
                  Parent__c: mapping[ x['ScreenId'].to_s ])
  end
end

def member_screen_upsert
  client = Salesforce.initialize
  member_screens = []
  results = query_commonapp(@member_screens_and_sections)

  results.map do |row|
    member_screens.push(row)
  end

  members = {}
  sf = client.query("SELECT Client_ID__c, Id
                        FROM Account
                        WHERE Client_ID__c NOT IN (null, 'x')
                        ORDER BY Client_ID__c ASC NULLS FIRST")
  sf.each do |x|
    members["#{x["Client_ID__c"]}"] = x['Id']
  end

  member_screens.map do |x|
    id = x['ScreenId'].to_s
    client.upsert('Application_Area__c',
                  'Identifier__c',
                  Identifier__c: id,
                  Name: x['ScreenLabel'],
                  Application_Id__c: x['ScreenId'],
                  Type__c: 'Screen',
                  Account__c: members[ x['MemberId'].to_s ])
  end
end

def member_section_upsert
  client = Salesforce.initialize
  member_sections = []
  results = query_commonapp(@member_screens_and_sections)

  results.map do |x|
    member_sections.push(x)
  end

  mapping = {}
  sf = client.query('SELECT Identifier__c, Id FROM Application_Area__c')

  sf.each do |x|
    mapping["#{x["Identifier__c"]}"] = x['Id']
  end

  members = {}
  sf2 = client.query("SELECT Client_ID__c, Id
                        FROM Account
                        WHERE Client_ID__c NOT IN (null, 'x')
                        ORDER BY Client_ID__c ASC NULLS FIRST")
  sf2.each do |x|
    members["#{x["Client_ID__c"]}"] = x['Id']
  end

  member_sections.map do |x|
    id = x['ScreenId'].to_s + x['SectionId'].to_s
    client.upsert('Application_Area__c',
                  'Identifier__c',
                  Identifier__c: id,
                  Name: x['SectionLabel'],
                  Application_Id__c: x['SectionId'],
                  Type__c: 'Section',
                  Parent__c: mapping[ x['ScreenId'].to_s ],
                  Account__c: members[ x['MemberId'].to_s ])
  end
end

def refresh_all_screens_and_sections
  common_screen_upsert
  common_section_upsert
  member_screen_upsert
  member_section_upsert
end

member_screen_upsert
member_section_upsert

# Time end
finish = Time.now
diff = finish - start
puts diff