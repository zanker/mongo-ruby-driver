# A hash in which the order of keys are preserved.
#
# Under Ruby 1.9 and greater, this class has no added methods because Ruby's
# Hash already keeps its keys ordered by order of insertion.

module BSON
  class OrderedHash < Hash

    def ==(other)
      begin
        case other
        when BSON::OrderedHash
           keys == other.keys && values == other.values
        else
          super
        end
      rescue
        false
      end
    end

    # We only need the body of this class if the RUBY_VERSION is before 1.9
    if RUBY_VERSION < '1.9'
      attr_accessor :ordered_keys

      def self.[] *args
        oh = BSON::OrderedHash.new
        if Hash === args[0]
          oh.merge! args[0]
        elsif (args.size % 2) != 0
          raise ArgumentError, "odd number of elements for Hash"
        else
          0.step(args.size - 1, 2) do |key|
            value = key + 1
            oh[args[key]] = args[value]
          end
        end
        oh
      end

      def initialize(*a, &b)
        @ordered_keys = []
        super
      end

      def yaml_initialize(tag, val)
        @ordered_keys = []
        super
      end

      def keys
        @ordered_keys.dup
      end

      def []=(key, value)
        unless has_key?(key)
          @ordered_keys << key
        end
        super(key, value)
      end

      def each
        @ordered_keys.each { |k| yield k, self[k] }
        self
      end
      alias :each_pair :each

      def to_a
        @ordered_keys.map { |k| [k, self[k]] }
      end

      def values
        collect { |k, v| v }
      end

      def replace(other)
        @ordered_keys.replace(other.keys)
        super
      end

      def merge(other)
        oh = self.dup
        oh.merge!(other)
        oh
      end

      def merge!(other)
        @ordered_keys += other.keys # unordered if not an BSON::OrderedHash
        @ordered_keys.uniq!
        super(other)
      end

      alias :update :merge!

      def dup
        result = OrderedHash.new
        @ordered_keys.each do |key|
          result[key] = self[key]
        end
        result
      end

      def inspect
        str = "#<BSON::OrderedHash:0x#{self.object_id.to_s(16)} {"
        str << (@ordered_keys || []).collect { |k| "\"#{k}\"=>#{self.[](k).inspect}" }.join(", ")
        str << '}>'
      end

      def delete(key, &block)
        @ordered_keys.delete(key) if @ordered_keys
        super
      end

      def delete_if(&block)
        keys.each do |key|
          if yield key, self[key]
            delete(key)
          end
        end
        self
      end

      def reject(&block)
        clone = self.clone
        return clone unless block_given?
        clone.delete_if(&block)
      end

      def reject!(&block)
        changed = false
        self.each do |k,v|
          if yield k, v
            changed = true
            delete(k)
          end
        end
        changed ? self : nil
      end

      def clear
        super
        @ordered_keys = []
      end

      def initialize_copy(original)
        super
        @ordered_keys = original.ordered_keys.dup
      end

      if RUBY_VERSION =~ /1.8.6/
        def hash
          code = 17
          each_pair do |key, value|
            code = 37 * code + key.hash
            code = 37 * code + value.hash
          end
          code & 0x7fffffff
        end

        def eql?(o)
          if o.instance_of? BSON::OrderedHash
            self.hash == o.hash
          else
            false
          end
        end
      end
    end
  end
end
