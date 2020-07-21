require_relative 'lib/trueskill'
require_relative 'simple_leaderboard'

QUALITY_STRING = <<~STRING
  ---------------------------------------------------
  Possible Match (Q: %{quality}%%)
  ---------------------------------------------------
  Winners:  %{winners}
  Losers:   %{losers}
  Winning team has %{probability}%% chance to win.
STRING

spades = 
[
  # Game 1
  [  
    ['shaun', 'ryan'],
    ['rylee', 'ruby'],
  ],
  # Game 2
  [  
    ['shaun', 'ryan'],
    ['rylee', 'ruby'],
  ],
  # Game 3
  [  
    ['rylee', 'ruby'],
    ['shaun', 'ryan'],
  ],
  # Game 4
  [  
    ['shaun', 'ryan'],
    ['rylee', 'ruby'],
  ],
  # Game 5
  [  
    ['shaun', 'ruby'],
    ['rylee', 'ryan'],
  ],
  # Game 6
  [  
    ['rylee', 'ryan'],
    ['shaun', 'ruby'],
  ],
  # Game 7
  [  
    ['shaun', 'ruby'],
    ['rylee', 'ryan'],
  ],
]

leaderboard = Leaderboard.new
spades.each_with_index do |game, index|
  leaderboard << game
end

puts("-" * 90)
puts("Current Standings".center(90))
puts("-" * 90)
leaderboard.show
puts('')


leaderboard.match_qualities.take(3).each do |possible_game|
  puts(QUALITY_STRING % {
    winners: possible_game.high_team.join(' & '),
    losers: possible_game.low_team.join(' & '),
    quality: (possible_game.quality * 100.0).round,
    probability: (possible_game.probability * 100.0).round,
  })
  puts("\n")
end