require "./crystal_diceware/version"
require "./crystal_diceware/roll"
require "./crystal_diceware/wordlist"

# Crystal Diceware — générateur de passphrases Diceware.
#
# Diceware (Arnold Reinhold, 1995) génère des passphrases
# mémorables à entropie mesurable :
#
# 1. On lance N fois 5 dés à 6 faces ;
# 2. Chaque tirage `1 3 4 5 6` indexe un mot dans une wordlist de
#    7776 (= 6^5) entrées ;
# 3. La concaténation des N mots forme la passphrase.
#
# Avec N=7, l'entropie est de 7 × log₂(7776) ≈ 90 bits — niveau
# standard 2026 pour une passphrase humaine de longue durée.
#
# ## API
#
# Cas le plus simple :
#
# ```
# require "crystal-diceware"
# phrase = CrystalDiceware.generate(words: 7)
# # => "abacus pinacle catalpa serment grenouille ablation luminaire"
# ```
#
# Choix explicite de la liste :
#
# ```
# CrystalDiceware.generate(words: 7, language: :fr_mbelivo_5d)
# CrystalDiceware.entropy(words: 7, wordlist: :fr_mbelivo_5d)
# # => 90.47
# ```
#
# Tirage manuel à partir de dés physiques :
#
# ```
# rolls = ["13456", "41522", "26611", "55432", "33214", "11111", "62524"]
# CrystalDiceware.generate(words: 7, source: :manual, rolls: rolls)
# ```
#
# ## Sources d'aléa
#
# * `:auto`   — `Random::Secure` (`/dev/urandom`). Défaut.
# * `:manual` — l'utilisateur fournit ses jets en `rolls:`.
# * `:hybrid` — K mots `:auto` + (N-K) mots `:manual`. Compromis
#               quand on ne fait pas pleinement confiance au PRNG
#               sans pour autant lancer 35 dés à la main.
module CrystalDiceware
  # Sépare les mots dans la passphrase produite par `#generate`.
  DEFAULT_SEPARATOR = " "

  # Génère une passphrase Diceware.
  #
  # * `words`     — nombre de mots tirés (entropie ≈ words × 12.92 bits)
  # * `language`  — id de la liste (`:eff_long`, `:fr_mbelivo_5d`…) ou `nil`
  #                 pour auto-détection via `$LANG`
  # * `source`    — `:auto` (défaut) | `:manual` | `:hybrid`
  # * `rolls`     — pour `:manual` ou `:hybrid` : liste de chaînes
  #                 `"13456"` (ordre d'apparition dans la passphrase)
  # * `auto_words`— pour `:hybrid` : combien des `words` premiers
  #                 mots sont générés en `:auto` (les autres en
  #                 `:manual` à partir de `rolls`)
  # * `separator` — chaîne entre les mots (défaut : un espace)
  def self.generate(
    words : Int32,
    language : Symbol? = nil,
    source : Symbol = :auto,
    rolls : Array(String)? = nil,
    auto_words : Int32 = 0,
    separator : String = DEFAULT_SEPARATOR,
  ) : String
    raise Error.new("words doit être > 0 (reçu #{words})") if words <= 0

    list = language ? Wordlist.for(language) : Wordlist.default
    selected = roll(words, source: source, rolls: rolls, auto_words: auto_words)
    selected.map { |r| list.lookup(r) }.join(separator)
  end

  # Tire `words` Roll selon `source`. Retourne un tableau de Roll
  # (utile pour audit, tests, mode `roll` du CLI qui n'affiche
  # que les jets sans lookup).
  def self.roll(
    words : Int32,
    source : Symbol = :auto,
    rolls : Array(String)? = nil,
    auto_words : Int32 = 0,
  ) : Array(Roll)
    raise Error.new("words doit être > 0 (reçu #{words})") if words <= 0

    case source
    when :auto
      Array(Roll).new(words) { Roll.secure }
    when :manual
      manual_rolls = rolls
      raise Error.new("source :manual nécessite `rolls:` (Array(String))") unless manual_rolls
      if manual_rolls.size != words
        raise Error.new("source :manual : `rolls` doit avoir #{words} éléments, reçu #{manual_rolls.size}")
      end
      manual_rolls.map { |s| Roll.from_string(s) }
    when :hybrid
      manual_rolls = rolls
      manual_count = words - auto_words
      raise Error.new("source :hybrid : auto_words doit être dans [0, #{words}], reçu #{auto_words}") if auto_words < 0 || auto_words > words
      raise Error.new("source :hybrid nécessite `rolls:` avec #{manual_count} éléments") unless manual_rolls && manual_rolls.size == manual_count

      result = Array(Roll).new(words)
      auto_words.times { result << Roll.secure }
      manual_rolls.each { |s| result << Roll.from_string(s) }
      result
    else
      raise Error.new("source inconnue : #{source.inspect}. Attendu :auto, :manual ou :hybrid")
    end
  end

  # Calcule l'entropie en bits d'une passphrase Diceware de
  # `words` mots tirés uniformément dans une liste de taille N.
  #
  # H = words × log₂(N)
  #
  # Pour N = 7776 et words = 7 → ~90.47 bits.
  def self.entropy(words : Int32, wordlist : Symbol) : Float64
    list = Wordlist.for(wordlist)
    words.to_f * Math.log2(list.size.to_f)
  end

  # :ditto:
  def self.entropy(words : Int32, list : Wordlist) : Float64
    words.to_f * Math.log2(list.size.to_f)
  end
end
