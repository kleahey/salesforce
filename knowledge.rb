require 'restforce'
require 'mysql2'
require './libs/configs'
require 'time'
require 'csv'
require 'stringex'
require 'hashie'

Restforce.log = true

def import_csv(file_name)
  # Create a new array to hold FAQ data from Production environment
  prod_data = []
  # Connect to CSV file and store data in new data hash
  data = CSV.read(file_name)
  # Iterate through each row and push to a new array as a key[header]:value[data] pair
  data.each do |x|
    prod = []
    new_prod = []
    i = 0
    while i < data[0].length
      prod.push(data[0][i].to_s => x[i].to_s)
      i += 1
    end
    # Check the "Applicant Type" field to see if data contains exception
    if prod[3]["Applicant Type"] == "Both First Year and Transfer"
      i = 0
      while i < data[0].length
        new_prod.push(data[0][i].to_s => x[i].to_s)
        i += 1
      end
      prod.delete_at(3)
      prod.insert(3, { "Applicant Type"=>"First Year" })
      prod_data.push(prod)
      new_prod.delete_at(3)
      new_prod.insert(3, { "Applicant Type"=>"Transfer" })
      prod_data.push(new_prod)
    else
      prod_data.push(prod)
    end
  end
  # Delete the 0 index from the new array, which contains all headers
  prod_data.delete_at(0)
end

# Use prod_data array to export data from CSV to Salesforce
def bulk_export_to_salesforce
  client = Salesforce.initialize

  @prod_data = import_csv("/Users/kevinleahey/Downloads/prodSheet1.csv")

  @prod_data.each do |x|
    # Upsert FAQ object and retrieve the FAQ Object Id
    query = client.query("SELECT Id FROM Account WHERE Name='" + x[0]["FAQ Name"].to_s + "'")
    client.upsert("FAQ__c", "Name", :Name => x[0]["FAQ Name"], :Account__c => query.first["Id"], :Status__c => "Submitted")
    query2 = client.query("SELECT Id FROM FAQ__c WHERE Name='" + x[0]["FAQ Name"].to_s + "'")
    faq_id = query2.first.Id
    # Use FAQ object as parent to create a new Help Topic child and return the Help Topic ID
    help_topic_id = client.create("Help_Topic__c", Name: x[1]["Help Topic Name"], Title__c: x[12]["Title"], Body__c: x[4]["Body"], Form_Type__c: x[5]["Form Type"], FAQ__c: faq_id)
    # Create a new DRAFT Member Specific FAQ Article in Knowledge Base and return the Article ID
    # Generate a random string to append to the end of the url name to ensure unique value
    random_string = (0...8).map { (65 + rand(26)).chr }.join
    # The following is pulling the WRONG ID. It returns the KnowledgeArticleVersion created, not the KnowledgeArticle
    article_id = client.create("Member_Specific_FAQ_Article__kav", Title: x[12]["Title"], Article_Content__c: x[4]["Body"], UrlName: (x[12]["Title"].to_s + " " + random_string).to_url, IsVisibleInPkb: true)
    # Create a new Article Relationship record using Area ID, Help Topic ID, & Article ID
    # and return the Article Relationship ID
    if x[10]["Section Name"]=="Other"
      area = x[0]["FAQ Name"].to_s + " " + x[3]["Applicant Type"].to_s + " " + x[11]["Section Name (if other):"].to_s
    else
      area = x[0]["FAQ Name"].to_s + " " + x[3]["Applicant Type"].to_s + " " + x[10]["Section Name"].to_s
    end
    query3 = client.query("SELECT Id FROM Application_Area__c WHERE Name='" + area + "'")
    area_id = query3.first.Id
    article_relationship_id = client.create("Article_Relationship__c", Application_Area__c: area_id, Help_Topic__c: help_topic_id, Article_Id__c: article_id )
    client.upsert("Article_Relationship__c", "Id", Id: article_relationship_id, Application_Area__c: area_id, Help_Topic__c: help_topic_id, Article_Id__c: article_id)
  rescue StandardError => e
    puts "ERROR: #{e.message}"
  next
  end
end

# Update the Article Id in the Article Relationship object (Used to correct an error)
def update_relationship_info
  arr = []
  client = Salesforce.initialize
  wrong = client.query("SELECT Id, Article_Id__c FROM Article_Relationship__c")
  wrong.each do |x|
    result = client.query("SELECT KnowledgeArticleId FROM KnowledgeArticleVersion WHERE ArticleType='Member_Specific_FAQ_Article__kav' AND Id='" + x.Article_Id__c + "'")
    result.each do |y|
      client.update("Article_Relationship__c", Id: x.Id, Article_Id__c: y.KnowledgeArticleId)
    end
    puts arr
  end
end

# Pull Article Id into the Help Topic from Article Relationship (used to correct an error)
client = Salesforce.initialize
request = client.query("SELECT Id, Article_Id__c,Help_Topic__r.Id,Help_Topic__r.Title__c,Help_Topic__r.Article_Id__c FROM Article_Relationship__c")

request.each do |x|
  if x.Help_Topic__r == nil
    next
  else
    client.update("Help_Topic__c", Id: x.Help_Topic__r.Id, Article_Id__c: x.Article_Id__c)
  end
end