require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(project_id: 'cs291a')
bucket = storage.bucket 'cs291project2', skip_lookup: true

require 'sinatra'
require 'digest'

get '/' do
  redirect "/files/", 302
end


get '/files/' do
  #Responds 200 with a JSON body containing a 
  #sorted list of valid SHA256 digests in 
  #sorted order (lexicographically ascending).
  fileNameList = []
  all_files = bucket.files 
  all_files.all do |file|
    fileName = file.name

    unless fileName.count("/") == 2 and 
      fileName.index('/') == 2 and 
      fileName.index('/', 3) == 5
      next
    end

    fileName = fileName.gsub("/", "")
    unless fileName.match(/^[a-f0-9]{64}$/)
      next
    end
    fileNameList << fileName
  end


  fileNameList.sort
  return [200, fileNameList.to_json]
end

get '/files/:digest' do
  fileDigest = params["digest"]
  unless fileDigest.match(/^[A-Fa-f0-9]{64}$/)
    return [422, "Invalid Digest!\n"]
  end
  fileDigest = fileDigest.downcase
  fileDigest = fileDigest.insert(4, "/")
  fileDigest = fileDigest.insert(2, "/")

  file = bucket.file fileDigest
  if file.nil?
    return [404, "The Required File Not Found!\n"]
  end

  downloaded = file.download
  downloaded.rewind
  content_type = file.content_type
  return [200, {"Content-Type" => content_type}, downloaded.read]
end

post '/files/' do
  unless params["file"] and 
    (tmpFile = params["file"]["tempfile"]) and 
    (tmpFile.instance_of? Tempfile)
      return [422, "Do Not Match The Input Requirements!\n"]
  end

  #puts params["file"]
  #tmpFile = params["file"]["tempfile"]
  #fileName = params["file"]["filename"]
  #check input file size
  fileSize = tmpFile.size()
  if fileSize > 1024 * 1024
    return [422, "File Size Are Too Large!\n"]
  end
  #cal input file sha256 digest based on file's content
  dataDigest = Digest::SHA256.hexdigest tmpFile.read
  #generate store path
  path = dataDigest.downcase
  path = path.insert(4, "/")
  path = path.insert(2, "/")
  #puts path
  #puts params
  checkFile = bucket.file path
  if checkFile
    return [409, "The Uploaded File Is Already There!\n"]
  end
  #move the begin of the tmpFile (to re-read it)
  #tmpFile.rewind
  #data = tmpFile.read
  contentType = params["file"]["type"]
  bucket.create_file tmpFile, path, content_type: contentType
  resp = {"uploaded" => dataDigest}
  #strub code
  ##uploadedFile = {'fileName': fileName, 'fileContent': data}
  return [201, resp.to_json]
end

delete '/files/:digest' do

  fileDigest = params["digest"]
  fileDigest = fileDigest.downcase

  unless fileDigest.match(/^[A-Fa-f0-9]{64}$/)
    return [422, "Not Valid Digest\n"]
  end
  
  fileDigest = fileDigest.insert(4, "/")
  fileDigest = fileDigest.insert(2, "/")

  fileCheck = bucket.file fileDigest
  if fileCheck
    fileCheck.delete
  end

  return [200, ""]

end

