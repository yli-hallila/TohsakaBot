module TohsakaBot
  module Commands
    module TriggerSearch
      extend Discordrb::Commands::CommandContainer
      command(:triggersearch,
              aliases: %i[searchtrigger tsearch ts],
              description: 'Search triggers.',
              usage: "Use 'triggersearch -h|--help' for help.",
              min_args: 1,
              require_register: true,
              enabled_in_pm: false) do |event, *msg|

        options = TohsakaBot.command_parser(
            event, msg, 'Usage: triggersearch [options]', '',
            [:author, 'Creator of the trigger. Format: Discord ID or mention', :type => :string],
            [:phrase, 'Phrase from which the bot triggers.', :type => :strings],
            [:reply, 'Reply to the phrase.', :type => :strings]
        )
        break if options.nil?

        triggers = TohsakaBot.db[:triggers]
        result = triggers.where(:server_id => event.server.id.to_i).order(:id).map{ |t| t.values}.select do |t|
          phrase = t[1].to_s
          reply = t[2].to_s
          file = t[3].to_s
          discord_uid = TohsakaBot.get_discord_id(t[4]).to_i

          # If no author specified, it's ignored.
          if options.author.nil?
            opt_author = discord_uid
          elsif !Integer(options.author, exception: false)
            opt_author = options.author.gsub(/[^\d]/, '').to_i
          else
            opt_author = options.author.to_i
          end

          # Tries to match with the given string as is, if there were no proper arguments.
          if options.author.nil? && options.phrase.nil? && options.reply.nil?

            message = msg.join(' ')
            opt_phrase = message
            opt_reply = message

            # if User matches OR Phrase is included OR Reply OR File is included
            discord_uid == opt_author &&
                (phrase.include?(opt_phrase) || reply.include?(opt_reply) || file.include?(opt_reply))
          else
            opt_phrase = options.phrase.nil? ? nil : options.phrase.join(' ')
            opt_reply = options.reply.nil? ? nil : options.reply.join(' ')
            opt_phrase = opt_phrase || phrase
            opt_reply = opt_reply || reply

            # if User matches AND Phrase is included AND (Reply OR File is included)
            discord_uid == opt_author &&
                phrase.include?(opt_phrase) && (reply.include?(opt_reply) || file.include?(opt_reply))
          end
        end

        result_amount = 0
        output = "`Modes include exact (0), any (1) and regex (2).`\n`  ID | M & % | TRIGGER                           | MSG/FILE`\n"
        result.each do |t|
          id = t[0]
          phrase = t[1]
          reply = t[2]
          file = t[3]
          chance = t[6].to_i == 0 ? CFG.default_trigger_chance.to_i : t[6].to_i
          mode = t[7].to_i
          chance *= 3 if mode == 0

          if reply.nil? || reply.empty?
            output << "`#{sprintf("%4s", id)} | #{sprintf("%-5s", mode.to_s + " " + chance.to_s)} | #{sprintf("%-33s", phrase.to_s.gsub("\n", '')[0..30])} | #{sprintf("%-21s", file[0..20])}`\n"
          else
            output << "`#{sprintf("%4s", id)} | #{sprintf("%-5s", mode.to_s + " " + chance.to_s)} | #{sprintf("%-33s", phrase.to_s.gsub("\n", '')[0..30])} | #{sprintf("%-21s", reply.gsub("\n", '')[0..20])}`\n"
          end
          result_amount += 1
        end

        where = result_amount > 5 ? event.author.pm : event.channel

        if result.any?
          where.split_send "#{output}"
        else
          event.<< 'No triggers found.'
        end
      end
    end
  end
end
