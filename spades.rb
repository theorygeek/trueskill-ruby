require_relative 'lib/trueskill'
require_relative 'simple_leaderboard'

TEAMS = 3
PLAYERS_PER_TEAM = 1

spades = [
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
  # Game 8
  [  
    ['shaun', 'ruby'],
    ['rylee', 'ryan'],
  ],
]

leaderboard = Leaderboard.new(TrueSkill::GameInfo.new(draw_probability: 0))
spades.each_with_index do |game, index|
  leaderboard << game
end

puts("-" * 90)
puts("Current Standings".center(90))
puts("-" * 90)
leaderboard.show
puts('')

QUALITY_STRING = <<~STRING
  ---------------------------------------------------
  Possible Match (Q: %{quality}%%)
  ---------------------------------------------------
  Winners:  %{winners}
  Losers:   %{losers}
  Winning team has %{probability}%% chance to win.
STRING

possible_games = leaderboard.possible_games(players_per_team: PLAYERS_PER_TEAM, teams: TEAMS)
[possible_games[0], possible_games[-1]].compact.each do |possible_game|
  puts(QUALITY_STRING % {
    winners: possible_game.winners.join(' & '),
    losers: possible_game.losers.map { |players| players.join(' & ') }.join(', '),
    quality: (possible_game.quality * 100.0).round,
    probability: (possible_game.probability * 100.0).round,
  })
  puts("\n")
end