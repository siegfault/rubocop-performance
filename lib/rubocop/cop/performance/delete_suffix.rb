# frozen_string_literal: true

module RuboCop
  module Cop
    module Performance
      # In Ruby 2.5, `String#delete_suffix` has been added.
      #
      # This cop identifies places where `gsub(/suffix\z/, '')`
      # can be replaced by `delete_suffix('suffix')`.
      #
      # The `delete_suffix('suffix')` method is faster than
      # `gsub(/suffix\z/, '')`.
      #
      # @example
      #
      #   # bad
      #   str.gsub(/suffix\z/, '')
      #   str.gsub!(/suffix\z/, '')
      #   str.gsub(/suffix$/, '')
      #   str.gsub!(/suffix$/, '')
      #
      #   # good
      #   str.delete_suffix('suffix')
      #   str.delete_suffix!('suffix')
      #
      class DeleteSuffix < Cop
        extend TargetRubyVersion

        minimum_target_ruby_version 2.5

        MSG = 'Use `%<prefer>s` instead of `%<current>s`.'

        PREFERRED_METHODS = {
          gsub: :delete_suffix,
          gsub!: :delete_suffix!
        }.freeze

        def_node_matcher :gsub_method?, <<~PATTERN
          (send $!nil? ${:gsub :gsub!} (regexp (str $#literal_at_end?) (regopt)) (str $_))
        PATTERN

        def on_send(node)
          gsub_method?(node) do |_, bad_method, _, replace_string|
            return unless replace_string.blank?

            good_method = PREFERRED_METHODS[bad_method]

            message = format(MSG, current: bad_method, prefer: good_method)

            add_offense(node, location: :selector, message: message)
          end
        end

        def autocorrect(node)
          gsub_method?(node) do |receiver, bad_method, regexp_str, _|
            lambda do |corrector|
              good_method = PREFERRED_METHODS[bad_method]

              regexp_str = if regexp_str.end_with?('\\z')
                             regexp_str.chomp('\z') # drop `\z` anchor
                           else
                             regexp_str.chop # drop `$` anchor
                           end
              regexp_str = interpret_string_escapes(regexp_str)
              string_literal = to_string_literal(regexp_str)

              new_code = "#{receiver.source}.#{good_method}(#{string_literal})"

              corrector.replace(node, new_code)
            end
          end
        end

        private

        def literal_at_end?(regex_str)
          # is this regexp 'literal' in the sense of only matching literal
          # chars, rather than using metachars like `.` and `*` and so on?
          # also, is it anchored at the start of the string?
          # (tricky: \s, \d, and so on are metacharacters, but other characters
          #  escaped with a slash are just literals. LITERAL_REGEX takes all
          #  that into account.)
          regex_str =~ /\A(?:#{LITERAL_REGEX})+(\\z|\$)\z/
        end
      end
    end
  end
end
