#!/usr/bin/env ruby
# encoding: UTF-8

require 'instagram'
require 'json'
require 'socket'
require 'open-uri'

Dir[File.expand_path('../lib/*.rb', __FILE__)].each do |file|
	require file
end
PATH = File.dirname(__FILE__);
$clients = []

puts "\n<#>     Welcome to InstaGrow     <#>\n\n"

print "Loading config...\t\t"
begin
	$config = JSON.parse( File.read(PATH+"/config.json"), {:symbolize_names => true} )
	puts "done"
rescue Exception => e
	puts "failed"
	puts "-> The config file 'config.json' is not valid JSON."
	puts "-> Please fix it. If you cant see the error google for JSON validator"
	exit
end

print "Loading temporary files...\t"
if File.exists? PATH+"/tmp.json"
	begin
		$tmp = JSON.parse( File.read(PATH+"/tmp.json"), {:symbolize_names => true} )
		puts "done"
	rescue Exception => e
		puts "failed"
		puts "-> The config file 'tmp.json' is not valid JSON."
		puts "-> Please fix it or remove it to create a new one."
		exit
	end
else
	puts "failed"
	puts "-> File 'tmp.json' does not exist. creating it."
	$tmp = {:clients => {}, :follower => [], :follows => [], :liked => [], :history => [] }
	File.open(PATH+"/tmp.json", "w"){ |f| f.write($tmp.to_json) }
end

puts "\n---    done loading depencies    ---\n\n"

puts "TAGS:\t\t#{$config[:tags].size} found, #{$config[:tags].uniq.size} unique"
puts "CLIENTS:\t#{$config[:clients].size} found"
puts "OPTIONS:"
$config[:general].each do |key,val|
	if key.size < 8
		puts "\t#{key}\t\t\t#{val}"
	else
		puts "\t#{key}\t\t#{val}"
	end
end

puts "\nChecking for auth token...\n"
$config[:clients].each do |client|
	if $tmp[:clients][client[:client_id].to_sym].nil?
		puts "#{client[:client_id][0,18]}...\t\tfailed"
		srv = InstaGrow::TokenServer.new(
			$config[:general][:hostname], 
			$config[:general][:port],
			client[:client_id],
			client[:client_secret])
		if !srv.code.nil?
			$tmp[:clients][client[:client_id].to_sym] = { :code => srv.code }
			puts "-> successfully registered #{client[:client_id][0,18]}"
		else
			puts "-> nope. that did not work..."
		end
	else
		puts "#{client[:client_id][0,18]}...\t\tok"
	end
	if !$tmp[:clients][client[:client_id].to_sym].nil?
		if $tmp[:clients][client[:client_id].to_sym][:token].nil?
			$tmp[:clients][client[:client_id].to_sym][:token] = Instagram.get_access_token($tmp[:clients][client[:client_id].to_sym][:code], {
				:client_id => client[:client_id],
				:redirect_uri => "http://#{$config[:general][:hostname]}:#{$config[:general][:port]}/callback/",
				:client_secret => client[:client_secret]
			}).access_token
		end
		$clients << {
			:access_token => $tmp[:clients][client[:client_id].to_sym][:token],
			:client_id => client[:client_id],
			:client_secret => client[:client_secret]}
	end
end

puts ""

(print "-> Error: no valid clients found"; exit) if $clients.size < 1

puts "-> The next steps make take a while"
print "Sync follower\t\t\t"
#InstaGrow::Sync.sync_follower Instagram.client($clients[2])
puts "done"

print "Sync follows\t\t\t"
#InstaGrow::Sync.sync_follows Instagram.client($clients[2])
puts "done"

print "Saving 'tmp.json'...\t\t"
File.open(PATH+"/tmp.json", "w"){ |f| f.write($tmp.to_json) }
puts "ok"

puts "\n---       account details        ---\n\n"

puts "FOLLOWER\t\t\t#{$tmp[:follower].size}"
puts "FOLLOWS\t\t\t\t#{$tmp[:follows].size}"
you = 0; they = 0; do_not_follow_back = []
$tmp[:follows].each do |usr|
	if $tmp[:follower].include? usr
		you += 1
	else
		do_not_follow_back << usr
	end
end
$tmp[:follower].each do |usr|
	they += 1 if $tmp[:follows].include? usr
end
puts ""
puts "People you follow that:"
puts "\tfollow you:\t\t#{you}"
puts "\tdont follow you:\t#{$tmp[:follows].size-you}"
puts "People that follow you that:"
puts "\tyou follow:\t\t#{they}"
puts "\tyou dont follow:\t#{$tmp[:follower].size-they}"

puts "\n---          wörk wörk           ---\n\n"

current_client = 4
while true
	tag = $config[:tags][rand($config[:tags].size)]
	puts "[#{current_client}] tag ##{tag}"

	client = Instagram.client($clients[current_client])
	items = client.tag_recent_media(tag, {:count => 50})

	sec = 0
	while true
		
			if $config[:general][:follow_people]
				items.each do |item|
					if !($tmp[:follows] + $tmp[:liked]).include? item.user.username
						puts "- follow: #{item.user.username}"
						$tmp[:follows] << item.user.username
						$tmp[:history] << { :liked => item.user.username, :time => Time.now.to_s }
						client.follow_user item.user.id
						sleep rand(10)/40
						if !$config[:general][:like_images] and $config[:general][:like_and_follow]
							client.like_media item.id
							sleep rand(10)/40
						end
					end
				end
			end
			sleep rand(10)/3

			puts "-> new page"
			cursor = items.pagination.next_cursor
			items = client.tag_recent_media(tag, {:count => 50, :cursor => cursor})

			sec += 1
			break if sec > 50 or items.size < 1

		
	end

	sec = 0
	while true
		begin
			if $config[:general][:like_images]
				items.each do |item|
					if !($tmp[:follows] + $tmp[:liked]).include? item.user.username
						puts "- like image from: #{item.user.username}"
						$tmp[:liked] << item.user.username
						client.like_media item.id
						sleep rand(10)/30
					end
				end
			end

			sleep rand(10)/30

			puts "-> new page"
			cursor = items.pagination.next_cursor
			items = client.tag_recent_media(tag, {:count => 50, :cursor => cursor})

			sec += 1
			break if sec > 50 or items.size < 1
		rescue Exception => e
			p e.message
			break
		end
	end

	break

	current_client += 1
	current_client = 0 if current_client >= $clients.size
end
