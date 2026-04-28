require "./spec_helper"

describe CrystalDiceware::Wordlist do
  describe "embarquement" do
    it "expose :eff_long et :fr_mbelivo_5d" do
      ids = CrystalDiceware::Wordlist.identifiers
      ids.should contain(:eff_long)
      ids.should contain(:fr_mbelivo_5d)
    end

    it ".for(:nonexistent) lève une erreur" do
      expect_raises(CrystalDiceware::Error, /inconnue/) do
        CrystalDiceware::Wordlist.for(:nonexistent)
      end
    end

    it "size = 7776 pour les deux listes embarquées" do
      CrystalDiceware::Wordlist.for(:eff_long).size.should eq(7776)
      CrystalDiceware::Wordlist.for(:fr_mbelivo_5d).size.should eq(7776)
    end

    it "language = :en pour eff_long, :fr pour fr_mbelivo_5d" do
      CrystalDiceware::Wordlist.for(:eff_long).language.should eq(:en)
      CrystalDiceware::Wordlist.for(:fr_mbelivo_5d).language.should eq(:fr)
    end
  end

  describe "validations structurelles" do
    {% for id in [:eff_long, :fr_mbelivo_5d] %}
      describe "{{ id.id }}" do
        list = CrystalDiceware::Wordlist.for({{ id }})

        it "n'a aucun doublon (case-insensitive)" do
          unique = list.words.map(&.downcase).to_set
          unique.size.should eq(7776)
        end

        it "n'a que des mots de longueur ∈ [3, 9]" do
          list.words.all? { |w| 3 <= w.size <= 9 }.should be_true
        end

        it "n'a aucun caractère de contrôle, espace ou ponctuation finale" do
          list.words.each do |w|
            w.includes?(' ').should be_false
            w.includes?('\t').should be_false
            w.includes?('\n').should be_false
            w.includes?('"').should be_false
            w.includes?('\\').should be_false
          end
        end

        it "est de l'UTF-8 valide" do
          list.words.each { |w| w.valid_encoding?.should be_true }
        end
      end
    {% end %}
  end

  describe "vecteurs historiques EFF (anti-corruption)" do
    list = CrystalDiceware::Wordlist.for(:eff_long)

    it "11111 → abacus" do
      list.lookup(CrystalDiceware::Roll.from_string("11111")).should eq("abacus")
    end

    it "66666 → zoom" do
      list.lookup(CrystalDiceware::Roll.from_string("66666")).should eq("zoom")
    end

    it "vecteurs représentatifs publiés par l'EFF" do
      # Sélection de tirages connus depuis le PDF officiel EFF.
      vectors = {
        "11112" => "abdomen",
        "11113" => "abdominal",
        "11116" => "ability",
        "12345" => "arousal",
        "23456" => "dispatch",
        "34561" => "ipad",
        "45612" => "prozac",
        "56123" => "stadium",
        "61234" => "suggest",
        "66665" => "zoology",
        "66664" => "zoologist",
      }
      vectors.each do |jet, expected|
        list.lookup(CrystalDiceware::Roll.from_string(jet)).should eq(expected)
      end
    end
  end

  describe "vecteurs historiques fr_mbelivo_5d" do
    list = CrystalDiceware::Wordlist.for(:fr_mbelivo_5d)

    it "11111 → abaisse" do
      list.lookup(CrystalDiceware::Roll.from_string("11111")).should eq("abaisse")
    end

    it "66666 → zoom" do
      list.lookup(CrystalDiceware::Roll.from_string("66666")).should eq("zoom")
    end

    it "11112 → abaisser, 11113 → abandon" do
      list.lookup(CrystalDiceware::Roll.from_string("11112")).should eq("abaisser")
      list.lookup(CrystalDiceware::Roll.from_string("11113")).should eq("abandon")
    end
  end
end
