# Needed for Prawn (from Statsample)
class File
  class << self
    alias_method :exists?, :exist? unless respond_to?(:exists?)
  end
end
