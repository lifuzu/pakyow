module Pakyow
  module Presenter
    class Page
      MATTER_MATCHER = /^(---\s*\n.*?\n?)^(---\s*$\n?)/m

      class << self
        def load(path)
          format   = Utils::String.split_at_last_dot(path)[-1]
          name     = File.basename(path, '.*').to_sym
          contents = FileTest.file?(path) ? File.read(path) : nil

          return Page.new(name, contents, path, format)
        end
      end

      attr_reader :path, :contents
      attr_accessor :composer

      def initialize(name, contents, path, format = :html)
        @name, @contents, @path, @format = name, contents, path, format

        @info    = { template: :pakyow }
        @containers = {}

        unless @contents.nil?
          parse_info
          parse_content
        end
      end

      def initialize_copy(original_page)
        super

        # copy content
        @containers = {}
        original_page.instance_variable_get(:'@containers').each_pair do |k, v|
          @containers[k] = v.dup
        end
      end

      def content(container = nil)
        return @contents if container.nil?

        container = @containers.fetch(container.to_sym) {
          raise MissingContainer, "No container named #{container} in #{@path}"
        }

        return container.to_html
      end

      def info(key = nil)
        return @info if key.nil?
        return @info[key]
      end

      def ==(page)
        @contents == page.contents
      end

      def container(name)
        @containers.fetch(name.to_sym) {
          raise MissingContainer, "No container named #{name} in #{@path}"
        }
      end

      def each_container
        @containers.each_pair { |name, container| yield(name, container) }
      end

      def composer=(composer)
        @composer = composer

        @containers.each do |name, container|
          container.composer = composer
        end
      end

      private

      def parse_info
        info = parse_front_matter(@contents)
        info = {} if !info || !info.is_a?(Hash)

        @info.merge!(Utils::Hash.symbolize(info))
      end

      def parse_content
        # remove yaml front matter
        @contents.gsub!(/---(.|\n)*---/, '')

        # process contents
        @contents = Presenter.process(@contents, @format)

        # find content in named containers
        within_regex = /<!--\s*@within\s*([a-zA-Z0-9\-_]*)\s*-->(.*?)<!--\s*\/within\s*-->/m

        @contents.scan(within_regex) do |m|
          container_name = m[0].to_sym
          @containers[container_name] = Container.new(m[1], @format)
        end

        # find default content
        @containers[:default] = Container.new(@contents.gsub(within_regex, ''), @format)
      end

      def parse_front_matter(contents)
        # match the matter
        matter = contents.match(MATTER_MATCHER).to_s

        # remove the opening/closing '---'
        matter = matter.split("\n")[1..-2]
        # return if no matter
        return {} if matter.nil?

        YAML.load(matter.join("\n"))
      end
    end
  end
end
