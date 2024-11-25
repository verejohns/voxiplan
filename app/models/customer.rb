class Customer < ApplicationRecord
  belongs_to :client
  #validates :first_name, :last_name, presence: true
  attr_accessor :lang
  before_create :recognise_name
  has_many :contacts, dependent: :destroy
  has_many :answers, dependent: :destroy

  accepts_nested_attributes_for :contacts, :allow_destroy => true

  scope :active_during, ->(start_time, end_time) { where("last_active_at >= ? and last_active_at <= ? ", start_time, end_time) }
  scope :current_active, -> { active_during(Time.now.at_beginning_of_month, Time.now.at_end_of_month) }

  GENDER = {
              "0" => "",              # blank
              "1" => "male",           # male
              "2" => "female",         # female
              "9" => "not applicable" # blank
            }
  # gender (Format: ISO/IEC 5218)
  # birthday (Format: ISO 8601)
  # country (Format: ISO 3166)
  # phone numbers (Format: E.164)

  def self.import(file, client_id)
    i = 0
    client = Client.find_by_id(client_id)
    CSV.foreach(file.path) do |row|
      i += 1
      next if  i == 1
      gender = 0
      gender = 1 if row[6] == 'male'
      gender = 2 if row[6] == 'female'
      gender = 9 if row[6] == 'not applicable'
      phone_number = row[2]
      phone_country = row[3]
      country = row[4]
      customer = Customer.new(
        first_name:     row[0],
        last_name:      row[1],
        email:          row[5],
        gender:         gender,
        birthday:       row[7],
        city:           row[9],
        street:         row[8],
        zipcode:        row[10],
        phone_country:  (phone_country || country_iso_code(client.country)),
        phone_number:   phone_number,
        country:        country,
        notes:          row[11],
        client_id:      client_id
      )
      customer.save

      save_result = true
      if phone_number
        phone_number.split(",").each_with_index do |phone_number, index|
          @contact = Contact.new(client_id: client_id, customer_id: customer.id, phone: phone_number, country: phone_country.split(',')[index])
          save_result = @contact.save
          break unless save_result
        end
      end

      unless save_result
        customer.destroy
      end
    end
  end

  def self.country_iso_code(country_name)
    country = ISO3166::Country.find_country_by_name(country_name)
    country.alpha2 rescue nil
  end

  def full_name
    [first_name, last_name].join(' ')
  end

  private

  def recognise_name
    return if recorded_name_url.blank?
    # recorded_name_url = "https://app.voxiplan.com/recordings/7e39edda02ffc0db6cfeef9d393ee0b5"
    uuid = recorded_name_url.split('/').last
    recording = Recording.find_by uuid: uuid
    return unless recording
    google_voice_locale = recording.call.try(:ivr).try(:google_voice_locale)
    name = GoogleSpeechToText.recognise(recording.url, google_voice_locale)
    result = NameApiParty.new(ENV['NAME_API_KEY']).parse_name(name)
    self.first_name = result[:first_name]
    self.last_name = result[:last_name]
    self.gender = result[:gender]
  end
end
