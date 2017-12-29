module TrueSkill
  module PartialPlay
    extend self

    def partial_play_percentage(player)
      return 1.0 unless player.respond_to?(:partial_play_percentage)
      [player.partial_play_percentage.to_f, 0.0001].max
    end
  end
end