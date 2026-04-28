module CrystalDiceware
  # Une wordlist Diceware : un tableau ordonné de N mots, où N est
  # une puissance de 6 (1296 = 6^4 ou 7776 = 6^5).
  #
  # Les listes sont **embarquées dans le binaire** via les chaînes
  # constantes ci-dessous (générées à la compilation par
  # `read_file` — pattern hérité de `crystal-flags`).
  #
  # Ne pas charger de wordlist depuis un fichier externe à
  # l'exécution : c'est une décision de sécurité de la chaîne
  # d'approvisionnement (cf. specs § « Ce que le shard ne fait
  # pas »). Pour ajouter une langue, soumettre une PR sur
  # `aloli-crystal/crystal-diceware`.
  struct Wordlist
    # Identifiant de la liste (ex. `:eff_long`, `:fr_mbelivo_5d`).
    getter id : Symbol
    # Code langue ISO 639-1 (`:en`, `:fr`, …) — utilisé pour
    # l'auto-détection via `$LANG`.
    getter language : Symbol
    # Description courte affichée par `crystal-diceware list`.
    getter description : String
    # Les mots eux-mêmes, indexés 0-based dans le même ordre que
    # `Roll#to_index`.
    getter words : Array(String)

    def initialize(@id : Symbol, @language : Symbol, @description : String, @words : Array(String))
    end

    # Nombre de mots dans la liste (1296 ou 7776).
    def size : Int32
      @words.size
    end

    # Mot correspondant à un tirage donné.
    def lookup(roll : Roll) : String
      @words[roll.to_index]
    end

    # Tire un mot uniformément avec `Random::Secure`.
    def secure_word : String
      lookup(Roll.secure)
    end

    # Renvoie la wordlist embarquée d'identifiant `id`. Lève si
    # l'identifiant n'est pas connu.
    #
    # Identifiants disponibles en v0.1 :
    # * `:eff_long` (anglais, 7776, EFF Large 2016)
    # * `:fr_mbelivo_5d` (français, 7776, mbelivo)
    def self.for(id : Symbol) : Wordlist
      EMBEDDED[id]? || raise Error.new("wordlist inconnue : #{id.inspect}. Listes disponibles : #{EMBEDDED.keys.inspect}")
    end

    # Liste les identifiants des wordlists embarquées.
    def self.identifiers : Array(Symbol)
      EMBEDDED.keys.to_a
    end

    # Liste les codes langue représentés (peut contenir des
    # doublons si plusieurs listes pour la même langue).
    def self.languages : Array(Symbol)
      EMBEDDED.values.map(&.language).uniq!
    end

    # Choisit une wordlist par défaut adaptée à la locale système.
    # Lit `$LANG` ; tombe sur `:eff_long` (anglais) en l'absence
    # de match.
    def self.default : Wordlist
      lang = ENV["LANG"]?.try(&.split('.').first.try(&.split('_').first))
      case lang
      when "fr" then self.for(:fr_mbelivo_5d)
      else           self.for(:eff_long)
      end
    end

    # ─── Embarquement des wordlists ────────────────────────────
    # Les fichiers sont au format Diceware standard : une ligne
    # par mot, `<roll>\t<word>` (EFF) ou `<roll> <word>` (mbelivo).
    # Le séparateur est détecté à la volée. Les fichiers sont triés
    # par roll croissant ; on indexe 0..7775 dans cet ordre.

    private def self.parse_text(raw : String) : Array(String)
      words = Array(String).new(8000)
      raw.each_line do |line|
        line = line.strip
        next if line.empty?
        # Sépare sur le premier whitespace (tab ou espace)
        i = line.index(/\s/)
        next unless i
        word = line[(i + 1)..].strip
        words << word unless word.empty?
      end
      words
    end

    EFF_LONG_TEXT      = {{ read_file("#{__DIR__}/../../data/eff_long.txt") }}
    FR_MBELIVO_5D_TEXT = {{ read_file("#{__DIR__}/../../data/fr_mbelivo_5d.txt") }}

    EMBEDDED = {
      :eff_long => Wordlist.new(
        :eff_long,
        :en,
        "EFF Large Wordlist (2016) — anglais, 7776 mots",
        parse_text(EFF_LONG_TEXT),
      ),
      :fr_mbelivo_5d => Wordlist.new(
        :fr_mbelivo_5d,
        :fr,
        "mbelivo/diceware-wordlists-fr — français, 7776 mots",
        parse_text(FR_MBELIVO_5D_TEXT),
      ),
    } of Symbol => Wordlist
  end
end
