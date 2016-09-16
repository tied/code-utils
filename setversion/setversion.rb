#!ruby

# Usage: setversion.sh version_info_template version_info_automated.h
# The script will copy the version header file template to the second file given
# and insert build and version info automatically.
# Script change the header file if running on Jenkins with global unique values,
# while local developer build get less unique informations.
# The automated file should be on the git ignore list, but the application should
# depende on the includes from both the default version_info.h file, and the automated
# one such the compilation will fail if the automated does not exists.
require "find"
require "fileutils"
require "open3"

# Parse input paramenter:
# one mandatory settings file in ruby (not validating the file)
if ARGV.length() != 2 then
  puts <<-EOF
Please provide a settings file as only parameter

usage:
  setversion.rb template_file target_file
EOF
  abort("Wrong input parameters")
else
  template = ARGV[0];
  target = ARGV[1]
  # assume file is in correct format and load it
  puts "Using:"
  puts "   templatefile - " + template
  puts "   targetfile   - " + target
end

if File.exist?(template) then
  FileUtils.cp template, target
else
  abort("Template file: "+template +" did not exist.target!!!.")
end

# Note: By purpose this cookie is chosen to be hardcoded, so as long we
# build on the same server we set version information.
# Building historical build later, on another server, will not be able
# without modification to get version information. That by purpose!
# Further by checking on PROJECT-STAMP-VERSION we can disable/enable
# if version is applied when building on Jenkins.
# The PROJECT-BUILD-NUMBER is instead of Jenkins BUILD_NUMBER and to allow
# changing it a bit.
if ENV['JENKINS_SERVER_COOKIE'] == "uniquejenkinscookie-couldbecertcheckalso" then
  if ENV['PROJECT_STAMP_VERSION'] == "yes" then
    puts "Running on our JenkinsServer - setting version info to unique values"
    puts "Writing version information to file: "+ target

    File.open(target){ |source_file|
      content = source_file.read
      content.gsub!('xxxx', ENV['PROJECT_BUILD_NUMBER'])
      content.gsub!('unknown', 'jenkins')
      content.gsub!('1970-01-01_00-00-00', ENV['BUILD_ID'])
      gitVersion = %x(git rev-parse --short HEAD).gsub(/\n/, '')
      puts "setversion setting git version: ["+gitVersion+"]"
      content.gsub!('not_available', gitVersion)
    File.open(target, "w+"){ |f| f.write(content)}
    }
  else
    puts "Running on our JenkinsServer - by disabled setting unique values"
    puts "Writing version information to file: "+ target

    File.open(target){ |source_file|
      content = source_file.read
      content.gsub!('xxxx', 'ci-build')
      content.gsub!('unknown', 'jenkins')
      content.gsub!('1970-01-01_00-00-00', ENV['BUILD_ID'])
      content.gsub!('not_available', 'unknown revision')
    File.open(target, "w+"){ |f| f.write(content)}
    }
  end

else
  puts "Local/developer build (not Jenkins) therefore less unique version info";
  time = Time.new
  if ENV['USERNAME']  == nil then
    user =  ENV['USER']
  else
    user = ENV['USERNAME']
  end
  File.open(target){ |source_file|
     content = source_file.read
     content.gsub!('xxxx', 'dev-snapshot')
     content.gsub!('unknown', user)
     content.gsub!('1970-01-01_00-00-00', time.strftime("%Y-%m-%d_%H-%M-%S"))
     content.gsub!('not_available', 'unknown revision')
   File.open(target, "w+"){ |f| f.write(content)}
   }
end

# Always, we will stamp in the PROJECT config information that notes a kind of
# configuration or build option for the software. For more information see
# the PROJECT config information concept.
# This information is always put in the automated version information file
# and will be none as default. The application can use or ignore it.
# It origin is in the smart project, where we build either crawler or smart
# and uses this CONFIG that the application use to termine and reveal if
# is a crawler or normal smart system. It can also be used for TI projects
# where building a bootloader or non-bootloader version sometimes.
# The template will contain "none" and if the environemnt variable
# PROJECT_CONFIG is available it will be replaced with it's content.
puts "Checking for PROJECT config information..."
if yc = ENV['PROJECT_CONFIG'] then #return true if env is set, but also if set and empty
  puts "Found PROJECT config information and inserting into automated version info";
  if yc.empty? then yc = "envVarEmpty" end
  File.open(target){ |source_file|
    content = source_file.read
    content.gsub!('none', yc)
  File.open(target, "w+"){ |f| f.write(content)}
  }
else
  puts "No PROJECT config information found in env. var. PROJECT_CONFIG, so not using it"
end
