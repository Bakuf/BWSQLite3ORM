#
# Be sure to run `pod lib lint BWSQlite3ORM.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BWSQlite3ORM'
  s.version          = '0.2.0'
  s.summary          = 'Simple object-relational mapping set of classes for SQLite3.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  Simple object-relational mapping set of classes for SQLite3, just make a data model and make it subclass of BWDataModel class, and a table will be created automatically, you can use the CRUD methods to manipulate the info.
                       DESC

  s.homepage         = 'https://github.com/Bakuf/BWSQLite3ORM'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Rodrigo Galvez' => 'bakuf3@hotmail.com' }
  s.source           = { :git => 'https://github.com/Bakuf/BWSQLite3ORM.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'BWSQlite3ORM/Classes/**/*'
  
  # s.resource_bundles = {
  #   'BWSQlite3ORM' => ['BWSQlite3ORM/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
