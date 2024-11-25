class GreekMonth
  GENITIVE_FORMS = %w[
    Ιανουαρίου Φεβρουαρίου Μαρτίου Απριλίου Μαΐου Ιουνίου
    Ιουλίου Αυγούστου Σεπτεμβρίου Οκτωβρίου Νοεμβρίου Δεκεμβρίου
  ]

  def self.genitive(numeric_month)
    GENITIVE_FORMS[numeric_month - 1]
  end
end
