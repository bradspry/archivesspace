ASpaceExport::model :mets do
  
  include JSONModel

  attr_accessor :header_agent_name
  attr_accessor :header_agent_note
  attr_accessor :header_agent_role
  attr_accessor :header_agent_type
  
  attr_accessor :wrapped_dmd
  
  attr_accessor :extents
  attr_accessor :notes
  attr_accessor :subjects
  attr_accessor :names
  attr_accessor :type_of_resource
  attr_accessor :parts
  
  
  
  
  @repository_map = {
    :name => :header_agent_name=,
    :values => :build_header_agent_note,
  }
  
  
  @archival_object_map = {
    # :title => :title=,
    # :language => :language_term=,
    # :extent => :handle_extent,
    # :subjects => :handle_subjects,
    # :linked_agents => :handle_agents

  }
  
  @digital_object_map = {
    # :notes => :handle_notes
  }
  
  
  @name_type_map = {
    'agent_person' => 'personal',
    'agent_family' => 'family',
    'agent_corporate' => 'corporate',
    'agent_software' => nil
  }
  
  @name_part_type_map = {
    'primary_name' => 'family',
    'title' => 'termsOfAddress',
    'rest_of_name' => 'given',
    'family_name' => 'family',
    'prefix' => 'termsOfAddress'
  }
    

  def initialize
    @wrapped_dmd = []
    
    @extents = []
    @notes = []
    @subjects = []
    @names = []
    @parts = []
  end
  
  # Some things are universal
  def self.from_aspace_object(obj)
  
    mets = self.new
    
    if obj.class.model_scope == :repository
      mets.apply_map(Repository.get_or_die(obj.repo_id), @repository_map)
      mets.header_agent_role = "CREATOR"
      mets.header_agent_type = "ORGANIZATION"
    end
    
    mets
  end
    
  # meaning, 'archival object' in the abstract
  def self.from_archival_object(obj)
    
    mets = self.from_aspace_object(obj)
    
    mets.apply_map(obj, @archival_object_map)
    
    mets.apply_mapped_relationships(obj, @archival_object_map)
     
    mets
  end
    
  
  def self.from_digital_object(obj)
    
    mets = self.from_archival_object(obj)
    
    mets.type_of_resource = obj.digital_object_type
    
    mets.apply_map(obj, @digital_object_map)
    
    # wrapped DMD
    mods = ASpaceExport.model(:mods).from_digital_object(obj)
    mods_callback = lambda {|mods, xml|
                            mods_ns = xml.doc.root.namespace_definitions.find{|ns| ns.prefix == 'mods'}
                            xml.instance_variable_set(:@sticky_ns, mods_ns)
                            ASpaceExport.serializer(:mods)._mods(mods, xml)
                            xml.instance_variable_set(:@sticky_ns, nil)
                             }

    mets.dmd_wrap("MODS", mods_callback, mods)
    
    # obj.tree['children'].each do |child|
    #   mets.parts << {'id' => "component-#{child['id']}", 'title' => child['title']}
    # end
  
    mets
  end
  
  def self.name_type_map
    @name_type_map
  end
  
  def self.name_part_type_map
    @name_part_type_map
  end
  
  
  def apply_mapped_relationships(obj, map)  
    obj.class.instance_variable_get(:@relationships).each do |rel|
      next unless map.has_key?(rel[:json_property].to_sym)
      self.send(map[rel[:json_property].to_sym], obj.my_relationships(rel[:name]))
    end
  end
  
  
  def apply_map(obj, map)
    map.each do |as_field, handler|
      self.send(handler, obj.send(as_field)) if obj.respond_to?(as_field)
    end
  end
  
  def build_header_agent_note(vals)
    note = String.new
    vals.reject! {|k,v| v.nil?}
    note += "Parent Institution: #{vals[:parent_institution_name]}" if vals[:parent_institution_name]
    self.header_agent_note = note unless note.empty?
  end
  
  def dmd_wrap(mdtype, callback, data)
    self.wrapped_dmd << {'type' => mdtype,'callback' => callback, 'data' => data}
  end
  
end