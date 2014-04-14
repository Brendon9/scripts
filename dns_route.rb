#!/usr/bin/env ruby
require 'rubydns'
require 'yaml'

CONFIG = YAML::load_file(File.join(__dir__, 'dns_route.yml'))

#puts CONFIG['domains'].inspect

INTERFACES = CONFIG['interface']
RESOLVERS = CONFIG['resolvers']
DOMAINS = CONFIG['domains']

module URIHelper
  def self.build(name, domain, match)
    phone_number = name.gsub(match, "")
    new_name = check_country_code(phone_number) << domain
    return Resolv::DNS::Name.create(new_name)
  end

  def self.check_country_code(phone_number)
    phone_number.gsub!(".", "")
    if phone_number.length == 10
      phone_number << "1"
    end
    return new_phone_number = phone_number.split("").join(".")
  end

  def self.configure(phone_number)
    new_phone_number = phone_number.split("").join(".").reverse
  end
end

RubyDNS::run_server(:listen => INTERFACES) do
  Name = Resolv::DNS::Name
  IN = Resolv::DNS::Resource::IN

  match(/.*.icehook.com$/) do |transaction|
    original_name = transaction.question.to_s
    new_name = URIHelper.build(original_name, DOMAINS[:org], /.icehook.com$/)

    transaction.passthrough!(RESOLVERS[0], :name => new_name) do |reply|
      reply.answer[0][0] = Resolv::DNS::Name.create(original_name)
      reply.question[0][0] = Resolv::DNS::Name.create(original_name)
    end
  end

  match(/.*.telaris$/) do |transaction|
    original_name = transaction.question.to_s
    new_name = URIHelper.build(original_name, DOMAINS[:arpa], /.telaris$/)

    transaction.passthrough!(RESOLVERS[1], :name => new_name) do |reply|
      reply.answer[0][0] = Resolv::DNS::Name.create(original_name) unless reply.answer.empty?
      reply.question[0][0] = Resolv::DNS::Name.create(original_name) unless reply.question.empty?
    end
  end

  match(/.*.unified$/) do |transaction|
    replies = []
    names = []
    original_name = transaction.question.to_s
    names << URIHelper.build(original_name, DOMAINS[:org], /.unified$/)
    names << URIHelper.build(original_name, DOMAINS[:arpa], /.unified$/)

    #logger.info "Names Array: #{names.inspect}"

    names.each_index do |index|
      transaction.passthrough!(RESOLVERS[index], :name => names[index]) do |reply|
        replies << Resolv::DNS::Name.create(original_name)
        reply.answer[0][0] = replies[index] unless reply.answer.empty?
        reply.question[0][0] = replies[index] unless reply.question.empty?
        #logger.info "Reply: #{reply.inspect}"
      end
    end
    #logger.info "Replies Array: #{replies.inspect}"
  end
end

