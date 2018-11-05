require 'json'
require 'net/http'
require 'pathname'
require 'rainbow'
require 'rspec/core/rake_task'
require 'uri'

VAGRANT_PROVIDERS = {
  virtualbox: {
    builder_type: 'virtualbox-iso'
  },
  vmware_desktop: {
    builder_type: 'vmware-iso'
  }
}.freeze

task default: ['packer:validate', 'packer:check_iso_url']

namespace :packer do
  desc 'Validate all the packer templates'
  task :validate do
    Pathname.glob('*.json').sort.each do |template|
      puts Rainbow("Validating #{template}...").green
      unless system "packer validate #{template}"
        puts Rainbow("#{template} is not a valid packer template").red
        raise "#{template} is not a valid packer template"
      end
    end
  end

  desc 'Check if all the ISO URLs are available'
  task :check_iso_url do
    Pathname.glob('*.json').sort.each do |template|
      json = JSON.parse(template.read)
      mirror = json['variables']['mirror']
      iso_urls = json['builders'].map do |builder|
        builder['iso_url'].sub('{{user `mirror`}}', mirror)
      end
      iso_urls.uniq.each do |iso_url|
        puts Rainbow("Checking if #{iso_url} is available...").green
        request_head(iso_url) do |response|
          unless available?(response)
            puts Rainbow("#{iso_url} is not available: uri=#{response.uri}, message=#{response.message}").red
            raise "#{iso_url} is not available"
          end
        end
      end
    end
  end

end

desc 'Run serverspec tests'
RSpec::Core::RakeTask.new(:spec, :host) do |_t, args|
  ENV['HOST'] = args[:host]
end

def request_head(uri, &block)
  uri = URI(uri)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request_head(uri)
  end
  if response.is_a?(Net::HTTPRedirection)
    request_head(response['Location'], &block)
  else
    yield response
  end
end

def available?(response)
  response.is_a?(Net::HTTPSuccess)
end

