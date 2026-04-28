require "./spec_helper"

# Tests d'uniformité statistique du tirage `Random::Secure`.
#
# Lents (plusieurs secondes), exclus du run par défaut.
# Lancer explicitement :
#   crystal spec --tag statistical
#
# Pertinents en CI nightly pour détecter une régression du PRNG OS
# ou un bug de discrétisation dans `Roll.secure`.
describe "uniformité du tirage" do
  it "chi² de la distribution des digits par position", tags: %w[statistical] do
    n = 1_000_000
    counts = Array(Array(Int32)).new(5) { Array.new(7, 0) } # 1..6 (idx 1..6)

    n.times do
      r = CrystalDiceware::Roll.secure
      r.digits.each_with_index do |d, pos|
        counts[pos][d] += 1
      end
    end

    expected = n / 6.0
    5.times do |pos|
      chi_sq = 0.0
      (1..6).each do |d|
        diff = counts[pos][d] - expected
        chi_sq += diff * diff / expected
      end
      # 5 degrés de liberté, p > 0.001 → χ² < ~20.5
      chi_sq.should be < 25.0
    end
  end

  it "distribution des mots dans une wordlist", tags: %w[statistical] do
    list = CrystalDiceware::Wordlist.for(:eff_long)
    n = 1_000_000
    counts = Array.new(list.size, 0)

    n.times do
      counts[CrystalDiceware::Roll.secure.to_index] += 1
    end

    expected = n / list.size.to_f
    # Écart-type d'une multinomiale à 7776 cellules : √(n × p × (1-p))
    # ≈ √(1_000_000 × 1/7776 × 7775/7776) ≈ √128.6 ≈ 11.3
    # On accepte ±10 σ pour être tolérant.
    counts.each do |c|
      (c.to_f - expected).abs.should be < 113.0
    end
  end
end
