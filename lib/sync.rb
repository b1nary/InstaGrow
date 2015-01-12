module InstaGrow
	module Sync

		def self.sync_follower client
			cursor = 0
			$tmp[:follower] = []
			while true
				query = {:count => 50}
				query[:cursor] = cursor if cursor != 0
				follower = client.user_followed_by(query)
				cursor = follower.pagination.next_cursor
				follower.each do |u|
					$tmp[:follower] << u.username
				end
				sleep rand(10)/20

				break if follower.size < 50
			end
		end

		def self.sync_follows client
			cursor = 0
			$tmp[:follows] = []
			while true
				query = {:count => 50}
				query[:cursor] = cursor if cursor != 0
				follower = client.user_follows(query)
				cursor = follower.pagination.next_cursor
				follower.each do |u|
					$tmp[:follows] << u.username
				end
				sleep(rand(10)/20)

				break if cursor.nil?
			end
		end

	end
end
