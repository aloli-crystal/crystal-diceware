require "./spec_helper"

describe CrystalDiceware::Roll do
  describe ".from_string" do
    it "parse une chaîne valide de 5 chiffres 1..6" do
      r = CrystalDiceware::Roll.from_string("13456")
      r.digits.should eq([1, 3, 4, 5, 6])
      r.to_s.should eq("13456")
    end

    it "round-trip from_string ↔ to_s" do
      ["11111", "13456", "66666", "32145"].each do |s|
        CrystalDiceware::Roll.from_string(s).to_s.should eq(s)
      end
    end

    it "rejette les chaînes de mauvaise longueur" do
      expect_raises(CrystalDiceware::Error, /5 chiffres/) do
        CrystalDiceware::Roll.from_string("123")
      end
      expect_raises(CrystalDiceware::Error, /5 chiffres/) do
        CrystalDiceware::Roll.from_string("123456")
      end
    end

    it "rejette les chiffres hors plage 1..6" do
      expect_raises(CrystalDiceware::Error, /chiffre invalide/) do
        CrystalDiceware::Roll.from_string("17345")
      end
      expect_raises(CrystalDiceware::Error, /chiffre invalide/) do
        CrystalDiceware::Roll.from_string("00000")
      end
      expect_raises(CrystalDiceware::Error, /chiffre invalide/) do
        CrystalDiceware::Roll.from_string("abcde")
      end
    end
  end

  describe "#to_index / .from_index" do
    it "11111 → 0, 66666 → 7775" do
      CrystalDiceware::Roll.from_string("11111").to_index.should eq(0)
      CrystalDiceware::Roll.from_string("66666").to_index.should eq(7775)
    end

    it "round-trip from_index ↔ to_index sur tous les indices" do
      0.upto(7775) do |i|
        roll = CrystalDiceware::Roll.from_index(i)
        roll.to_index.should eq(i)
      end
    end

    it "from_index rejette les valeurs hors plage" do
      expect_raises(CrystalDiceware::Error, /hors plage/) do
        CrystalDiceware::Roll.from_index(-1)
      end
      expect_raises(CrystalDiceware::Error, /hors plage/) do
        CrystalDiceware::Roll.from_index(7776)
      end
    end
  end

  describe ".secure" do
    it "produit toujours 5 chiffres dans 1..6" do
      100.times do
        r = CrystalDiceware::Roll.secure
        r.digits.size.should eq(5)
        r.digits.all? { |d| 1 <= d <= 6 }.should be_true
      end
    end
  end
end
