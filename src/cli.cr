require "option_parser"
require "./diceware"

# crystal-diceware CLI.
#
# Sous-commandes (avec leurs alias courts) :
#   generate (g)  — génère une passphrase
#   roll     (r)  — tire des Roll sans lookup
#   lookup   (lk) — affiche le mot d'un Roll
#   list     (ls) — liste les wordlists embarquées
#   version  (v)
#   help     (h)

words = 7
wordlist_id : Symbol? = nil
source = :auto
auto_words = 0
dice_str : String? = nil
show_entropy = false
separator = " "

parser = OptionParser.new do |p|
  p.banner = <<-BANNER
    Usage : crystal-diceware SOUS-COMMANDE [options]

    Sous-commandes :
      generate (g)        Génère une passphrase Diceware
      roll     (r)        Tire les jets sans lookup (audit, debug)
      lookup   (lk) JET   Mot correspondant à un tirage
      list     (ls)       Liste les wordlists embarquées
      help     (h) [CMD]  Aide détaillée d'une sous-commande

    Pour la doc complète d'une sous-commande :
      crystal-diceware help generate
      crystal-diceware h roll

    Options :
    BANNER

  p.on("-n WORDS", "--words=WORDS", "Nombre de mots (défaut : 7)") { |v| words = v.to_i }
  p.on("-l ID", "--language=ID", "Wordlist : eff_long | fr_mbelivo_5d (défaut : auto via $LANG)") do |v|
    wordlist_id = v.to_s_symbol
  end
  p.on("-D LIST", "--dice=LIST", "Mode manuel : jets séparés par virgules (ex: 13456,41522,...)") do |v|
    dice_str = v
    source = :manual
  end
  p.on("-k N", "--auto-words=N", "Mode hybride : N premiers mots automatiques, le reste via --dice") do |v|
    auto_words = v.to_i
    source = :hybrid
  end
  p.on("-s SEP", "--separator=SEP", "Séparateur entre les mots (défaut : un espace)") { |v| separator = v }
  p.on("-e", "--entropy", "Affiche l'entropie en bits sous la passphrase") { show_entropy = true }
  p.on("-v", "--version", "Affiche la version") do
    puts "crystal-diceware #{Diceware::VERSION}"
    exit 0
  end
  p.on("-h", "--help", "Affiche cette aide") do
    puts p
    exit 0
  end

  p.invalid_option do |flag|
    STDERR.puts "Option inconnue : #{flag}"
    STDERR.puts p
    exit 1
  end
end

# Crystal n'a pas `String#to_s_symbol` — petit helper inline.
class String
  def to_s_symbol : Symbol
    {% begin %}
      case self
      when "eff_long"      then :eff_long
      when "fr_mbelivo_5d" then :fr_mbelivo_5d
      when "en"            then :en
      when "fr"            then :fr
      else                      raise Diceware::Error.new("identifiant inconnu : #{self.inspect}")
      end
    {% end %}
  end
end

positional = [] of String
parser.unknown_args { |args| positional = args }
parser.parse(ARGV)

# Routing des sous-commandes (avec alias courts).
# `version` n'est PAS une sous-commande : on utilise le drapeau
# Unix standard `-v` / `--version`. En revanche `help` est gardé
# en sous-commande (en plus de `-h` / `--help`) parce qu'il
# accepte un argument optionnel `help SUBCMD` qui affiche la doc
# détaillée d'une sous-commande spécifique (style `git help`).
subcommand =
  if positional.empty?
    "generate"
  else
    case positional.first
    when "g", "generate" then positional = positional[1..]; "generate"
    when "r", "roll"     then positional = positional[1..]; "roll"
    when "lk", "lookup"  then positional = positional[1..]; "lookup"
    when "ls", "list"    then positional = positional[1..]; "list"
    when "h", "help"     then positional = positional[1..]; "help"
    else                      "generate"
    end
  end

