#!/usr/bin/env ruby
require 'rubydns'

# Sample input:
# 8.4.4.5.8.6.3.7.1.8.1.icehook.com
# The preceeding number 1 should be appended to the number if necessary

# Expected response:
#

INTERFACES = [[:udp, "127.0.0.1", 5354]]

RESOLVERS = [
  RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53]]),
  RubyDNS::Resolver.new([[:udp, "207.198.118.90", 53]])
]

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
    new_name = URIHelper.build(original_name, ".e164.org", /.icehook.com$/)

    transaction.passthrough!(RESOLVERS[0], :name => new_name) do |reply|
      reply.answer[0][0] = Resolv::DNS::Name.create(original_name)
      reply.question[0][0] = Resolv::DNS::Name.create(original_name)
    end
  end

  match(/.*.telaris$/) do |transaction|
    original_name = transaction.question.to_s
    new_name = URIHelper.build(original_name, ".a6928cfe-20a2-4292-9cd3-35666430765d.e164.arpa", /.telaris$/)

    logger.info "Name: #{new_name.inspect}"

    transaction.passthrough!(RESOLVERS[1], :name => new_name) do |reply|
      reply.answer[0][0] = Resolv::DNS::Name.create(original_name) unless reply.answer.empty?
      reply.question[0][0] = Resolv::DNS::Name.create(original_name) unless reply.question.empty?

      logger.info "Reply: #{reply.inspect}"
    end
  end

  match(/.*.unified$/) do |transaction|
    replies = []
    names = []
    original_name = transaction.question.to_s
    names << URIHelper.build(original_name, ".e164.org", /.unified$/)
    names << URIHelper.build(original_name, ".a6928cfe-20a2-4292-9cd3-35666430765d.e164.arpa", /.unified$/)

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

