# Things shared between sites and site proxies

module RSMP
  module Components
    attr_reader :components
    
    def initialize_components
      @components = {}
    end

    def aggregated_status_changed component, options={}
    end

    def setup_components settings
      return unless settings
      check_main_component settings
      settings.each_pair do |type,components_by_type|
        components_by_type.each_pair do |id,settings|
          @components[id] = build_component(id:id, type:type, settings:settings)
        end
      end
    end

    def check_main_component settings
      unless settings['main'] && settings['main'].size >= 1
        raise ConfigurationError.new("main component must be defined") 
      end
      if settings['main'].size > 1
        raise ConfigurationError.new("only one main component can be defined, found #{settings['main'].keys.join(', ')}") 
      end
    end

    def add_component component
      @components[component.c_id] = component
    end

    def build_component id:, type:, settings:{}
      Component.new id:id, node: self, grouped: type=='main'
    end

    def find_component component_id
      component = @components[component_id]
      raise UnknownComponent.new("Component #{component_id} not found") unless component
      component
    end

  end
end