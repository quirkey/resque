module Resque
  class Payload < Hash
    include Helpers
    extend Helpers
    
    attr_accessor :uuid
    
    def initialize(uuid, hash = {})
      if uuid.is_a?(String)
        self.uuid = uuid
      else
        self.uuid = nil
        hash = uuid
      end
      self.replace(hash)
    end
    
    def klass
      @klass ||= constantize(self['class'])
    end
    
    def args
      self['args']
    end
    
  end
end