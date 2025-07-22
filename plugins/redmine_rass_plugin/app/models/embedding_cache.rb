class EmbeddingCache
  include Singleton
  
  def initialize
    @cache = {}
    @access_times = {}
    @max_size = Setting.plugin_redmine_rass_plugin&.dig('embedding_cache_size') || 1000
    @ttl = Setting.plugin_redmine_rass_plugin&.dig('embedding_cache_ttl') || 3600
  end
  
  def get(text)
    return nil unless enabled?
    return nil if text.blank?
    
    key = cache_key(text)
    cached = @cache[key]
    
    if cached && !expired?(cached)
      @access_times[key] = Time.current
      return cached[:embedding]
    elsif cached && expired?(cached)
      delete(key)
    end
    
    nil
  end
  
  def set(text, embedding)
    return unless enabled?
    return if text.blank?
    
    key = cache_key(text)
    
    # Remove least recently used if cache is full
    if @cache.size >= @max_size
      remove_lru
    end
    
    @cache[key] = {
      embedding: embedding,
      created_at: Time.current
    }
    @access_times[key] = Time.current
  end
  
  def clear
    @cache.clear
    @access_times.clear
  end
  
  def size
    @cache.size
  end
  
  def enabled?
    Setting.plugin_redmine_rass_plugin&.dig('enable_embedding_cache') != false
  end
  
  def stats
    {
      size: size,
      max_size: @max_size,
      enabled: enabled?,
      ttl: @ttl
    }
  end
  
  private
  
  def cache_key(text)
    Digest::SHA256.hexdigest(text.strip.downcase)
  end
  
  def expired?(cached)
    Time.current - cached[:created_at] > @ttl
  end
  
  def delete(key)
    @cache.delete(key)
    @access_times.delete(key)
  end
  
  def remove_lru
    return if @access_times.empty?
    
    oldest_key = @access_times.min_by { |k, v| v }[0]
    delete(oldest_key)
  end
end 