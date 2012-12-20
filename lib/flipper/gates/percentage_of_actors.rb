require 'zlib'

module Flipper
  module Gates
    class PercentageOfActors < Gate
      Key = :perc_actors

      def type_key
        Key
      end

      def open?(actor)
        percentage = toggle.value.to_i

        if percentage == 0
          false
        else
          Zlib.crc32(actor.identifier.to_s) % 100 < percentage
        end
      end

      def protects?(thing)
        thing.is_a?(Flipper::Types::PercentageOfActors)
      end
    end
  end
end
