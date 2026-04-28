require "./spec_helper"

describe Diceware do
  describe ".generate" do
    it "produit une passphrase de N mots séparés par des espaces" do
      phrase = Diceware.generate(words: 7, language: :eff_long)
      phrase.split(' ').size.should eq(7)
    end

    it "respecte le séparateur custom" do
      phrase = Diceware.generate(words: 5, language: :eff_long, separator: "-")
      phrase.split('-').size.should eq(5)
    end

    it "rejette words ≤ 0" do
      expect_raises(Diceware::Error, /words doit/) do
        Diceware.generate(words: 0)
      end
      expect_raises(Diceware::Error, /words doit/) do
        Diceware.generate(words: -3)
      end
    end

    it "mode :manual avec rolls" do
      rolls = ["11111", "11112", "66665", "66666"]
      phrase = Diceware.generate(
        words: 4, language: :eff_long, source: :manual, rolls: rolls,
      )
      phrase.should eq("abacus abdomen zoology zoom")
    end

    it "mode :manual sans rolls lève une erreur" do
      expect_raises(Diceware::Error, /nécessite/) do
        Diceware.generate(words: 3, source: :manual)
      end
    end

    it "mode :manual avec mauvais nombre de rolls lève une erreur" do
      expect_raises(Diceware::Error, /3 éléments/) do
        Diceware.generate(
          words: 3, language: :eff_long, source: :manual,
          rolls: ["11111", "22222"],
        )
      end
    end

    it "mode :hybrid combine auto et manual" do
      phrase = Diceware.generate(
        words: 5, language: :eff_long, source: :hybrid,
        auto_words: 3, rolls: ["11111", "66666"],
      )
      words = phrase.split(' ')
      words.size.should eq(5)
      words[3].should eq("abacus")
      words[4].should eq("zoom")
    end

    it "source inconnue lève une erreur" do
      expect_raises(Diceware::Error, /source inconnue/) do
        Diceware.generate(words: 3, source: :bogus)
      end
    end
  end

  describe ".roll" do
    it "produit N Roll en mode :auto" do
      rolls = Diceware.roll(words: 10, source: :auto)
      rolls.size.should eq(10)
      rolls.all? { |r| r.digits.size == 5 }.should be_true
    end

    it "convertit les chaînes en Roll en mode :manual" do
      rolls = Diceware.roll(
        words: 2, source: :manual, rolls: ["11111", "66666"],
      )
      rolls.map(&.to_s).should eq(["11111", "66666"])
    end
  end

  describe ".entropy" do
    it "= words × log₂(7776) pour une liste de 7776" do
      bits = Diceware.entropy(words: 7, wordlist: :eff_long)
      bits.should be_close(90.47, 0.01)
    end

    it "résultat double pour 14 mots" do
      bits14 = Diceware.entropy(words: 14, wordlist: :eff_long)
      bits7 = Diceware.entropy(words: 7, wordlist: :eff_long)
      bits14.should be_close(bits7 * 2, 0.0001)
    end
  end
end