# Doc détaillée par sous-commande (affichée par `help SUBCMD`).
HELP_TEXTS = {
  "generate" => <<-DOC,
    NAME
      crystal-diceware generate — génère une passphrase Diceware

    USAGE
      crystal-diceware generate [options]
      crystal-diceware g [options]

    OPTIONS
      -n WORDS, --words=WORDS         Nombre de mots (défaut : 7)
      -l ID, --language=ID            Wordlist (eff_long | fr_mbelivo_5d
                                      ou auto via $LANG)
      -D LIST, --dice=LIST            Mode manuel : jets séparés par
                                      virgules (ex: 13456,41522,...)
      -k N, --auto-words=N            Mode hybride : N premiers mots
                                      en auto, le reste dans --dice
      -s SEP, --separator=SEP         Séparateur entre mots (défaut : espace)
      -e, --entropy                   Affiche aussi l'entropie en bits

    EXEMPLES
      # Génère 7 mots, langue auto-détectée via $LANG
      crystal-diceware generate -n 7

      # 7 mots, wordlist française explicite, avec entropie
      crystal-diceware g -n 7 -l fr_mbelivo_5d -e

      # Mode manuel — vous lancez vos dés physiques et tapez les jets
      crystal-diceware g -n 3 -D 13456,41522,26611

      # Mode hybride — 4 mots auto + 3 mots manuels
      crystal-diceware g -n 7 -k 4 -D 13456,41522,26611

      # Séparateur custom (utile pour copier-coller dans un site
      # qui n'accepte pas l'espace)
      crystal-diceware g -n 7 -s "-"

    DOC
  "roll" => <<-DOC,
    NAME
      crystal-diceware roll — tire des jets bruts sans lookup

    USAGE
      crystal-diceware roll [options]
      crystal-diceware r [options]

    DESCRIPTION
      Affiche `words` jets de 5 dés sous forme de chaînes de
      5 chiffres (un jet par ligne). Utile pour :

      * audit du PRNG (`--source :auto` par défaut)
      * debug — voir les tirages sans le lookup vers la wordlist
      * pré-calcul — capturer les jets avant un éventuel
        replay avec `lookup`

    OPTIONS
      -n WORDS, --words=WORDS         Nombre de jets (défaut : 7)
      -D LIST, --dice=LIST            Mode :manual (renvoie les
                                      jets validés)
      -k N, --auto-words=N            Mode :hybrid

    EXEMPLES
      crystal-diceware roll -n 7
      # 23456
      # 41522
      # ...

    DOC
  "lookup" => <<-DOC,
    NAME
      crystal-diceware lookup — mot correspondant à un jet

    USAGE
      crystal-diceware lookup JET [JET2 ...] [options]
      crystal-diceware lk JET [JET2 ...] [options]

    DESCRIPTION
      Convertit un ou plusieurs jets de 5 chiffres en mots de la
      wordlist choisie. Inverse de `roll`.

    OPTIONS
      -l ID, --language=ID            Wordlist à consulter

    EXEMPLES
      crystal-diceware lookup 11111 -l eff_long
      # abacus

      crystal-diceware lk 11111 66666 -l eff_long
      # abacus
      # zoom

    DOC
  "list" => <<-DOC,
    NAME
      crystal-diceware list — liste les wordlists embarquées

    USAGE
      crystal-diceware list
      crystal-diceware ls

    EXEMPLE
      $ crystal-diceware list
        eff_long            en   7776   EFF Large Wordlist (2016) — anglais
        fr_mbelivo_5d       fr   7776   mbelivo/diceware-wordlists-fr — français

    DOC
  "help" => <<-DOC,
    NAME
      crystal-diceware help — aide détaillée d'une sous-commande

    USAGE
      crystal-diceware help [SOUS-COMMANDE]
      crystal-diceware h [SOUS-COMMANDE]

    DESCRIPTION
      Sans argument, affiche le résumé général (équivalent de
      `--help`). Avec un argument, affiche la documentation
      détaillée de la sous-commande, avec exemples.

    EXEMPLES
      crystal-diceware help              # résumé général
      crystal-diceware help generate     # doc détaillée
      crystal-diceware h roll            # idem, alias court

    DOC
} of String => String

def resolve_rolls(dice_str : String?) : Array(String)?
  dice_str.try(&.split(',').map(&.strip))
end

begin
  case subcommand
  when "generate"
    rolls = resolve_rolls(dice_str)
    phrase = Diceware.generate(
      words: words,
      language: wordlist_id,
      source: source,
      rolls: rolls,
      auto_words: auto_words,
      separator: separator,
    )
    puts phrase
    if show_entropy
      list = (id = wordlist_id) ? Diceware::Wordlist.for(id) : Diceware::Wordlist.default
      bits = Diceware.entropy(words: words, list: list)
      printf("Entropie : %.2f bits (#{words} mots × log₂(#{list.size}))\n", bits)
    end
  when "roll"
    rolls = resolve_rolls(dice_str)
    selected = Diceware.roll(
      words: words,
      source: source,
      rolls: rolls,
      auto_words: auto_words,
    )
    selected.each { |r| puts r.to_s }
  when "lookup"
    if positional.empty?
      STDERR.puts "Usage : crystal-diceware lookup JET [-l ID]"
      exit 1
    end
    list = (id = wordlist_id) ? Diceware::Wordlist.for(id) : Diceware::Wordlist.default
    positional.each do |jet|
      puts list.lookup(Diceware::Roll.from_string(jet))
    end
  when "list"
    Diceware::Wordlist.identifiers.each do |list_id|
      list = Diceware::Wordlist.for(list_id)
      printf("  %-18s  %-3s  %-5d  %s\n", list.id, list.language, list.size, list.description)
    end
  when "help"
    if positional.empty?
      # `help` sans argument → résumé général (comme `--help`).
      puts parser
    else
      target = positional.first
      # Résolution des alias courts.
      target = case target
               when "g"  then "generate"
               when "r"  then "roll"
               when "lk" then "lookup"
               when "ls" then "list"
               when "h"  then "help"
               else           target
               end
      if doc = HELP_TEXTS[target]?
        puts doc
      else
        STDERR.puts "Sous-commande inconnue : #{positional.first}"
        STDERR.puts "Sous-commandes disponibles : #{HELP_TEXTS.keys.join(", ")}"
        exit 1
      end
    end
  end
rescue ex : Diceware::Error
  STDERR.puts "Erreur : #{ex.message}"
  exit 1
end
