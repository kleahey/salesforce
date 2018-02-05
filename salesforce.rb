require "salesforce_bulk"

s = SalesforceBulk::Api.new("kleahey@commonapp.org.partial",
                                     "Planet@ry7WPf6rc2wliBFbClZWLqQ5P7H9",
                                     true)

records_to_delete = []

query = s.query("Article_Relationship__c", "SELECT Id FROM Article_Relationship__c")

records = query.result.records

records.each_with_index do |x, index|
  instance_variable_set("@number_#{index}", Hash[ "Id" => x["Id"] ])
  records_to_delete.push("@number_#{index}")
end


=begin
records_to_delete.map do |x|
  result = s.delete("Article_Relationship__c", x, true)
  puts result.result.success?
  puts result.result.has_errors?
  puts result.result.errors
end
=end
