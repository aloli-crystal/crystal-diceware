require "option_parser"
require "./crystal_diceware"

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
      generate (g)       Génère une passphrase Diceware
      roll     (r)       Tire les jets sans lookup (audit, debug)
      lookup   (lk) JET  Mot correspondant à un tirage
      list     (ls)      Liste les wordlists embarquées
      version  (v)       Affiche la version
      help     (h)       Affiche cette aide

    Options communes :
    BANNER

  p.on("-n WORDS", "--words=WORDS", "Nombre de mots (défaut : 7)") { |v| words = v.to_i }
  p.on("-l ID", "--language=ID", "Wordlist : eff_long | fr_mbelivo_5d (défaut : auto via $LANG)") do |v|
    wordlist_id = v.to_s_symbol
  end
  p.on("--dice=LIST", "Mode manuel : jets séparés par virgules (ex: 13456,41522,...)") do |v|
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

# Routing des sous-commandes (avec alias courts)
subcommand =
  if positional.empty?
    "generate"
  else
    case positional.first
    when "g", "generate" then positional = positional[1..]; "generate"
    when "r", "roll"     then positional = positional[1..]; "roll"
    when "lk", "lookup"  then positional = positional[1..]; "lookup"
    when "ls", "list"    then positional = positional[1..]; "list"
    when "v", "version"  then positional = positional[1..]; "version"
    when "h", "help"     then positional = positional[1..]; "help"
    else                      "generate"
    end
  end

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
  when "version"
    puts "crystal-diceware #{Diceware::VERSION}"
  when "help"
    puts parser
  end
rescue ex : Diceware::Error
  STDERR.puts "Erreur : #{ex.message}"
  exit 1
end
