require 'net/http'
require 'uri'
puts "using http-ncbi-dbs-dgs.rake"
# Downloads tarball at the given URL if a local copy does not exist, or if the
# local copy is older than at the given URL, or if the local copy is corrupt.
def download(url, last_to_do)
  file = File.basename(url)

  # # Resume an interrupted download or fetch the file for the first time. If
  # # the file on the server is newer, then it is downloaded from start.

  sh "wget -Nc --no-verbose #{url}"
  # If the local copy is already fully retrieved, then the previous command
  # ignores the timestamp. So we check with the server again if the file on
  # the server is newer and if so download the new copy.
  sh "wget -N --no-verbose #{url}"
  sh "wget -Nc --no-verbose #{url}.md5"
  sh "wget -N --no-verbose #{url}.md5"
  # Immediately download md5 and verify the tarball. Re-download tarball if
  # corrupt; extract otherwise.
  sh "md5sum -c #{file}.md5" do |matched, _|
    if !matched
      sh "rm #{file} #{file}.md5"; download(url)
    # too many tar instances unzipping the same file clutter the system
    elsif file == last_to_do;
      sh "tar xfov #{file}"
    else
      # at least nr and nt tarballs have identical files .?al; unsure of others
      sh "tar xfov #{file} --exclude='*.?al' --exclude='taxdb*'"
    end
  end
end


def databases
  method = 'https://'
  host, dir = 'ftp.ncbi.nlm.nih.gov', 'blast/db'
  uri = URI.parse(method + host + "/" + dir + "/")

  response = Net::HTTP.get_response(uri)
  body = response.body.split

  array_of_files = []
  body.each do |line|
    # regex takes the raw http response, matches lines such as:
    #    href="tsa_nt.06.tar.gz.md5">tsa_nt.06.tar.gz</a>
    # Returns:
    # tsa_nt.06.tar.gz
    filenames_and_newlines = line[/(^href=".*">)(.*tar.gz|.*md5)(<\/a>)$/, 2]
    array_of_files.append(filenames_and_newlines) unless filenames_and_newlines.nil?
  end

  # append the full path to file for downstream wget
  array_of_files.map! { |string| "".concat("/blast/db/", string ) }
  array_of_files.
    map { |file| File.join(host, file) }.
    select { |file| file.match(/\.tar\.gz$/) }.
    group_by { |file| File.basename(file).split('.')[0] }
end


# Create user-facing task for each database to drive the download of its
# volumes in parallel.
databases.each do |name, files|
  last = { name => files.last }
  multitask(name => files.map { |file| task(file) { download(file, last.values.uniq) } })
end

# List name of all databases that can be downloaded if executed without
# any arguments.
task :default do
  databases
  puts databases.keys.push('taxdump').join(', ')
end

task :taxdump do
  download('https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz', "nil")
end

# Ruby being over my head, this is my quick-and-dirty way to trick it ignoring
# "http" as a task rather than a specification. Happy for an expert to fix it up!
task :http do
  puts "using http method"
end
