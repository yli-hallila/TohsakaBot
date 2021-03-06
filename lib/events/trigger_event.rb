module TohsakaBot
  module Events
    module TriggerEvent
      extend Discordrb::EventContainer
      rate_limiter = Discordrb::Commands::SimpleRateLimiter.new

      message(containing: TohsakaBot.trigger_data.active_triggers) do |event|
        # Private messages disabled
        next if event.channel.pm?

        # Posts the trigger at 100% probability if bot is also mentioned in the message.
        sure_trigger = false
        mentions = event.message.mentions
        mentions.each { |user| if user.current_bot? then sure_trigger = true end }

        if sure_trigger
          rate_limiter.bucket :sure_triggers, delay: 60
          sure_trigger = false if rate_limiter.rate_limited?(:sure_triggers, event.author)
        end

        server_triggers = TohsakaBot.trigger_data.triggers.where(:server_id => event.server.id.to_i)
        matching_triggers = []

        server_triggers.each do |t|
          phrase = t[:phrase]
          mode = t[:mode].to_i
          msg = event.content.gsub("<@!#{AUTH.cli_id}>", "").strip

          if mode == 0
            phrase = /^#{phrase}$/i
            regex = Regexp.new phrase
          elsif mode == 1
            phrase = /.*\b#{phrase}\b.*/i
            regex = Regexp.new phrase
          else
            regex = phrase.to_regexp
          end

          if regex.match?(msg)
            matching_triggers << t
          end
        end

        # No matching triggers
        next if matching_triggers.empty?

        chosen_trigger = matching_triggers.sample

        if sure_trigger
          picked = true
        else
          chance = chosen_trigger[:chance].to_i
          default_chance = CFG.default_trigger_chance.to_i
          c = chance == 0 ? default_chance : chance

          # Three times the default chance if Exact mode.
          c *= 3 if chance == default_chance && mode == 0

          pickup = Pickup.new({true => c, false => 100 - c})
          picked = pickup.pick(1)
        end

        # Doesn't send reply if the probability wasn't hit.
        next unless picked

        file = chosen_trigger[:file]
        if file.to_s.empty?
          reply = event.respond chosen_trigger[:reply]
        else
          reply = event.channel.send_file(File.open("data/triggers/#{file}"))
        end

        # A way to remove the trigger response.
        # Only the one, whose message got triggered, is able to delete the response.
        # Threading is needed here as otherwise the await! would block any other triggers.
        Thread.new do
          response = event.message.await!(timeout: 10)
          if response
            if CFG.del_trigger.include? response.content
              reply.delete
              response.message.delete
            end
          end
        end
      end
    end
  end
end
