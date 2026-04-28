module CrystalDiceware
  # Erreur générique du shard.
  class Error < Exception; end

  # Un tirage Diceware : 5 dés à 6 faces, chaque chiffre ∈ [1, 6].
  #
  # ```
  # roll = CrystalDiceware::Roll.from_string("13456")
  # roll.digits   # => [1, 3, 4, 5, 6]
  # roll.to_index # => 1063 (index 0-based dans une liste de 7776)
  # roll.to_s     # => "13456"
  # ```
  struct Roll
    # Nombre de dés par tirage Diceware standard (5 × 6 = 7776 mots).
    DICE = 5

    # Les 5 chiffres du tirage, dans l'ordre de lecture.
    getter digits : Array(Int32)

    def initialize(@digits : Array(Int32))
      validate!
    end

    # Parse une chaîne `"13456"` (5 chiffres ASCII 1..6).
    # Lève `CrystalDiceware::Error` si la chaîne est invalide.
    def self.from_string(s : String) : Roll
      if s.size != DICE
        raise Error.new("un tirage Diceware fait #{DICE} chiffres, reçu : #{s.inspect} (#{s.size} caractères)")
      end
      digits = s.chars.map do |ch|
        unless '1' <= ch <= '6'
          raise Error.new("chiffre invalide #{ch.inspect} dans #{s.inspect} ; un dé donne 1..6")
        end
        ch.to_i
      end
      Roll.new(digits)
    end

    # Tire un Roll uniformément avec `Random::Secure`.
    def self.secure : Roll
      digits = Array.new(DICE) { Random::Secure.rand(1..6) }
      Roll.new(digits)
    end

    # Convertit le tirage en index 0-based dans une liste de 6^5
    # = 7776 mots. Lecture : `1 3 4 5 6` est interprété comme un
    # nombre en base 6 où chaque chiffre est décalé de -1 (les dés
    # vont de 1..6, pas 0..5).
    #
    # `1 1 1 1 1` → 0
    # `6 6 6 6 6` → 7775
    def to_index : Int32
      idx = 0
      digits.each do |d|
        idx = idx * 6 + (d - 1)
      end
      idx
    end

    def to_s(io : IO) : Nil
      digits.each { |d| io << d }
    end

    # Construit le tirage correspondant à `index` 0-based dans une
    # liste de 7776 mots. Inverse de `to_index`.
    def self.from_index(index : Int32) : Roll
      raise Error.new("index hors plage [0, 7775] : #{index}") if index < 0 || index >= 7776
      digits = Array.new(DICE, 0)
      n = index
      DICE.times do |i|
        digits[DICE - 1 - i] = (n % 6) + 1
        n //= 6
      end
      Roll.new(digits)
    end

    private def validate!
      if digits.size != DICE
        raise Error.new("un tirage Diceware contient #{DICE} dés, reçu #{digits.size}")
      end
      digits.each do |d|
        unless 1 <= d <= 6
          raise Error.new("chiffre invalide #{d} ; un dé donne 1..6")
        end
      end
    end
  end
end
