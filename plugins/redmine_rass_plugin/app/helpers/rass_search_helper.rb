module RassSearchHelper
  def self.included(base)
    base.class_eval do
      # Override the search form to add semantic search options
      def semantic_search_options
        content_tag(:fieldset, class: 'box') do
          content_tag(:legend, l(:label_semantic_search_options)) +
          content_tag(:p) do
            check_box_tag('semantic_search', '1', params[:semantic_search] == '1') +
            label_tag('semantic_search', l(:label_use_semantic_search))
          end +
          content_tag(:p) do
            label_tag('search_algorithm', l(:label_search_algorithm)) +
            select_tag('search_algorithm', 
              options_for_select([
                [l(:label_semantic_search), 'semantic'],
                [l(:label_hybrid_search), 'hybrid'],
                [l(:label_lexical_search), 'lexical']
              ], params[:search_algorithm] || 'hybrid'))
          end +
          content_tag(:p) do
            label_tag('similarity_threshold', l(:label_similarity_threshold)) +
            select_tag('similarity_threshold',
              options_for_select([
                [l(:label_high_similarity), '0.8'],
                [l(:label_medium_similarity), '0.6'],
                [l(:label_low_similarity), '0.4']
              ], params[:similarity_threshold] || '0.6'))
          end
        end
      end

      # Add highlight_tokens method for search result highlighting
      def highlight_tokens(text, tokens)
        return text if text.blank? || tokens.blank?
        
        # Simple highlighting implementation
        highlighted_text = text.to_s
        tokens.each do |token|
          next if token.blank?
          # Escape regex special characters
          escaped_token = Regexp.escape(token)
          # Case-insensitive replacement with highlighting
          highlighted_text = highlighted_text.gsub(
            /(#{escaped_token})/i,
            '<mark>\1</mark>'
          )
        end
        highlighted_text.html_safe
      end
    end
  end
end 