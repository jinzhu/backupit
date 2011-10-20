module Backup
  module Attribute
    def generate_attributes(*attrs)
      attrs.flatten.each do |attr|
        class_eval <<-METHOD
          def #{attr}(value=nil)
            instance_variable_set("@#{attr}", value) unless value.nil?
            instance_variable_get("@#{attr}")
          end
        METHOD
      end
    end
  end
end
