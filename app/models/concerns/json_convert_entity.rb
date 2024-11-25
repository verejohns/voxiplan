module JSONConvertEntity
  extend ::ActiveSupport::Concern

  included do
    before_save do
      json_fields = self.class.columns.select{|c| c.type == :json}.map(&:name)

      json_fields.each do |field|
        data = self.send(field)
        if data.present? and data.is_a? String
          begin
            self.attributes = {field => JSON.parse(data)}
          rescue JSON::ParserError => e
            # puts "******** Error while parsing json "
            # puts data
            self.attributes = {field => data}
          end
        end
      end
    end
  end
end
