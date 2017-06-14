require 'zip'
require 'plist'

module FastlaneCore
  class IpaFileAnalyser
    # Fetches the app identifier (e.g. com.facebook.Facebook) from the given ipa file.
    def self.fetch_app_identifier(path)
      path = File.expand_path(path)
      plist = self.fetch_info_plist_file(path)
      return plist['CFBundleIdentifier'] if plist
      return nil
    end

    # Fetches the app version from the given ipa file.
    def self.fetch_app_version(path)
      path = File.expand_path(path)
      plist = self.fetch_info_plist_file(path)
      return plist['CFBundleShortVersionString'] if plist
      return nil
    end

    # Fetches the app platform from the given ipa file.
    def self.fetch_app_platform(path)
      path = File.expand_path(path)
      plist = self.fetch_info_plist_file(path)
      platform = "ios"
      platform = plist['DTPlatformName'] if plist
      platform = "ios" if platform == "iphoneos" # via https://github.com/fastlane/spaceship/issues/247
      return platform
    end

    def self.fetch_info_plist_file(path)
      path = File.expand_path(path)
      UI.user_error!("Could not find file at path '#{path}'") unless File.exist?(path)
      Zip::File.open(path, "rb") do |zipfile|
        file = zipfile.glob('**/Payload/*.app/Info.plist').first
        return nil unless file

        # Creates a temporary directory with a unique name tagged with 'fastlane'
        # The directory is deleted automatically at the end of the block
        Dir.mktmpdir("fastlane") do |tmp|
          # The XML file has to be properly unpacked first
          tmp_path = File.join(tmp, "Info.plist")
          File.open(tmp_path, 'wb') do |output|
            output.write zipfile.read(file)
          end
          system("plutil -convert xml1 #{tmp_path}")
          result = Plist.parse_xml(tmp_path)

          if result['CFBundleIdentifier'] or result['CFBundleVersion']
            return result
          end
        end
      end

      return nil
    end
  end
end
