#!/usr/bin/env ruby
require 'rubydns'



INTERFACES = [[:udp, "127.0.0.1", 5354]]

R = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53]])

RubyDNS::run_server(:listen => INTERFACES) do
  Name = Resolv::DNS::Name
  IN = Resolv::DNS::Resource::IN

  match(/.*.google.com$/, IN::A) do |transaction|
    original_name = transaction.question.to_s
    front = Resolv::DNS::Name.create(original_name.gsub(/.google.com$/, ""))

    transaction.passthrough!(R, :name => front) do |reply|
      logger.info reply.inspect
      logger.info reply.answer.inspect
      reply.answer[0][0] = Resolv::DNS::Name.create(original_name)
      reply.question[0][0] = Resolv::DNS::Name.create(original_name)
      #logger.info reply.answer.inspect
    end
  end
end

