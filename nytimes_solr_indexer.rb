require 'java'
require 'rubygems'
require 'rsolr'
require 'rsolr-direct'
require 'timestools.jar'

class String
  def starts_with?(prefix)
    prefix = prefix.to_s
    self[0, prefix.length] == prefix
  end
 
  def ends_with?(suffix)
    suffix = suffix.to_s
    self[-suffix.length, suffix.length] == suffix      
  end
end

def untar_dir(dir)
  tar_files = Dir[File.join(dir, "**", "*")].map{|f| f if File.basename(f).ends_with?(".tgz")}.compact
  
  tar_files.each do |file|
    puts "Untaring #{file}"
    system("tar -C #{File.dirname(file)} -zxvf #{file}")
  end  
end

def index_dir(dir, opts={})
  solr = nil
  if opts[:solr_home] != nil
    RSolr.load_java_libs
    solr = RSolr.connect :direct, :solr_home => opts[:solr_home]
  elsif opts[:solr_server_url] != nil
    solr = RSolr.connect :url=> opts[:solr_server_url]
  else
    raise "You must specify a solr_home or solr_server_url"
  end
  solr.delete_by_query "*:*"

  docs = []
  xml_files = Dir[File.join(dir, "**", "*")].map{|f| f if File.basename(f).ends_with?(".xml")}.compact
  
  xml_files.each_with_index do |file, i|
    #puts "Processing #{file}"
    docs << parse_and_create_hash_from_nyt_file(java.io.File.new(file))
    
    #commit every 2000 docs to reduce mem usage
    if(i % 2000 == 0)
      solr.add(docs)
      solr.commit
      solr.optimize
      docs = []
    end
  end  
end

def parse_and_create_hash_from_nyt_file(file) 
    parser = com.nytlabs.corpus.NYTCorpusDocumentParser.new
    nytDoc = parser.parseNYTCorpusDocumentFromFile(file, false)

    create_hash_from_nyt_doc(nytDoc)
end

def create_hash_from_nyt_doc(nytDoc)
  doc = {}
  
  #strings
  doc["id"] = nytDoc.getGuid()
  doc["alternativeURL"] = nytDoc.getAlternateURL()
  doc["url"] = nytDoc.getUrl()
  doc["articleAbstract"] = nytDoc.getArticleAbstract()
  doc["authorBiography"] = nytDoc.getAuthorBiography()
  doc["banner"] = nytDoc.getBanner()
  doc["body"] = nytDoc.getBody()
  doc["byline"] = nytDoc.getByline()
  doc["columnName"] = nytDoc.getColumnName()
  doc["correctionText"] = nytDoc.getCorrectionText()
  doc["credit"] = nytDoc.getCredit()
  doc["dateline"] = nytDoc.getDateline()
  doc["dayOfWeek"] = nytDoc.getDayOfWeek()
  doc["featurePage"] = nytDoc.getFeaturePage()
  doc["headline"] = nytDoc.getHeadline()
  doc["kicker"] = nytDoc.getKicker()
  doc["leadParagraph"] = nytDoc.getLeadParagraph()
  doc["newsDesk"] = nytDoc.getNewsDesk()
  doc["normalizedByline"] = nytDoc.getNormalizedByline()
  doc["onlineHeadline"] = nytDoc.getOnlineHeadline()
  doc["onlineLeadParagraph"] = nytDoc.getOnlineLeadParagraph()
  doc["onlineSection"] = nytDoc.getOnlineSection()
  doc["section"] = nytDoc.getSection()
  doc["seriesName"] = nytDoc.getSeriesName()
  doc["slug"] = nytDoc.getSlug()
  doc["sourceFile"] = nytDoc.getSourceFile().toString()

  #numerics
  doc["columnNumber"] = nytDoc.getColumnNumber()
  doc["guid"] = nytDoc.getGuid()
  doc["page"] = nytDoc.getPage()
  doc["publicationDayOfMonth"] = nytDoc.getPublicationDayOfMonth()
  doc["publicationMonth"] = nytDoc.getPublicationMonth()
  doc["publicationYear"] = nytDoc.getPublicationYear()
  doc["wordCount"] = nytDoc.getWordCount()
  
  #dates
  doc["publicationDate"]= Date.parse(nytDoc.getPublicationDate().to_s).strftime("%Y-%m-%dT00:00:00Z")
  doc["correctDate"] = Date.parse(nytDoc.getCorrectionDate().to_s).strftime("%Y-%m-%dT00:00:00Z") rescue nil
  
  #mulitvalues
  doc["biographicalCategories"] = nytDoc.getBiographicalCategories().to_a
  doc["descriptors"] = nytDoc.getDescriptors().to_a
  doc["generalOnlineDescriptors"] = nytDoc.getGeneralOnlineDescriptors().to_a
  doc["locations"] = nytDoc.getLocations().to_a
  doc["names"] = nytDoc.getNames().to_a
  doc["onlineDescriptors"] = nytDoc.getOnlineDescriptors().to_a
  doc["onlineLocations"] = nytDoc.getOnlineLocations().to_a
  doc["onlineOrganizations"] = nytDoc.getOnlineOrganizations().to_a
  doc["onlinePeople"] = nytDoc.getOnlinePeople().to_a
  doc["onlineTitles"] = nytDoc.getOnlineTitles().to_a
  doc["organizations"] = nytDoc.getOrganizations().to_a
  doc["people"] = nytDoc.getPeople().to_a
  doc["taxonomicClassifiers"] = nytDoc.getTaxonomicClassifiers().to_a
  doc["titles"] = nytDoc.getTitles().to_a
  doc["typesOfMaterial"] = nytDoc.getTypesOfMaterial().to_a
  
  doc
end

puts "Indexing NYTimes Corpus"
puts "-----"

if(ARGV.size != 2)
  puts " This script will untar the xml files and index them with Solr"
  puts " Specify a path the nytimes corpus data folder and solr home"
  puts "jruby nytimes_solr_indexer.rb \"path/to/nytimes data/data\" \"/path/to/solr/home\""
  puts " You can also post a solr server by specifying a solr server in the second parameter"
  puts "jruby nytimes_solr_indexer.rb \"path/to/nytimes data/data\" \"http://localhost:8983/solr\""
else
  dir = ARGV[0] #"/Users/wheels/data/tmp_data"
  server_or_solr_dir = ARGV[1] #"/Users/wheels/src/java/nytimes/solr/solr" or "http://localhost:8983/solr"
  opts= {}
  if server_or_solr_dir.starts_with?("http://")
    opts[:solr_server_url] = server_or_solr_dir
  else
    opts[:solr_home] = server_or_solr_dir
  end
      
  puts "Processing #{ARGV[0]}"
  #untar_dir(dir)
  index_dir(dir, opts)  
  puts "Done!"
end